{#
    Billing systems store amounts in cents (integers) to avoid float errors.
    Convert once, in staging, and never again downstream.
#}
{% macro cents_to_euros(column_name, scale=2) -%}
    round(cast({{ column_name }} as {{ dbt.type_numeric() }}) / 100, {{ scale }})
{%- endmacro %}
