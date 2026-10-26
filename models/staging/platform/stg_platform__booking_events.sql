{#
    Grain: one row per (booking_id, status) transition.
    Staging stays 1:1 with the CDC log; the "current state" of each booking
    is rebuilt in intermediate/int_bookings__pivoted.
#}

with source as (

    select * from {{ source('platform', 'bookings') }}

),

renamed as (

    select
        cast(booking_id as {{ dbt.type_string() }})        as booking_id,
        cast(student_id as {{ dbt.type_int() }})           as student_id,
        cast(mentor_id as {{ dbt.type_int() }})            as mentor_id,
        -- source has 'Completed', 'completed ' ... => normalise once, here
        lower(trim(status))                                as booking_status,
        cast(created_at as {{ dbt.type_timestamp() }})     as requested_at,
        cast(scheduled_at as {{ dbt.type_timestamp() }})   as scheduled_at,
        cast(updated_at as {{ dbt.type_timestamp() }})     as status_changed_at

    from source

)

select * from renamed
