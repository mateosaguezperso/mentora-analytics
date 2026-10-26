with source as (

    select * from {{ source('platform', 'subscriptions') }}

),

renamed as (

    select
        cast(id as {{ dbt.type_string() }})              as subscription_id,
        cast(company_id as {{ dbt.type_int() }})         as company_id,
        lower(trim(plan))                                as plan_name,
        lower(trim(status))                              as subscription_status,

        cast(mrr_cents as {{ dbt.type_int() }})          as mrr_cents,
        {{ cents_to_euros('mrr_cents') }}                as mrr_eur,

        cast(started_at as {{ dbt.type_timestamp() }})   as started_at,
        -- open-ended subscription => null ended_at
        cast(ended_at as {{ dbt.type_timestamp() }})     as ended_at

    from source

)

select * from renamed
