{#
    Grain: one row per (cohort_month, activity_month).

    Cohort       = month of the student's FIRST completed conversation.
    Retention    = share of the cohort with >= 1 completed conversation
                   IN that exact month (not cumulative "ever came back").

    The full cohort x month grid is generated with a date spine so that months
    with zero returning students appear as 0 % instead of disappearing from the
    heatmap.
#}

with completed_bookings as (

    select
        student_id,
        cast({{ dbt.date_trunc('month', 'completed_at') }} as date) as activity_month

    from {{ ref('fct_bookings') }}
    where is_completed

),

student_months as (

    select distinct student_id, activity_month
    from completed_bookings

),

cohorts as (

    select
        student_id,
        min(activity_month) as cohort_month

    from student_months
    group by student_id

),

cohort_sizes as (

    select
        cohort_month,
        count(*) as cohort_size

    from cohorts
    group by cohort_month

),

months as (

    {{ dbt_utils.date_spine(
        datepart="month",
        start_date="cast('2024-01-01' as date)",
        end_date="cast('" ~ var('analysis_end_date') ~ "' as date)"
    ) }}

),

grid as (

    select
        cohort_sizes.cohort_month,
        cohort_sizes.cohort_size,
        cast(months.date_month as date) as activity_month

    from cohort_sizes
    inner join months
        on cast(months.date_month as date) >= cohort_sizes.cohort_month

),

activity as (

    select
        cohorts.cohort_month,
        student_months.activity_month,
        count(distinct student_months.student_id) as active_students

    from student_months
    inner join cohorts
        on student_months.student_id = cohorts.student_id
    group by
        cohorts.cohort_month,
        student_months.activity_month

)

select
    grid.cohort_month,
    grid.activity_month,
    {{ dbt.datediff('grid.cohort_month', 'grid.activity_month', 'month') }}  as months_since_first,
    grid.cohort_size,
    coalesce(activity.active_students, 0)                                   as active_students,
    round(1.0 * coalesce(activity.active_students, 0) / grid.cohort_size, 4) as retention_rate

from grid
left join activity
    on  grid.cohort_month = activity.cohort_month
    and grid.activity_month = activity.activity_month
