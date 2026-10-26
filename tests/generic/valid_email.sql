{#
    Custom generic test: fails on rows whose email is not normalised
    (lowercase, trimmed) or doesn't look like an email at all.
    Usage in YAML:   data_tests: [valid_email]
#}
{% test valid_email(model, column_name) %}

select {{ column_name }}
from {{ model }}
where {{ column_name }} is not null
  and (
       {{ column_name }} != lower(trim({{ column_name }}))
    or {{ column_name }} not like '%_@_%._%'
  )

{% endtest %}
