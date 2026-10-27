-- Cross-model reconciliation: the mart must agree with the fact table.
-- This is the test that catches a bad join or a double-count in a grouping.
with fact as (
    select round(sum(total_amount_usd), 2) as revenue
    from {{ ref('fct_trips') }}
),

mart as (
    select round(sum(gross_revenue_usd), 2) as revenue
    from {{ ref('fct_daily_demand') }}
)

select
    fact.revenue  as fct_revenue,
    mart.revenue  as mart_revenue
from fact
cross join mart
where abs(fact.revenue - mart.revenue) > 1.0   -- $1 tolerance for float rounding
