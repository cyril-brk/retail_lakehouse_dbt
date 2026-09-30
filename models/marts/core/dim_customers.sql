-- MART / DIMENSION: one row per customer with derived attributes + a
-- surrogate key. Materialized as a Delta TABLE (see dbt_project.yml).
with customers as (
    select * from {{ ref('stg_customers') }}
),

orders as (
    select * from {{ ref('int_orders_enriched') }}
),

customer_orders as (
    select
        customer_id,
        min(ordered_at)                          as first_order_at,
        max(ordered_at)                          as most_recent_order_at,
        count(*)                                 as lifetime_orders,
        sum(order_amount)                        as lifetime_value
    from orders
    group by customer_id
),

countries as (
    select * from {{ ref('country_codes') }}
)

select
    -- surrogate key from dbt_utils (hash of the natural key)
    {{ dbt_utils.generate_surrogate_key(['c.customer_id']) }} as customer_sk,
    c.customer_id,
    c.first_name,
    c.last_name,
    c.email,
    c.country_code,
    cn.country_name,
    cn.region,
    c.signed_up_at,
    co.first_order_at,
    co.most_recent_order_at,
    coalesce(co.lifetime_orders, 0) as lifetime_orders,
    coalesce(co.lifetime_value, 0)  as lifetime_value,
    case when co.lifetime_orders is null then false else true end as has_ordered
from customers c
left join customer_orders co on c.customer_id = co.customer_id
left join countries cn       on c.country_code = cn.country_code
