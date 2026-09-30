-- =============================================================================
-- 02_permissions.sql
-- Unity Catalog grants for the dbt service principal / developer group.
-- Run as a catalog owner or metastore admin. Replace <<< PLACEHOLDER >>>s.
--
-- Principle of least privilege:
--   * dbt needs to CREATE/READ/WRITE inside the project catalog.
--   * It needs USE CATALOG + USE SCHEMA to traverse the namespace.
--   * Downstream BI/consumers only need SELECT on the marts schemas.
-- =============================================================================

-- <<< PLACEHOLDER >>> The principal dbt runs as.
--   DEV: your user email, e.g. 'first.last@company.com'
--   PROD/CI: the service principal's application id (a GUID) or its display name.
-- Set these once and reuse:
--   :dbt_principal      -> e.g. '00000000-0000-0000-0000-000000000000' (SP app id)
--   :consumer_group     -> e.g. 'bi_readers' (a UC account group)

-- ---- Catalog-level -----------------------------------------------------------
GRANT USE CATALOG      ON CATALOG retail_lakehouse_dbt TO `<<< dbt_principal >>>`;
GRANT CREATE SCHEMA    ON CATALOG retail_lakehouse_dbt TO `<<< dbt_principal >>>`;

-- ---- Raw schema (read-only for dbt sources) ---------------------------------
GRANT USE SCHEMA       ON SCHEMA  retail_lakehouse_dbt.raw TO `<<< dbt_principal >>>`;
GRANT SELECT           ON SCHEMA  retail_lakehouse_dbt.raw TO `<<< dbt_principal >>>`;

-- ---- dbt-managed schemas: dbt CREATEs them, but the principal needs the ------
-- ---- rights to create + own objects. Simplest is broad rights in the catalog:
GRANT CREATE TABLE     ON CATALOG retail_lakehouse_dbt TO `<<< dbt_principal >>>`;
GRANT MODIFY           ON CATALOG retail_lakehouse_dbt TO `<<< dbt_principal >>>`;
GRANT SELECT           ON CATALOG retail_lakehouse_dbt TO `<<< dbt_principal >>>`;

-- ---- Consumers (BI tools, analysts) — read the published marts only ----------
-- (These schemas are created by dbt on first run; grant after the first build,
--  or grant at catalog level and rely on schema ownership.)
-- GRANT USE CATALOG ON CATALOG retail_lakehouse_dbt             TO `<<< consumer_group >>>`;
-- GRANT USE SCHEMA  ON SCHEMA  retail_lakehouse_dbt.dbt_core    TO `<<< consumer_group >>>`;
-- GRANT SELECT      ON SCHEMA  retail_lakehouse_dbt.dbt_core    TO `<<< consumer_group >>>`;

-- ---- SQL Warehouse access (compute) -----------------------------------------
-- Grant the principal CAN_USE on the SQL Warehouse via the UI or CLI:
--   Settings > SQL Warehouses > (warehouse) > Permissions > Can use
-- (There is no GRANT statement for warehouse compute; it is an object ACL.)
