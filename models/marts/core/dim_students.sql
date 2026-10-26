{#
    Grain: one row per student.

    Activation = first conversation COMPLETED within N days of signup
    (var activation_window_days, default 30).

    Edge case: a student who signed up 10 days before the analysis date has
    not had 30 days to activate yet. `is_activation_window_closed` lets the BI
    layer exclude immature cohorts instead of showing a fake drop in the KPI.
#}

with students as (

    select * from {{ ref('stg_platform__students') }}

),

milestones as (

    select * from {{ ref('int_students__booking_milestones') }}

),

joined as (

    select
        students.student_id,
        students.email,
        students.education_level,
        students.acquisition_channel,
        students.city,
        students.signed_up_at,
        cast({{ dbt.date_trunc('month', 'students.signed_up_at') }} as date)  as signup_cohort_month,

        milestones.first_requested_at,
        milestones.first_completed_at,
        milestones.last_completed_at,
        coalesce(milestones.bookings_requested, 0)                          as bookings_requested,
        coalesce(milestones.conversations_completed, 0)                     as conversations_completed,

        cast(
            {{ dbt.dateadd('day', var('activation_window_days'), 'students.signed_up_at') }}
            as {{ dbt.type_timestamp() }}
        )                                                                   as activation_deadline_at

    from students
    left join milestones
        on students.student_id = milestones.student_id

)

select
    *,
    {{ dbt.datediff('signed_up_at', 'first_completed_at', 'day') }}       as days_to_first_conversation,  -- noqa: LT05

    first_requested_at is not null                                         as has_requested,

    coalesce(first_completed_at <= activation_deadline_at, false)          as is_activated,

    activation_deadline_at
    <= cast('{{ var("analysis_end_date") }}' as {{ dbt.type_timestamp() }})
        as is_activation_window_closed

from joined
