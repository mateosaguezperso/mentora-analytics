{#
    Grain: one row per (company_id, month) from the company's first subscription
    month up to the analysis end date, INCLUDING months with 0 MRR after churn.
    Those zero rows are what lets fct_mrr_movements detect churn with lag().

    MRR convention: a subscription counts in a month if it is active on the
    last day of that month (end-of-month snapshot).
#}

with subscriptions as (

    select * from {{ ref('stg_platform__subscriptions') }}

),

months as (

    {{ dbt_utils.date_spine(
        datepart="month",
        start_date="cast('2024-01-01' as date)",
        end_date="cast('" ~ var('analysis_end_date') ~ "' as date)"
    ) }}

),

months_clean as (

    select
        cast(date_month as date)                                                         as month_start,
        cast({{ dbt.dateadd('month', 1, 'date_month') }} as {{ dbt.type_timestamp() }})  as next_month_start

    from months

),

company_first_month as (

    select
        company_id,
        cast({{ dbt.date_trunc('month', 'min(started_at)') }} as date) as first_month

    from subscriptions
    group by company_id

),

company_months as (

    select
        company_first_month.company_id,
        months_clean.month_start,
        months_clean.next_month_start

    from company_first_month
    inner join months_clean
        on months_clean.month_start >= company_first_month.first_month

),

company_mrr as (

    select
        company_months.company_id,
        company_months.month_start,
        coalesce(sum(subscriptions.mrr_eur), 0)            as mrr_eur,
        -- plan of the active subscription (a company has at most one at a time)
        max(subscriptions.plan_name)                       as plan_name

    from company_months
    left join subscriptions
        on  subscriptions.company_id = company_months.company_id
        and subscriptions.started_at < company_months.next_month_start
        and (
            subscriptions.ended_at is null
            or subscriptions.ended_at >= company_months.next_month_start
        )
    group by
        company_months.company_id,
        company_months.month_start

)

select * from company_mrr
