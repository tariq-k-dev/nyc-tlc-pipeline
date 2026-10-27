{{ config(
    materialized='incremental',
    unique_key='trip_sk',
    incremental_strategy='merge',
    on_schema_change='append_new_columns',
    cluster_by=['trip_date']
) }}

-- Incremental fact table. Strategy notes, because this is the design question an
-- interviewer will actually ask:
--
--   merge  -> handles both new trips and corrected rows, keyed on trip_sk. Correct
--             choice here because TLC republishes months and backfills corrections.
--   append -> cheaper, but silently duplicates any corrected trip. Wrong for this data.
--
-- The lookback window exists because trips arrive late: a February file will contain
-- January pickups. Re-scanning the last N days catches them without a full refresh.
with trips as (

    select * from {{ ref('int_trips_enriched') }}

    {% if is_incremental() %}
    where trip_date >= (
        select coalesce(max(trip_date), date '1900-01-01') - interval {{ var('incremental_lookback_days') }} day
        from {{ this }}
    )
    {% endif %}

)

select * from trips
