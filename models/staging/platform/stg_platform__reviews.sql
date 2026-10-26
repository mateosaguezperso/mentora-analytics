with source as (

    select * from {{ source('platform', 'reviews') }}

),

renamed as (

    select
        cast(id as {{ dbt.type_string() }})               as review_id,
        cast(booking_id as {{ dbt.type_string() }})       as booking_id,
        cast(rating as {{ dbt.type_int() }})              as rating,
        cast(created_at as {{ dbt.type_timestamp() }})    as reviewed_at

    from source

),

-- the review webhook sometimes fires twice => exact duplicates on review_id
deduplicated as (

    select
        *,
        row_number() over (
            partition by review_id
            order by reviewed_at
        ) as row_num

    from renamed

)

select
    review_id,
    booking_id,
    rating,
    reviewed_at

from deduplicated
where row_num = 1
