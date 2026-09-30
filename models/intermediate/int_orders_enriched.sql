-- INTERMEDIATE (ephemeral): roll line items up to the order grain and attach
-- payment totals. Feeds fct_orders. Demonstrates fanning multiple staging
-- models into a reusable, order-grain building block.
with orders as (
    select * from {{ ref('stg_orders') }}
),

items as (
    select
        order_id,
        count(*)            as n_line_items,
        sum(quantity)       as total_quantity,
        sum(line_total)     as items_amount
    from {{ ref('int_order_items_enriched') }}
    group by order_id
),

payments as (
    select
        order_id,
        sum(amount) as amount_paid
    from {{ ref('stg_payments') }}
    group by order_id
)

select
    o.order_id,
    o.customer_id,
    o.store_id,
    o.ordered_at,
    o.status,
    o.is_returned,
    coalesce(i.n_line_items, 0)   as n_line_items,
    coalesce(i.total_quantity, 0) as total_quantity,
    coalesce(i.items_amount, 0)   as order_amount,
    coalesce(p.amount_paid, 0)    as amount_paid
from orders o
left join items i    on o.order_id = i.order_id
left join payments p on o.order_id = p.order_id
