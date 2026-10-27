-- Cash tips are not recorded by the meter, so cash trips should have zero tip.
-- A cash trip with a tip means tip_amount is being populated from somewhere else,
-- and any tip-rate metric is measuring two different things at once.
select
    payment_method,
    count(*)              as offending_rows,
    round(sum(tip_amount_usd), 2) as tipped_usd
from {{ ref('fct_trips') }}
where payment_method = 'cash'
  and tip_amount_usd > 0
group by 1
having count(*) > 1000   -- tolerate a data-quality tail, alert on a systematic problem
