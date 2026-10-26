{#
    Financial reconciliation test.
    For every month:
        opening + new + reactivation + expansion - contraction - churn = closing
    and the opening MRR of month M equals the closing MRR of month M-1.
    Any returned row is a bug in the MRR logic.
#}

with bridge as (

    select
        *,
        lag(closing_mrr_eur) over (order by month_start) as previous_closing_mrr_eur

    from {{ ref('agg_mrr_monthly') }}

)

-- a singular test returns the failing rows, whatever their columns
select *  -- noqa: AM04
from bridge
where abs(
        opening_mrr_eur
        + new_mrr_eur
        + reactivation_mrr_eur
        + expansion_mrr_eur
        - contraction_mrr_eur
        - churned_mrr_eur
        - closing_mrr_eur
    ) > 0.01
    or (
        previous_closing_mrr_eur is not null
        and abs(opening_mrr_eur - previous_closing_mrr_eur) > 0.01
    )
