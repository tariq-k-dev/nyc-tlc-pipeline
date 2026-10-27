# NYC TLC — Analytics Engineering Pipeline

End-to-end ELT on NYC yellow-taxi data: **in-place Parquet ingestion → dbt staging →
intermediate → marts**, with data tests, a snapshot, an enforced data contract, and
CI that runs the whole thing on every push.

[![dbt build](https://github.com/tariq-k-dev/nyc-tlc-analytics-engineering/actions/workflows/dbt_ci.yml/badge.svg)](https://github.com/tariq-k-dev/nyc-tlc-analytics-engineering/actions/workflows/dbt_ci.yml)

## Why this exists

I wanted a project where the engineering decisions are defensible, not decorative.
Every choice below is one I can walk through in an interview:

| Decision | Choice | Why not the alternative |
|---|---|---|
| Warehouse | **DuckDB** (embedded, file-based) | Snowflake/BigQuery cost money and expire on a trial clock. DuckDB needs no account, and the adapter surface is identical enough that porting is a `profiles.yml` change. |
| Ingestion | **Read Parquet in place** from CloudFront | No COPY/load step to maintain or re-run, and DuckDB pushes filters into the remote file — a month of trips aggregates in ~2 s. Real ELT starts at the transformation layer; copying first would have been decorating a tutorial. |
| Trip key | **Hash of the full business row** | A narrower hash (vendor + timestamps + zones + amount) collided on ~1 row per 3.3M in the January file. Hashing every measure makes the key unique by construction. |
| Incremental strategy | **merge** on `trip_sk`, 3-day lookback | `append` is cheaper but silently duplicates any corrected trip, and TLC republishes months. The lookback catches late-arriving records (a February file contains January pickups). |
| Date dimension | **Generated spine** | Without it, a line chart silently drops zero-trip days and reads as a trend that isn't there. |
| Snapshot | **SCD2 on `dim_zones`** | TLC renames and re-buckets zones; without a snapshot, "which zone was this trip in at the time" is lost on every refresh. |
| Contract | **Enforced on `fct_trips`** | Adding a column to the model without declaring its type fails the build — which is the point. |

## Lineage

```
yellow_tripdata_*.parquet  (public, CloudFront)
        │
        ▼
   stg_tlc__trips        view      rename, cast, dedupe-safe hash, quality filters
   stg_tlc__zones        table     from seeds/taxi_zone_lookup.csv (265 zones)
        │
        ▼
   int_trips_enriched    ephemeral joins zones, derives duration / tip_rate / payment_method
        │
        ▼
   fct_trips             incremental (merge)  3.3M rows for 2025-01
   dim_zones             table
   dim_date              table (generated spine)
        │
        ▼
   fct_daily_demand      table    BI-facing: trips, revenue, avg fare by borough/day
```

## Results (2025-01, real run)

- **3,324,144** trips after cleaning, from 3.36M raw rows (99.0% retained)
- **243** borough-day rows in `fct_daily_demand`; **265** zones; **664** days in the spine
- **41 data tests** green, including 4 singular business-rule tests
- Full build: `PASS=41 WARN=0 ERROR=0` in ~10 s; `dbt docs generate` produces a lineage graph

### What the data says

**1. A single city-wide average is meaningless.** Average trips per borough-day:

| Borough | Avg trips/day | % paid by card | Avg tip rate (all) | Avg tip rate (card only) | Avg fare |
|---|---|---|---|---|---|
| Manhattan | 92,808 | 73.9% | 20.6% | 26.8% | $22.36 |
| Queens | 8,780 | 72.1% | 15.5% | 21.1% | $72.05 |
| Brooklyn | 1,946 | 36.2% | 3.1% | 6.2% | $27.70 |
| Bronx | — | 40.6% | 0.6% | 1.2% | $32.46 |

**2. The "Brooklyn tips 3% vs Manhattan 21%" headline is mostly a measurement artefact.**
The taximeter only records tips on card payments — cash tips are invisible to the
data. Card share in Brooklyn is 36% versus 74% in Manhattan, so most of the gap is
*how the trip was paid for*, not generosity. Restricting to card trips narrows it from
a 6.8× gap to 4.3×, and even that residual is likely trip-mix (Brooklyn card trips are
shorter and more local). This is the analysis I'd actually present: a naive average
here gets repeated in a meeting and is wrong.

**3. Queens has a $72 average fare on a $22 Manhattan baseline** — the airports.
JFK and LaGuardia are Queens zones, so the borough average is dominated by a handful of
long flat-rate airport runs, not by typical Queens trips. Median would have been the
honest summary statistic; this is why `avg_fare_usd` in the mart is labelled as a mean.

**4. Outliers are bounded, not deleted.** 0.005% of rows exceed 100 miles and 13 rows
had meter durations over 24 hours (worst: 5,626 minutes for a 6.5-mile trip — a meter
left running). Those 13 are dropped; the distance tail is kept and policed by a
*rate-based* test, because deleting every outlier also deletes real long-haul trips.

## Run it

```bash
uv sync
uv run dbt deps    --profiles-dir profiles
uv run dbt build   --profiles-dir profiles     # seed → models → snapshot → tests
uv run dbt docs generate --profiles-dir profiles
uv run dbt docs serve    --profiles-dir profiles   # open the lineage graph
```

Or via the Makefile: `make install && make build && make serve`.

Inspect a mart without a BI tool:

```bash
uv run dbt show --profiles-dir profiles --select fct_daily_demand --limit 20
```

## Layout

```
models/staging/       stg_* views: rename, cast, filter. One per source.
models/intermediate/  int_* ephemeral: joins and derivations, never materialised.
models/marts/         fct_* / dim_*: the tables a BI tool or an analyst consumes.
snapshots/            SCD2 history for mutable dimensions.
tests/                singular tests: business rules that generic tests can't express.
analyses/             ad-hoc queries rendered by `dbt compile`, never materialised.
macros/               tlc_parquet_paths(): month-range → explicit file list.
seeds/                taxi_zone_lookup.csv, version-controlled.
profiles/             profiles.yml lives in-repo so runs are reproducible.
```

## Known limits

- **DuckDB does not teach warehouse operations** — roles, grants, warehouse sizing,
  clustering, cost control. Those are Snowflake/BigQuery concerns. This project
  demonstrates the transformation layer, not the platform administration around it.
- CloudFront returns **403 for wildcard paths**, so the file list is generated
  explicitly by `tlc_parquet_paths()` rather than a glob.
- One month is loaded by default. Widen `start_month` / `end_month` in
  `dbt_project.yml` to extend the window; the incremental model then does real work.
- Cash tips are not recorded by the meter, so any tip metric is card-only. Stated
  rather than corrected, because it is a fact about the source.

## Data source

NYC Taxi & Limousine Commission, [TLC Trip Record Data](https://www.nyc.gov/site/tlc/about/tlc-trip-record-data.page).
Public domain. Zone lookup from the same distribution.
