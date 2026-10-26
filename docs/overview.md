{% docs __overview__ %}

# Mentora Analytics

Analytics layer of **Mentora**, a fictional B2B2C EdTech marketplace:
companies pay a monthly subscription so their employees can mentor students,
and students book career-orientation conversations with those mentors.

## Layers

| Layer | Schema | Materialization | Purpose |
|---|---|---|---|
| staging | `staging` | view | 1:1 with sources: rename, cast, normalise, dedupe |
| intermediate | `intermediate` | view | Reusable business logic (CDC pivot, MRR spine) |
| marts/core | `core` | table / incremental | Conformed facts & dimensions |
| marts/product | `product` | table | Activation, retention, mentor quality, account health |
| marts/finance | `finance` | table | MRR bridge, NRR, logo churn |

## Key definitions

- **Activated student**: completed a first conversation within 30 days of signup.
- **Retention**: share of a first-conversation cohort with a completed conversation in month *k* (exact month, not cumulative).
- **MRR**: end-of-month snapshot of active subscriptions.

Code: see the GitHub repository README.

{% enddocs %}
