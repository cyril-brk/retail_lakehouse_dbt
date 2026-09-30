-- MART (aggregate): monthly revenue per category vs. its target (from a seed).
-- Shows a fact-to-seed join and a % attainment metric — feeds the exposure.
with items as (
    select
        category,
        date_trunc('month', ordered_date) as revenue_month,
        sum(line_total)                   as revenue
    from {{ ref('fct_order_items') }}
    where status not in ('cancelled', 'returned')
    group by category, date_trunc('month', ordered_date)
),

targets as (
    select * from {{ ref('category_targets') }}
)

select
    i.revenue_month,
    i.category,
    i.revenue,
    t.monthly_revenue_target,
    round(100.0 * i.revenue / nullif(t.monthly_revenue_target, 0), 1) as pct_of_target
from items i
left join targets t on i.category = t.category
