{{ config(materialized='view') }}

-- Reads the TLC's monthly Parquet files in place. Widen the window by changing
-- start_month / end_month in dbt_project.yml — no edits to this file.
with source as (

    select *
    from read_parquet(
        {{ tlc_parquet_paths(var('start_month'), var('end_month')) }},
        union_by_name = true
    )

),

renamed as (

    select
        -- Surrogate key. TLC publishes no trip identifier, so we hash the full
        -- business row. A narrower hash (vendor + pickup + dropoff + zones + amount)
        -- collides on ~1 row per 3.3M: two genuinely different trips can share those
        -- five values. Including every measure makes the key unique by construction,
        -- and any remaining duplicate is then a real duplicate row we *want* to drop.
        {{ dbt_utils.generate_surrogate_key([
            'VendorID', 'tpep_pickup_datetime', 'tpep_dropoff_datetime',
            'passenger_count', 'trip_distance', 'PULocationID', 'DOLocationID',
            'payment_type', 'fare_amount', 'extra', 'mta_tax', 'tip_amount',
            'tolls_amount', 'improvement_surcharge', 'total_amount',
            'congestion_surcharge', 'Airport_fee'
        ]) }}                                    as trip_sk,
        cast(VendorID as integer)                as vendor_id,
        cast(tpep_pickup_datetime as timestamp)  as pickup_at,
        cast(tpep_dropoff_datetime as timestamp) as dropoff_at,
        cast(PULocationID as integer)            as pickup_zone_id,
        cast(DOLocationID as integer)            as dropoff_zone_id,
        cast(passenger_count as integer)         as passenger_count,
        cast(trip_distance as double)            as trip_distance_mi,
        cast(fare_amount as double)              as fare_amount_usd,
        cast(tip_amount as double)               as tip_amount_usd,
        cast(tolls_amount as double)             as tolls_amount_usd,
        cast(total_amount as double)             as total_amount_usd,
        cast(payment_type as integer)            as payment_type_id
    from source

),

cleaned as (

    select *
    from renamed
    where pickup_at is not null
      and dropoff_at is not null
      and dropoff_at > pickup_at                                     -- no negative durations
      and dropoff_at - pickup_at <= interval 24 hour                  -- meter left running / clock error
      and pickup_at >= cast('{{ var("start_month") }}-01' as timestamp)  -- clamp to requested window
      and trip_distance_mi > 0                                       -- no zero-mileage rows
      and total_amount_usd > 0                                       -- no refunds / voids
      and cast(pickup_at as date) < current_date - interval 1 day     -- never trust today's partial file

)

select * from cleaned
