{{ config(materialized='table') }}

-- Daily demand by pickup borough. This is the mart a BI tool or an exec actually
-- consumes, so it is materialised as a table and kept narrow.
select
    trip_date,
    pickup_borough,
    count(*)                                  as trips,
    count(distinct pickup_zone_id)            as active_zones,
    round(sum(total_amount_usd), 2)           as gross_revenue_usd,
    round(avg(trip_distance_mi), 2)           as avg_distance_mi,
    round(avg(trip_duration_min), 2)          as avg_duration_min,
    round(avg(tip_rate), 4)                   as avg_tip_rate,
    round(
        sum(total_amount_usd) / nullif(count(*), 0), 2
    )                                         as avg_fare_usd
from {{ ref('fct_trips') }}
group by 1, 2
