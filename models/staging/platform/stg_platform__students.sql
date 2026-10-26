with source as (

    select * from {{ source('platform', 'students') }}

),

renamed as (

    select
        cast(id as {{ dbt.type_int() }})                   as student_id,
        -- emails come with mixed casing / whitespace from the signup form
        lower(trim(email))                                 as email,
        education_level,
        acquisition_channel,
        city,
        cast(signed_up_at as {{ dbt.type_timestamp() }})   as signed_up_at

    from source

)

select * from renamed
