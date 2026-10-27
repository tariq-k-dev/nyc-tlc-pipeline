-- Singular test: business rule that customer-facing reports depend on.
-- A negative or absurdly long duration means the meter timestamps are wrong, and
-- every average-duration number downstream is quietly biased. Fail loudly.
select
    trip_sk,
    trip_duration_min
from {{ ref('fct_trips') }}
where trip_duration_min < 0
   or trip_duration_min > 1440
