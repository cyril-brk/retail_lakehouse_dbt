{% docs dim_customers %}
Customer dimension — one row per customer.

Includes derived RFM-style attributes computed from order history:
- `first_order_at` / `most_recent_order_at`
- `lifetime_orders`
- `lifetime_value` (sum of order amounts)

Reusable **doc blocks** like this one keep long descriptions out of the YAML and
can be referenced from a model's `description` in the properties YAML.
{% raw %}(Reference syntax: `{{ doc("dim_customers") }}` — wrapped in a raw block
here so dbt doesn't try to evaluate it inside this doc block.){% endraw %}
{% enddocs %}
