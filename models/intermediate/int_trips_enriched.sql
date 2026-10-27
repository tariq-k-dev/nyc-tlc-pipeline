{{ config(materialized='ephemeral') }}

-- Ephemeral: never materialised, inlined as a CTE into whichever mart references it.
-- This is the join layer — it exists so fct_trips stays readable.
with trips as (

    select * from {{ ref('stg_tlc__trips') }}

),

zones as (

    select * from {{ ref('stg_tlc__zones') }}

),

enriched as (

    select
        t.trip_sk,
        cast(t.pickup_at as date)        as trip_date,
        t.pickup_at,
        t.dropoff_at,
        t.vendor_id,

        -- geography
        t.pickup_zone_id,
        pu.borough                       as pickup_borough,
        pu.zone_name                     as pickup_zone,
        t.dropoff_zone_id,
        do_.borough                      as dropoff_borough,
        do_.zone_name                    as dropoff_zone,

        -- measures
        t.passenger_count,
        t.trip_distance_mi,
        t.fare_amount_usd,
        t.tip_amount_usd,
        t.tolls_amount_usd,
        t.total_amount_usd,

        -- derived
        round(
            date_diff('second', t.pickup_at, t.dropoff_at) / 60.0, 2
        )                                as trip_duration_min,
        case
            when t.fare_amount_usd > 0
            then round(t.tip_amount_usd / t.fare_amount_usd, 4)
        end                              as tip_rate,
        case t.payment_type_id
            when 1 then 'credit_card'
            when 2 then 'cash'
            when 3 then 'no_charge'
            when 4 then 'dispute'
            when 5 then 'unknown'
            when 6 then 'voided'
            else 'other'
        end                              as payment_method,

        -- Dedupe rank. Because trip_sk hashes every business column, a repeated key
        -- means a genuinely duplicated row (TLC republishes corrected months), not a
        -- hash collision. Keep the record from the most recent load.
        row_number() over (
            partition by t.trip_sk
            order by t.dropoff_at desc
        )                                as _dedupe_rank
    from trips t
    left join zones pu  on t.pickup_zone_id  = pu.zone_id
    left join zones do_ on t.dropoff_zone_id = do_.zone_id

)

select
    trip_sk, trip_date, pickup_at, dropoff_at, vendor_id,
    pickup_zone_id, pickup_borough, pickup_zone,
    dropoff_zone_id, dropoff_borough, dropoff_zone,
    passenger_count, trip_distance_mi, trip_duration_min,
    fare_amount_usd, tip_amount_usd, tolls_amount_usd, total_amount_usd,
    tip_rate, payment_method
from enriched
where _dedupe_rank = 1
