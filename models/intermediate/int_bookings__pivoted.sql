{#
    Rebuilds one row per booking from the CDC log:
      - the CURRENT status (latest transition)
      - a timestamp per lifecycle milestone (accepted_at, completed_at...)

    Edge case handled: two transitions can share the same timestamp
    (e.g. accepted then immediately cancelled). We break ties with the
    lifecycle order so the terminal state always wins.
#}

with events as (

    select * from {{ ref('stg_platform__booking_events') }}

),

ranked as (

    select
        *,
        row_number() over (
            partition by booking_id
            order by
                status_changed_at desc,
                case booking_status
                    when 'requested' then 1
                    when 'accepted'  then 2
                    else 3  -- declined / expired / cancelled / completed are terminal
                end desc
        ) as recency_rank

    from events

),

current_state as (

    select
        booking_id,
        booking_status       as current_status,
        status_changed_at    as last_updated_at

    from ranked
    where recency_rank = 1

),

milestones as (

    select
        booking_id,
        -- constant per booking in the source: min() just collapses the log
        min(student_id)                                                              as student_id,
        min(mentor_id)                                                               as mentor_id,
        min(requested_at)                                                            as requested_at,
        min(scheduled_at)                                                            as scheduled_at,
        min(case when booking_status = 'accepted'  then status_changed_at end)       as accepted_at,
        min(case when booking_status = 'declined'  then status_changed_at end)       as declined_at,
        min(case when booking_status = 'expired'   then status_changed_at end)       as expired_at,
        min(case when booking_status = 'cancelled' then status_changed_at end)       as cancelled_at,
        min(case when booking_status = 'completed' then status_changed_at end)       as completed_at

    from events
    group by booking_id

)

select
    milestones.booking_id,
    milestones.student_id,
    milestones.mentor_id,
    current_state.current_status,
    milestones.requested_at,
    milestones.scheduled_at,
    milestones.accepted_at,
    milestones.declined_at,
    milestones.expired_at,
    milestones.cancelled_at,
    milestones.completed_at,
    -- first answer of the mentor, whatever it was
    coalesce(milestones.accepted_at, milestones.declined_at)   as responded_at,
    current_state.last_updated_at

from milestones
inner join current_state
    on milestones.booking_id = current_state.booking_id
