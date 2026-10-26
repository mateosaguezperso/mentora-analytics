{#
    Grain: one row per month. The MRR bridge the CFO / Comex reads:
      opening MRR + new + reactivation + expansion - contraction - churn = closing MRR
    plus Net Revenue Retention (NRR) and paying customers.
#}

with movements as (

    select * from {{ ref('fct_mrr_movements') }}

),

monthly as (

    select
        month_start,
        sum(previous_mrr_eur)                                                          as opening_mrr_eur,
        sum(case when mrr_movement = 'new'          then mrr_change_eur else 0 end)   as new_mrr_eur,
        sum(case when mrr_movement = 'reactivation' then mrr_change_eur else 0 end)   as reactivation_mrr_eur,
        sum(case when mrr_movement = 'expansion'    then mrr_change_eur else 0 end)   as expansion_mrr_eur,
        -sum(case when mrr_movement = 'contraction' then mrr_change_eur else 0 end)   as contraction_mrr_eur,
        -sum(case when mrr_movement = 'churn'       then mrr_change_eur else 0 end)   as churned_mrr_eur,
        sum(mrr_eur)                                                                   as closing_mrr_eur,
        sum(case when previous_mrr_eur > 0 then 1 else 0 end)                          as opening_paying_companies,
        sum(case when mrr_eur > 0 then 1 else 0 end)                                   as paying_companies,
        sum(case when mrr_movement = 'new'   then 1 else 0 end)                        as new_companies,
        sum(case when mrr_movement = 'churn' then 1 else 0 end)                        as churned_companies

    from movements
    group by month_start

)

select
    *,
    -- NRR: what the opening customer base is worth one month later
    round(
        (opening_mrr_eur + expansion_mrr_eur - contraction_mrr_eur - churned_mrr_eur)
        / nullif(opening_mrr_eur, 0),
        4
    )                                                                                  as net_revenue_retention,
    round(1.0 * churned_companies / nullif(opening_paying_companies, 0), 4)
        as logo_churn_rate

from monthly
