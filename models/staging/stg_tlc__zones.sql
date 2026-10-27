{{ config(materialized='table') }}

-- Bootstrapped from the TLC zone lookup (264 rows). Replace seeds/taxi_zone_lookup.csv
-- with the full file: curl -o seeds/taxi_zone_lookup.csv \
--   https://d37ci6vzurychx.cloudfront.net/misc/taxi_zone_lookup.csv
-- dbt seed --select taxi_zone_lookup && dbt run --select stg_tlc__zones
select
    cast(LocationID as integer) as zone_id,
    Borough                     as borough,
    Zone                        as zone_name,
    service_zone
from {{ ref('taxi_zone_lookup') }}
