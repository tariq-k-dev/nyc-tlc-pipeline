-- Distance outliers as a *rate*, not a row count. TLC data contains a long tail of
-- meter errors (0.5 mi trips billed as 300 mi). Deleting every outlier hides real
-- long-haul trips; the defensible rule is "the tail must stay under a threshold",
-- so this test fails when the tail grows, not when a single bad row appears.
--
-- Measured on 2025-01: 0.005% of rows exceed 100 mi, and the 99.99th percentile is
-- 58 mi — so a 0.1% ceiling is ~20x headroom and still catches a broken source file.
with stats as (

    select
        count(*)                                                  as total_rows,
        sum(case when trip_distance_mi > 100 then 1 else 0 end)    as rows_over_100_mi
    from {{ ref('fct_trips') }}

)

select
    total_rows,
    rows_over_100_mi,
    round(rows_over_100_mi * 100.0 / nullif(total_rows, 0), 4) as pct_over_100_mi
from stats
where rows_over_100_mi * 100.0 / nullif(total_rows, 0) > 0.1
