-- Grain: one row per customer company, with its CURRENT commercial state.

with companies as (

    select * from {{ ref('stg_platform__companies') }}

),

mrr_monthly as (

    select * from {{ ref('int_companies__mrr_monthly') }}

),

mentors as (

    select * from {{ ref('stg_platform__mentors') }}

),

mrr_summary as (

    select
        company_id,
        min(case when mrr_eur > 0 then month_start end)     as first_paying_month,
        max(case when mrr_eur > 0 then month_start end)     as last_paying_month,
        max(month_start)                                    as latest_month

    from mrr_monthly
    group by company_id

),

current_month as (

    select
        mrr_monthly.company_id,
        mrr_monthly.mrr_eur      as current_mrr_eur,
        mrr_monthly.plan_name    as current_plan

    from mrr_monthly
    inner join mrr_summary
        on  mrr_monthly.company_id = mrr_summary.company_id
        and mrr_monthly.month_start = mrr_summary.latest_month

),

mentor_counts as (

    select
        company_id,
        count(*)                                             as mentors_total,
        count(case when is_active then 1 end)                as mentors_active

    from mentors
    group by company_id

)

select
    companies.company_id,
    companies.company_name,
    companies.industry,
    companies.employee_range,
    companies.created_at,

    mrr_summary.first_paying_month,
    coalesce(current_month.current_mrr_eur, 0)               as current_mrr_eur,
    current_month.current_plan,
    coalesce(current_month.current_mrr_eur, 0) > 0           as is_active_customer,
    -- churn month = first month after the last paying month
    case
        when coalesce(current_month.current_mrr_eur, 0) = 0
            then cast({{ dbt.dateadd('month', 1, 'mrr_summary.last_paying_month') }} as date)
    end                                                      as churned_month,

    coalesce(mentor_counts.mentors_total, 0)                 as mentors_total,
    coalesce(mentor_counts.mentors_active, 0)                as mentors_active

from companies
left join mrr_summary
    on companies.company_id = mrr_summary.company_id
left join current_month
    on companies.company_id = current_month.company_id
left join mentor_counts
    on companies.company_id = mentor_counts.company_id
