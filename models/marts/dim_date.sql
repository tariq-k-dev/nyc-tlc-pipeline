{{ config(materialized='table') }}

-- Generated date spine. Every day in the reporting window exists even when no trips
-- were taken (weather, holidays, data gaps). Without this, a line chart silently
-- drops days instead of plotting zero — which reads as a trend that isn't there.
with days as (

    select
        unnest(
            generate_series(
                cast('{{ var("reporting_start_date") }}' as date),
                cast(current_date as date),
                interval 1 day
            )
        ) as date_day

)

select
    cast(date_day as date)                                                    as date_day,
    extract(year from date_day)                                               as year,
    extract(month from date_day)                                              as month,
    extract(day from date_day)                                                as day_of_month,
    extract(dow from date_day)                                                as day_of_week,
    dayname(date_day)                                                         as day_name,
    case when extract(dow from date_day) in (0, 6) then true else false end    as is_weekend
from days
