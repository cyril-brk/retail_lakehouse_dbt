-- MART / FACT: one row per order line (finest grain). Joins the ephemeral
-- enriched line items back to order + date context for BI slicing.
with items as (
    select * from {{ ref('int_order_items_enriched') }}
),

orders as (
    select order_id, customer_id, store_id, ordered_at, status
    from {{ ref('stg_orders') }}
)

select
    {{ dbt_utils.generate_surrogate_key(['i.order_item_id']) }} as order_item_sk,
    i.order_item_id,
    i.order_id,
    o.customer_id,
    o.store_id,
    i.product_id,
    i.product_name,
    i.category,
    o.ordered_at,
    cast(o.ordered_at as date) as ordered_date,
    o.status,
    i.quantity,
    i.unit_price,
    i.line_total
from items i
left join orders o on i.order_id = o.order_id
