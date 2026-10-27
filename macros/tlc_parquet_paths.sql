{% macro tlc_parquet_paths(start_month, end_month=none) %}
    {#
        Emits an explicit DuckDB list of monthly TLC Parquet URLs, inclusive of both
        months. An explicit list is required because the CloudFront distribution does
        not answer wildcard requests — `yellow_tripdata_2025-*.parquet` returns
        HTTP 403, while the named files return 200.

        Month arithmetic runs on integers (year*12 + month) so February and year
        boundaries are not special cases.
    #}
    {%- set base = 'https://d37ci6vzurychx.cloudfront.net/trip-data/yellow_tripdata_' -%}

    {%- set sy = start_month.split('-')[0] | int -%}
    {%- set sm = start_month.split('-')[1] | int -%}
    {%- set ey = (end_month or start_month).split('-')[0] | int -%}
    {%- set em = (end_month or start_month).split('-')[1] | int -%}

    {%- set start_idx = sy * 12 + (sm - 1) -%}
    {%- set end_idx = ey * 12 + (em - 1) -%}

    {%- set urls = [] -%}
    {%- for idx in range(start_idx, end_idx + 1) -%}
        {%- set y = idx // 12 -%}
        {%- set m = idx % 12 + 1 -%}
        {%- do urls.append("'" ~ base ~ "%04d-%02d" % (y, m) ~ ".parquet'") -%}
    {%- endfor -%}

    {{ return('[' ~ urls | join(', ') ~ ']') }}
{% endmacro %}
