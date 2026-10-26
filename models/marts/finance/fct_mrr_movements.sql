{#
    Grain: one row per (company_id, month) where the company is or was paying.

    Classic SaaS MRR bridge. For each month, compare MRR to the previous month:
      new           0 -> >0, first time ever paying
      reactivation  0 -> >0, has paid before
      expansion     up
      contraction   down (but still > 0)
      churn         >0 -> 0
      retained      unchanged and > 0
    Months at 0 after a churn ('inactive') are filtered out.
#}

with mrr_monthly as (

    select * from {{ ref('int_companies__mrr_monthly') }}

),

with_previous as (

    select
        company_id,
        month_start,
        plan_name,
        mrr_eur,
        coalesce(
            lag(mrr_eur) over (partition by company_id order by month_start)
        , 0)                                                        as previous_mrr_eur,
        coalesce(
            sum(case when mrr_eur > 0 then 1 else 0 end) over (
                partition by company_id
                order by month_start
                rows between unbounded preceding and 1 preceding
            )
        , 0)                                                        as prior_paying_months

    from mrr_monthly

),

classified as (

    select
        *,
        mrr_eur - previous_mrr_eur                                  as mrr_change_eur,
        case
            when previous_mrr_eur = 0 and mrr_eur > 0 and prior_paying_months = 0 then 'new'
            when previous_mrr_eur = 0 and mrr_eur > 0                             then 'reactivation'
            when previous_mrr_eur > 0 and mrr_eur = 0                             then 'churn'
            when mrr_eur > previous_mrr_eur                                       then 'expansion'
            when mrr_eur < previous_mrr_eur                                       then 'contraction'
            when mrr_eur > 0                                                      then 'retained'
            else 'inactive'
        end                                                         as mrr_movement

    from with_previous

)

select
    {{ dbt_utils.generate_surrogate_key(['company_id', 'month_start']) }}   as company_month_key,
    company_id,
    month_start,
    plan_name,
    previous_mrr_eur,
    mrr_eur,
    mrr_change_eur,
    mrr_movement

from classified
where mrr_movement != 'inactive'
