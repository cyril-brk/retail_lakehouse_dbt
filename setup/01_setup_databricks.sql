-- =============================================================================
-- 01_setup_databricks.sql
-- One-time Databricks/Unity Catalog setup for the dbt_retail_lakehouse project.
-- Run this in a Databricks SQL Editor / notebook attached to your SQL Warehouse,
-- OR via the CLI (see README "Load raw data" section).
--
-- Replace every <<< PLACEHOLDER >>> before running.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Catalog + landing schema for the RAW source data.
--    dbt writes its own schemas (staging/core/finance/...) automatically;
--    here we only create the catalog and the "raw" landing zone dbt reads from.
-- -----------------------------------------------------------------------------
-- <<< PLACEHOLDER: catalog name >>>  must match DATABRICKS_CATALOG in .env
CREATE CATALOG IF NOT EXISTS retail_lakehouse_dbt
  COMMENT 'Learning project: dbt on Databricks (retail lakehouse).';

USE CATALOG retail_lakehouse_dbt;

CREATE SCHEMA IF NOT EXISTS raw
  COMMENT 'Raw landing data loaded from the CSVs in ../data/. dbt sources point here.';

USE SCHEMA raw;

-- -----------------------------------------------------------------------------
-- 2. Raw tables (Delta). Column layout matches scripts/generate_data.py output.
--    We create them empty here; data is loaded in step 3.
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS raw_customers (
  customer_id   BIGINT,
  first_name    STRING,
  last_name     STRING,
  email         STRING,
  country_code  STRING,
  signup_at     TIMESTAMP
) USING DELTA;

CREATE TABLE IF NOT EXISTS raw_products (
  product_id    BIGINT,
  sku           STRING,
  product_name  STRING,
  category      STRING,
  price         DECIMAL(10,2),
  updated_at    TIMESTAMP
) USING DELTA;

CREATE TABLE IF NOT EXISTS raw_stores (
  store_id      BIGINT,
  store_name    STRING,
  country_code  STRING,
  store_type    STRING
) USING DELTA;

CREATE TABLE IF NOT EXISTS raw_orders (
  order_id      BIGINT,
  customer_id   BIGINT,
  store_id      BIGINT,
  ordered_at    TIMESTAMP,
  updated_at    TIMESTAMP,
  status        STRING
) USING DELTA;

CREATE TABLE IF NOT EXISTS raw_order_items (
  order_item_id BIGINT,
  order_id      BIGINT,
  product_id    BIGINT,
  quantity      INT,
  unit_price    DECIMAL(10,2),
  line_total    DECIMAL(12,2)
) USING DELTA;

CREATE TABLE IF NOT EXISTS raw_payments (
  payment_id     STRING,
  order_id       BIGINT,
  payment_method STRING,
  amount         DECIMAL(12,2),
  paid_at        TIMESTAMP
) USING DELTA;

CREATE TABLE IF NOT EXISTS raw_inventory_events (
  event_id        BIGINT,
  store_id        BIGINT,
  product_id      BIGINT,
  event_type      STRING,
  quantity_change INT,
  event_at        TIMESTAMP
) USING DELTA;

-- -----------------------------------------------------------------------------
-- 3. Load the CSVs.
--    EASIEST PATH: upload the files in ../data/ to a UC Volume, then COPY INTO.
--    Create a volume and upload (see README for the `databricks fs cp` commands):
-- -----------------------------------------------------------------------------
CREATE VOLUME IF NOT EXISTS retail_lakehouse_dbt.raw.landing
  COMMENT 'Upload the project ../data/*.csv here, then COPY INTO the raw tables.';

-- After uploading data/raw_*.csv to /Volumes/retail_lakehouse_dbt/raw/landing/,
-- run one COPY INTO per table. Because a CSV has no schema, COPY INTO reads every
-- column as STRING; cast each column to the table's type so the load doesn't fail
-- with DELTA_FAILED_TO_MERGE_FIELDS. Example (repeat for each table):
--
-- COPY INTO retail_lakehouse_dbt.raw.raw_customers
-- FROM (
--   SELECT
--     CAST(customer_id AS BIGINT)  AS customer_id,
--     first_name, last_name, email, country_code,
--     CAST(signup_at AS TIMESTAMP) AS signup_at
--   FROM '/Volumes/retail_lakehouse_dbt/raw/landing/raw_customers.csv'
-- )
-- FILEFORMAT = CSV FORMAT_OPTIONS ('header' = 'true');
--
-- (Full set of COPY INTO statements is in setup/03_load_raw_copy_into.sql)
