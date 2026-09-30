-- =============================================================================
-- 03_load_raw_copy_into.sql
-- Bulk-load the project CSVs into the raw Delta tables.
-- Prereq: run 01_setup_databricks.sql AND upload data/raw_*.csv to the volume
--         /Volumes/retail_lakehouse_dbt/raw/landing/  (see README).
-- Replace the catalog placeholder if you renamed it.
--
-- WHY THE CAST(...) WRAPPER:
--   COPY INTO reads CSV columns as STRING (a CSV has no schema). Loading STRING
--   straight into the typed raw tables fails with DELTA_FAILED_TO_MERGE_FIELDS
--   (STRING source vs BIGINT/INT/DECIMAL/TIMESTAMP target). Wrapping the source
--   in `(SELECT CAST(col AS <type>) ... FROM 'path')` casts each column to the
--   table's type before the write, so the schemas match. Column names come from
--   the CSV header (header=true), so we reference them by name.
-- =============================================================================
USE CATALOG retail_lakehouse_dbt;
USE SCHEMA raw;

COPY INTO raw_customers
FROM (
  SELECT
    CAST(customer_id AS BIGINT)   AS customer_id,
    first_name,
    last_name,
    email,
    country_code,
    CAST(signup_at AS TIMESTAMP)  AS signup_at
  FROM '/Volumes/retail_lakehouse_dbt/raw/landing/raw_customers.csv'
)
FILEFORMAT = CSV FORMAT_OPTIONS ('header'='true');

COPY INTO raw_products
FROM (
  SELECT
    CAST(product_id AS BIGINT)        AS product_id,
    sku,
    product_name,
    category,
    CAST(price AS DECIMAL(10,2))      AS price,
    CAST(updated_at AS TIMESTAMP)     AS updated_at
  FROM '/Volumes/retail_lakehouse_dbt/raw/landing/raw_products.csv'
)
FILEFORMAT = CSV FORMAT_OPTIONS ('header'='true');

COPY INTO raw_stores
FROM (
  SELECT
    CAST(store_id AS BIGINT)  AS store_id,
    store_name,
    country_code,
    store_type
  FROM '/Volumes/retail_lakehouse_dbt/raw/landing/raw_stores.csv'
)
FILEFORMAT = CSV FORMAT_OPTIONS ('header'='true');

COPY INTO raw_orders
FROM (
  SELECT
    CAST(order_id AS BIGINT)      AS order_id,
    CAST(customer_id AS BIGINT)   AS customer_id,
    CAST(store_id AS BIGINT)      AS store_id,
    CAST(ordered_at AS TIMESTAMP) AS ordered_at,
    CAST(updated_at AS TIMESTAMP) AS updated_at,
    status
  FROM '/Volumes/retail_lakehouse_dbt/raw/landing/raw_orders.csv'
)
FILEFORMAT = CSV FORMAT_OPTIONS ('header'='true');

COPY INTO raw_order_items
FROM (
  SELECT
    CAST(order_item_id AS BIGINT)    AS order_item_id,
    CAST(order_id AS BIGINT)         AS order_id,
    CAST(product_id AS BIGINT)       AS product_id,
    CAST(quantity AS INT)            AS quantity,
    CAST(unit_price AS DECIMAL(10,2)) AS unit_price,
    CAST(line_total AS DECIMAL(12,2)) AS line_total
  FROM '/Volumes/retail_lakehouse_dbt/raw/landing/raw_order_items.csv'
)
FILEFORMAT = CSV FORMAT_OPTIONS ('header'='true');

COPY INTO raw_payments
FROM (
  SELECT
    payment_id,
    CAST(order_id AS BIGINT)      AS order_id,
    payment_method,
    CAST(amount AS DECIMAL(12,2)) AS amount,
    CAST(paid_at AS TIMESTAMP)    AS paid_at
  FROM '/Volumes/retail_lakehouse_dbt/raw/landing/raw_payments.csv'
)
FILEFORMAT = CSV FORMAT_OPTIONS ('header'='true');

COPY INTO raw_inventory_events
FROM (
  SELECT
    CAST(event_id AS BIGINT)        AS event_id,
    CAST(store_id AS BIGINT)        AS store_id,
    CAST(product_id AS BIGINT)      AS product_id,
    event_type,
    CAST(quantity_change AS INT)    AS quantity_change,
    CAST(event_at AS TIMESTAMP)     AS event_at
  FROM '/Volumes/retail_lakehouse_dbt/raw/landing/raw_inventory_events.csv'
)
FILEFORMAT = CSV FORMAT_OPTIONS ('header'='true');

-- Sanity check
SELECT 'raw_customers'  AS tbl, count(*) FROM raw_customers
UNION ALL SELECT 'raw_products',        count(*) FROM raw_products
UNION ALL SELECT 'raw_stores',          count(*) FROM raw_stores
UNION ALL SELECT 'raw_orders',          count(*) FROM raw_orders
UNION ALL SELECT 'raw_order_items',     count(*) FROM raw_order_items
UNION ALL SELECT 'raw_payments',        count(*) FROM raw_payments
UNION ALL SELECT 'raw_inventory_events',count(*) FROM raw_inventory_events;
