{#
    Schema strategy
    ----------------
    - prod  : models land in clean schemas      -> staging, core, finance...
    - other : schemas are prefixed by the target -> dbt_mateo_staging, main_core...
      so that every developer / CI run is isolated and never overwrites prod.
#}
{% macro generate_schema_name(custom_schema_name, node) -%}

    {%- set default_schema = target.schema -%}

    {%- if custom_schema_name is none -%}
        {{ default_schema }}
    {%- elif target.name == 'prod' -%}
        {{ custom_schema_name | trim }}
    {%- else -%}
        {{ default_schema }}_{{ custom_schema_name | trim }}
    {%- endif -%}

{%- endmacro %}
