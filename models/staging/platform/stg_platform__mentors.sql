with source as (

    select * from {{ source('platform', 'mentors') }}

),

renamed as (

    select
        cast(id as {{ dbt.type_int() }})                 as mentor_id,
        cast(company_id as {{ dbt.type_int() }})         as company_id,
        trim(job_title)                                  as job_title,
        -- "Data Analyst" -> "Data": job family used for supply analysis
        {{ dbt.split_part('trim(job_title)', "' '", 1) }} as job_family,
        cast(is_active as {{ dbt.type_boolean() }})      as is_active,
        cast(joined_at as {{ dbt.type_timestamp() }})    as joined_at

    from source

)

select * from renamed
