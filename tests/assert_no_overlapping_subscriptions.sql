{#
    A company can only have ONE active subscription at a time.
    If two periods overlap, MRR would be double-counted in
    int_companies__mrr_monthly. Returns the overlapping pairs.
#}

with subscriptions as (

    select * from {{ ref('stg_platform__subscriptions') }}

)

select
    a.company_id,
    a.subscription_id as subscription_a,
    b.subscription_id as subscription_b

from subscriptions as a
inner join subscriptions as b
    on  a.company_id = b.company_id
    and a.subscription_id < b.subscription_id
    and a.started_at < coalesce(b.ended_at, cast('9999-12-31' as {{ dbt.type_timestamp() }}))
    and b.started_at < coalesce(a.ended_at, cast('9999-12-31' as {{ dbt.type_timestamp() }}))
