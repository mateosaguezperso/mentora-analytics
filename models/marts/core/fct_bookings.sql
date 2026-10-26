{#
    Grain: one row per booking (conversation request).

    Incremental strategy
    --------------------
    Bookings are mutable (requested -> accepted -> completed), so we can't just
    append new rows: we re-process every booking updated in the last N days
    (var incremental_lookback_days) and upsert on booking_id.
      - BigQuery : MERGE, table partitioned by month + clustered
      - DuckDB   : delete+insert (local / CI)
#}

{{
    config(
        materialized='incremental',
        unique_key='booking_id',
        incremental_strategy=('merge' if target.type == 'bigquery' else 'delete+insert'),
        on_schema_change='append_new_columns',
        partition_by=(
            {'field': 'requested_at', 'data_type': 'timestamp', 'granularity': 'month'}
            if target.type == 'bigquery' else none
        ),
        cluster_by=(['company_id', 'current_status'] if target.type == 'bigquery' else none)
    )
}}

with bookings as (

    select * from {{ ref('int_bookings__pivoted') }}

    {% if is_incremental() %}
    where last_updated_at >= (
        select
            cast({{ dbt.dateadd('day', -1 * var('incremental_lookback_days'), 'max(last_updated_at)') }}
                 as {{ dbt.type_timestamp() }})
        from {{ this }}
    )
    {% endif %}

),

mentors as (

    select mentor_id, company_id from {{ ref('stg_platform__mentors') }}

),

reviews as (

    select booking_id, rating from {{ ref('stg_platform__reviews') }}

),

final as (

    select
        bookings.booking_id,
        bookings.student_id,
        bookings.mentor_id,
        mentors.company_id,
        bookings.current_status,

        -- lifecycle timestamps
        bookings.requested_at,
        bookings.scheduled_at,
        bookings.responded_at,
        bookings.accepted_at,
        bookings.declined_at,
        bookings.expired_at,
        bookings.cancelled_at,
        bookings.completed_at,

        -- funnel flags
        bookings.responded_at is not null                    as is_responded,
        bookings.accepted_at is not null                     as is_accepted,
        bookings.current_status = 'completed'                as is_completed,

        -- durations
        round(
            {{ dbt.datediff('bookings.requested_at', 'bookings.responded_at', 'minute') }} / 60.0
        , 2)                                                 as response_time_hours,
        {{ dbt.datediff('bookings.requested_at', 'bookings.scheduled_at', 'day') }}
                                                             as lead_time_days,

        reviews.rating,
        bookings.last_updated_at

    from bookings
    left join mentors
        on bookings.mentor_id = mentors.mentor_id
    left join reviews
        on bookings.booking_id = reviews.booking_id

)

select * from final
