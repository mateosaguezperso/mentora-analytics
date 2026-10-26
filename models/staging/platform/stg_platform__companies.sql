with source as (

    select * from {{ source('platform', 'companies') }}

),

renamed as (

    select
        cast(id as {{ dbt.type_int() }})                 as company_id,
        trim(name)                                       as company_name,
        industry,
        employee_range,
        cast(created_at as {{ dbt.type_timestamp() }})   as created_at

    from source

)

select * from renamed
