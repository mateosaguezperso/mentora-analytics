{#
    Cross-database median (aggregate function).
    dbt has no built-in median macro, and every warehouse spells it differently,
    so we dispatch on the adapter:
      - BigQuery : APPROX_QUANTILES (exact PERCENTILE_CONT is analytic-only on BQ)
      - DuckDB   : native MEDIAN()
      - default  : ANSI ordered-set aggregate (Postgres, Snowflake...)
#}
{% macro median(column_name) -%}
    {{ return(adapter.dispatch('median', 'mentora_analytics')(column_name)) }}
{%- endmacro %}

{% macro default__median(column_name) -%}
    percentile_cont(0.5) within group (order by {{ column_name }})
{%- endmacro %}

{% macro bigquery__median(column_name) -%}
    approx_quantiles({{ column_name }}, 100)[offset(50)]
{%- endmacro %}

{% macro duckdb__median(column_name) -%}
    median({{ column_name }})
{%- endmacro %}
