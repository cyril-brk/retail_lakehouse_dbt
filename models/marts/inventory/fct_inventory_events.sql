-- =============================================================================
-- MART / FACT — INCREMENTAL model.
-- Instead of rebuilding the whole table every run, dbt only processes NEW rows
-- since the last run (based on the event_at watermark) and MERGEs them in.
--
-- Data-flow type: INCREMENTAL (merge).
--   * First run (or `--full-refresh`): builds from all source rows.
--   * Later runs: the is_incremental() block filters to rows newer than what's
--     already loaded, and unique_key drives an upsert (MERGE) on Delta.
-- =============================================================================
{{
    config(
        materialized='incremental',
        unique_key='event_id',
        incremental_strategy='merge',
        on_schema_change='sync_all_columns',
        liquid_clustered_by=['event_date', 'store_id']
    )
}}

with events as (
    select * from {{ ref('stg_inventory_events') }}

    {% if is_incremental() %}
    -- Only scan source rows newer than the max already loaded.
    -- `this` = the existing table being built.
    where event_at > (select coalesce(max(event_at), '1900-01-01') from {{ this }})
    {% endif %}
)

select
    event_id,
    store_id,
    product_id,
    event_type,
    quantity_change,
    event_at,
    cast(event_at as date) as event_date
from events
