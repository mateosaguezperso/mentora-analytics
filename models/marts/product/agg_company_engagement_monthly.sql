{#
    Grain: one row per (company_id, month) for PAYING months only.

    Customer-success view: is the customer getting value for what they pay?
      - cost_per_conversation_eur : MRR / completed conversations
      - is_at_risk                : < 3 completed conversations over the last
                                    3 paying months => churn signal for the CSM
#}

with mrr_monthly as (

    select * from {{ ref('int_companies__mrr_monthly') }}
    where mrr_eur > 0

),

bookings_monthly as (

    select
        company_id,
        cast({{ dbt.date_trunc('month', 'requested_at') }} as date)   as month_start,
        count(*)                                                      as requests_received,
        count(case when is_completed then 1 end)                      as conversations_completed

    from {{ ref('fct_bookings') }}
    group by
        company_id,
        cast({{ dbt.date_trunc('month', 'requested_at') }} as date)

),

joined as (

    select
        mrr_monthly.company_id,
        mrr_monthly.month_start,
        mrr_monthly.plan_name,
        mrr_monthly.mrr_eur,
        coalesce(bookings_monthly.requests_received, 0)         as requests_received,
        coalesce(bookings_monthly.conversations_completed, 0)   as conversations_completed

    from mrr_monthly
    left join bookings_monthly
        on  mrr_monthly.company_id = bookings_monthly.company_id
        and mrr_monthly.month_start = bookings_monthly.month_start

),

rolling as (

    select
        *,
        cast(
            sum(conversations_completed) over (
                partition by company_id
                order by month_start
                rows between 2 preceding and current row
            ) as {{ dbt.type_bigint() }}
        ) as conversations_completed_rolling_3m

    from joined

)

select
    company_id,
    month_start,
    plan_name,
    mrr_eur,
    requests_received,
    conversations_completed,
    conversations_completed_rolling_3m,
    round(mrr_eur / nullif(conversations_completed, 0), 2)   as cost_per_conversation_eur,
    conversations_completed_rolling_3m < 3                    as is_at_risk

from rolling
