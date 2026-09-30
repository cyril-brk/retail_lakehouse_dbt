-- =============================================================================
-- SNAPSHOT — SCD Type 2 history.
-- Captures how a product's price/name/category change OVER TIME. Each run dbt
-- compares the current source rows to the snapshot table and closes/opens
-- validity windows (dbt_valid_from / dbt_valid_to), giving you full history.
--
-- Data-flow type: SNAPSHOT (SCD2).
-- Strategy 'check' = create a new version whenever any watched column changes.
-- (Use strategy 'timestamp' with an updated_at column when the source has a
--  reliable last-modified timestamp — see snap_orders.sql.)
-- =============================================================================
{% snapshot snap_products %}
{{
    config(
        target_schema='snapshots',
        unique_key='product_id',
        strategy='check',
        check_cols=['price', 'product_name', 'category']
    )
}}

select
    product_id,
    sku,
    product_name,
    category,
    price,
    updated_at
from {{ ref('stg_products') }}

{% endsnapshot %}
