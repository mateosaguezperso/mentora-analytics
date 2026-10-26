{#
    Grain: one row per mentor (lifetime).
    Supply-side quality: is the mentor answering, accepting, showing up?

    Rates are computed on the right denominator:
      response_rate    = responded / requests received
      acceptance_rate  = accepted  / responded     (decision quality)
      completion_rate  = completed / accepted      (show-up rate)
#}

with bookings as (

    select * from {{ ref('fct_bookings') }}

),

mentors as (

    select * from {{ ref('dim_mentors') }}

),

stats as (

    select
        mentor_id,
        count(*)                                                     as requests_received,
        count(case when is_responded then 1 end)                     as requests_responded,
        count(case when is_accepted  then 1 end)                     as requests_accepted,
        count(case when is_completed then 1 end)                     as conversations_completed,
        {{ median('response_time_hours') }}                          as median_response_time_hours,
        avg(rating)                                                  as avg_rating,
        count(rating)                                                as ratings_count

    from bookings
    group by mentor_id

),

rates as (

    select
        *,
        round(1.0 * requests_responded      / nullif(requests_received, 0), 4)  as response_rate,
        round(1.0 * requests_accepted       / nullif(requests_responded, 0), 4) as acceptance_rate,
        round(1.0 * conversations_completed / nullif(requests_accepted, 0), 4)  as completion_rate

    from stats

)

select
    mentors.mentor_id,
    mentors.company_id,
    mentors.company_name,
    mentors.job_family,
    mentors.is_active,

    coalesce(rates.requests_received, 0)          as requests_received,
    coalesce(rates.requests_responded, 0)         as requests_responded,
    coalesce(rates.requests_accepted, 0)          as requests_accepted,
    coalesce(rates.conversations_completed, 0)    as conversations_completed,
    rates.response_rate,
    rates.acceptance_rate,
    rates.completion_rate,
    round(rates.median_response_time_hours, 1)    as median_response_time_hours,
    round(rates.avg_rating, 2)                    as avg_rating,
    coalesce(rates.ratings_count, 0)              as ratings_count,

    case
        when coalesce(rates.requests_received, 0) < 5           then 'not_enough_data'
        when rates.response_rate < 0.8
            or rates.median_response_time_hours > 72            then 'unresponsive'
        when rates.acceptance_rate >= 0.85
            and coalesce(rates.avg_rating, 0) >= 4.3            then 'top_mentor'
        else 'standard'
    end                                           as performance_segment

from mentors
left join rates
    on mentors.mentor_id = rates.mentor_id
