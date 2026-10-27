-- Ad-hoc analysis, NOT materialised. `dbt compile --select demand_by_hour` renders
-- this to target/compiled/ so a question can be answered without adding a model.
-- The point: hourly demand reveals the 5-6pm Manhattan peak that daily averages hide.
select
    extract(hour from pickup_at)  as hour_of_day,
    pickup_borough,
    count(*)                      as trips,
    round(avg(tip_rate), 3)       as avg_tip_rate
from {{ ref('fct_trips') }}
where pickup_borough in ('Manhattan', 'Queens', 'Brooklyn')
group by 1, 2
order by 1, 2
