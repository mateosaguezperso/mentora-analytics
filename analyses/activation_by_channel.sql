-- Metabase native question: 30-day activation rate by acquisition channel.
-- Run with `dbt compile -s activation_by_channel` and paste the compiled SQL.
-- Immature cohorts are excluded so the latest weeks don't drag the KPI down.

select
    acquisition_channel,
    count(*)                                                       as students,
    sum(case when is_activated then 1 else 0 end)                  as activated_students,
    round(avg(case when is_activated then 1.0 else 0.0 end), 3)   as activation_rate,
    round(avg(days_to_first_conversation), 1)                      as avg_days_to_first_conversation

from {{ ref('dim_students') }}
where is_activation_window_closed
group by acquisition_channel
order by activation_rate desc
