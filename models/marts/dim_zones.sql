{{ config(materialized='table') }}

select
    zone_id,
    zone_name,
    borough,
    service_zone
from {{ ref('stg_tlc__zones') }}
