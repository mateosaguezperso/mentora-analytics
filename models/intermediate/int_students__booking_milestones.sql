-- Grain: one row per student who requested at least one conversation.

with bookings as (

    select * from {{ ref('int_bookings__pivoted') }}

)

select
    student_id,
    min(requested_at)                                                   as first_requested_at,
    min(completed_at)                                                   as first_completed_at,
    max(completed_at)                                                   as last_completed_at,
    count(*)                                                            as bookings_requested,
    count(case when current_status = 'completed' then 1 end)            as conversations_completed

from bookings
group by student_id
