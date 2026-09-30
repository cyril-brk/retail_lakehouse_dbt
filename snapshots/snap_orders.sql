-- SNAPSHOT (SCD2) using the TIMESTAMP strategy.
-- Tracks order status changes over time using the source `updated_at` column.
-- dbt opens a new version whenever updated_at advances for a given order_id.
{% snapshot snap_orders %}
{{
    config(
        target_schema='snapshots',
        unique_key='order_id',
        strategy='timestamp',
        updated_at='updated_at'
    )
}}

select
    order_id,
    customer_id,
    store_id,
    status,
    ordered_at,
    updated_at
from {{ ref('stg_orders') }}

{% endsnapshot %}
