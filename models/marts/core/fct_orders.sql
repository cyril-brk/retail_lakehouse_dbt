-- MART / FACT: one row per order. Materialized as a Delta table and demonstrates
-- Databricks-specific config: LIQUID CLUSTERING for read performance.
{{
    config(
        materialized='table',
        liquid_clustered_by=['ordered_date', 'store_id'],
        tblproperties={'delta.autoOptimize.optimizeWrite': 'true'}
    )
}}

with orders as (
    select * from {{ ref('int_orders_enriched') }}
)

select
    {{ dbt_utils.generate_surrogate_key(['order_id']) }} as order_sk,
    order_id,
    customer_id,
    store_id,
    ordered_at,
    cast(ordered_at as date) as ordered_date,
    status,
    is_returned,
    n_line_items,
    total_quantity,
    order_amount,
    amount_paid,
    -- data-quality signal: did the customer under/overpay?
    round(order_amount - amount_paid, 2) as payment_gap
from orders
