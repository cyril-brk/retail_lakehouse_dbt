-- INTERMEDIATE model (EPHEMERAL — see dbt_project.yml).
-- Ephemeral models are NOT built as DB objects; dbt inlines them as CTEs into
-- whatever model ref()s them. Use them to share logic without materializing.
--
-- Here: enrich each order line with product attributes.
with order_items as (
    select * from {{ ref('stg_order_items') }}
),

products as (
    select * from {{ ref('stg_products') }}
)

select
    oi.order_item_id,
    oi.order_id,
    oi.product_id,
    p.product_name,
    p.category,
    oi.quantity,
    oi.unit_price,
    oi.line_total
from order_items oi
left join products p on oi.product_id = p.product_id
