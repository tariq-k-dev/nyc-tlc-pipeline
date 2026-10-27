{% snapshot zones_snapshot %}

{{
    config(
        target_schema='snapshots',
        unique_key='zone_id',
        strategy='check',
        check_cols=['zone_name', 'borough', 'service_zone'],
    )
}}

-- SCD Type 2 on the zone lookup. TLC renames and re-buckets zones; without this the
-- history of "which zone was this trip in when it happened" is lost on every refresh.
select * from {{ ref('stg_tlc__zones') }}

{% endsnapshot %}
