# dbt on Databricks — Retail Lakehouse Learning Project

A hands-on dbt project designed to teach **every major dbt concept** while running
on **Databricks (Unity Catalog + SQL Warehouse)**. It models a small retail /
e-commerce business (customers, orders, products, stores, payments, inventory)
and walks the data from raw → staging → intermediate → marts, with snapshots,
incremental loads, tests, macros, seeds, exposures, and docs along the way.

> Everything Databricks-specific is a **placeholder** you fill in — search the repo
> for `<<< PLACEHOLDER >>>` and the environment variables in `.env.example`.

---

## 1. What you'll learn (dbt concept map)

| Concept | Where in this project | Data-flow / materialization |
|---|---|---|
| **Sources** | `models/staging/_sources.yml` | reads raw UC tables (not created by dbt) |
| **Seeds** | `seeds/*.csv` + `seeds/_seeds.yml` | small CSVs loaded as tables |
| **Staging models** | `models/staging/stg_*.sql` | **view** — clean/rename/cast, 1:1 with source |
| **Intermediate models** | `models/intermediate/int_*.sql` | **ephemeral** — inlined CTEs, no DB object |
| **Marts (dimensions/facts)** | `models/marts/**` | **table** — physical Delta tables for BI |
| **Incremental model** | `models/marts/inventory/fct_inventory_events.sql` | **incremental (merge)** — only new rows |
| **Snapshots (SCD2)** | `snapshots/snap_*.sql` | history tables (`check` + `timestamp` strategies) |
| **Generic tests** | every `_*.yml` | unique / not_null / accepted_values / relationships / ranges |
| **Singular tests** | `tests/*.sql` | custom business-rule tests (SELECT returns 0 rows = pass) |
| **Macros** | `macros/*.sql` | reusable SQL, custom schema names, grant operation |
| **Packages** | `packages.yml` | `dbt_utils`, `dbt_expectations` |
| **Documentation** | `_*.yml` descriptions + `*__docs.md` doc blocks | `dbt docs` site |
| **Exposures** | `models/marts/_exposures.yml` | downstream dashboards / ML in the lineage graph |
| **Analyses** | `analyses/*.sql` | compiled but not run |
| **Sources freshness** | `_sources.yml` `freshness:` | `dbt source freshness` |
| **Orchestration (DAB)** | `databricks.yml` + `resources/dbt_build.job.yml` | Lakeflow Job runs `dbt build` on serverless |
| **Databricks specifics** | throughout | Delta, `liquid_clustered_by`, `tblproperties`, UC 3-level names, OAuth SP |

### The data flow (lineage)

```
seeds (country_codes, category_targets) ─────────────┐
                                                      ▼
raw.* (UC tables)                            ┌── dim_customers ─┐
   │  source()                               │   dim_products   │
   ▼                                         │   dim_stores     │
stg_* (views) ── int_* (ephemeral) ── fct_orders / fct_order_items   ← marts (tables)
   │                                         │   mart_category_revenue
   │                                         └── fct_payments
   └── stg_inventory_events ── fct_inventory_events (INCREMENTAL) ── agg_current_stock

snapshots: snap_products (SCD2 check on price), snap_orders (SCD2 timestamp on status)
```

---

## 2. Databricks prerequisites (fill these in)

You need a Databricks workspace with Unity Catalog and a running **SQL Warehouse**.
Provide the following (placeholders live in `.env.example` and `profiles.yml`):

| Element | Placeholder / env var | Where to get it |
|---|---|---|
| **Workspace URL** | `DATABRICKS_HOST` | Browser address bar (no `https://`, no trailing `/`) |
| **SQL Warehouse HTTP path** | `DATABRICKS_HTTP_PATH` | SQL Warehouse → **Connection details** → HTTP path |
| **UC catalog** | `DATABRICKS_CATALOG` | You create it in `setup/01_setup_databricks.sql` |
| **Target schema** | `DATABRICKS_SCHEMA` | Your personal dev schema, e.g. `dbt_yourname` |
| **Dev auth: PAT** | `DATABRICKS_TOKEN` | User Settings → Developer → Access tokens |
| **Prod auth: Service Principal (OAuth M2M)** | `DATABRICKS_CLIENT_ID` / `DATABRICKS_CLIENT_SECRET` | Settings → Identity & access → Service principals → OAuth secret |

### Required permissions (Unity Catalog)

See `setup/02_permissions.sql` for the exact `GRANT` statements. In short, the dbt
principal (your user in dev; the **service principal** in prod) needs:

- `USE CATALOG` + `CREATE SCHEMA` on the project **catalog**
- `USE SCHEMA` + `SELECT` on the **`raw`** schema (sources)
- `CREATE TABLE` + `MODIFY` + `SELECT` in the catalog (dbt creates/writes marts)
- `CAN USE` on the **SQL Warehouse** (set via warehouse Permissions UI — not a SQL grant)
- BI consumers: `USE CATALOG` + `USE SCHEMA` + `SELECT` on the published mart schemas only

---

## 3. One-time setup

This project uses [**uv**](https://docs.astral.sh/uv/) (not pip) to manage the
Python environment. Install uv once: `curl -LsSf https://astral.sh/uv/install.sh | sh`.

```bash
# 3.1 Create the env + install dbt from pyproject.toml / uv.lock.
#     uv auto-fetches a compatible Python (3.9–3.12) and builds .venv/.
uv sync                                   # dbt-core + dbt-databricks

# 3.2 Configure connection secrets
cp .env.example .env                      # then edit .env with your values
set -a && source .env && set +a           # load env vars into the shell

# 3.3 Generate the synthetic raw datasets (already run once; re-run to refresh)
uv run python scripts/generate_data.py    # writes data/raw_*.csv
#   optional: uv run python scripts/generate_data.py --scale 5   # 5x more rows

# 3.4 Create the catalog, raw tables + a Volume  (run in Databricks SQL editor)
#     setup/01_setup_databricks.sql
# 3.5 Grant permissions (run as catalog owner)
#     setup/02_permissions.sql

# 3.6 Upload the CSVs to the UC Volume, then load them
./scripts/upload_data_to_volume.sh <PROFILE> <CATALOG>
#     then run setup/03_load_raw_copy_into.sql in the SQL editor
#     (03 wraps each source in SELECT ... CAST(...) so the STRING-typed CSV
#      columns match the typed raw tables — see the "Loading raw data" note below)

# 3.7 Install dbt packages + verify the connection
uv run dbt deps
uv run dbt debug --profiles-dir .
```

> **Running dbt:** prefix every `dbt` command with `uv run` (e.g. `uv run dbt build`),
> **or** activate the env once with `source .venv/bin/activate` and then call `dbt`
> directly. To add a package later: `uv add <pkg>`; to update the lock: `uv lock`.

> This repo keeps `profiles.yml` **in the project** and uses `--profiles-dir .` so
> everything is self-contained for learning. In real projects, prefer
> `~/.dbt/profiles.yml` to keep it out of source control.

---

## 4. dbt command reference (what each does)

Run these from the project root. Prefix each with `uv run` (or activate `.venv` first),
and add `--profiles-dir .` (this project's convention). Example: `uv run dbt build --profiles-dir .`.

### Core lifecycle

| Command | What it does |
|---|---|
| `dbt debug --profiles-dir .` | Test the connection + config. **Start here.** |
| `dbt deps` | Install packages from `packages.yml` into `dbt_packages/`. |
| `dbt seed --profiles-dir .` | Load `seeds/*.csv` into tables. |
| `dbt run --profiles-dir .` | Build all models (views/tables/incrementals) in dependency order. |
| `dbt snapshot --profiles-dir .` | Capture SCD2 history for `snapshots/*.sql`. |
| `dbt test --profiles-dir .` | Run all generic + singular tests. |
| `dbt build --profiles-dir .` | **Seed → run → snapshot → test in one DAG-aware pass.** The command you'll use most. |
| `dbt compile --profiles-dir .` | Render SQL (with Jinja resolved) into `target/compiled/` without running it. |
| `dbt clean` | Delete `target/` and `dbt_packages/`. |

### Selecting a subset (the `--select` / `-s` graph operators)

| Command | What it does |
|---|---|
| `dbt run -s stg_orders` | Build just one model. |
| `dbt run -s staging` | Build everything tagged/pathed under staging. |
| `dbt run -s stg_orders+` | A model **and everything downstream** of it. |
| `dbt run -s +fct_orders` | A model **and everything upstream** of it. |
| `dbt run -s +fct_orders+` | Full ancestry **and** descendants. |
| `dbt build -s marts.core` | Build one folder/package path. |
| `dbt run -s tag:staging` | Select by tag (tags set in `dbt_project.yml`). |
| `dbt build -s state:modified --state ./prev` | Only what changed vs a previous run (CI "slim" builds). |
| `dbt test -s source:retail_raw` | Test only the sources. |

### Incremental & snapshots

| Command | What it does |
|---|---|
| `dbt run -s fct_inventory_events` | Incremental run — processes only **new** events (merge). |
| `dbt run -s fct_inventory_events --full-refresh` | Rebuild the incremental table from scratch. |
| `dbt snapshot -s snap_products` | Record a new SCD2 version when watched columns change. |

> **Try the incremental loop:** run it once, then re-run `python3 scripts/generate_data.py --scale 2`,
> reload the raw table, and run `dbt run -s fct_inventory_events` again — only the new rows are merged in.

### Docs, freshness & operations

| Command | What it does |
|---|---|
| `dbt docs generate --profiles-dir .` | Build the documentation + lineage site. |
| `dbt docs serve` | Serve the docs locally at http://localhost:8080. |
| `dbt source freshness --profiles-dir .` | Check raw data recency against `_sources.yml` thresholds. |
| `dbt ls -s marts` | List resources matching a selector (no execution). |
| `dbt run-operation grant_select_on_schema --args '{schema: core, grantee: "bi_readers"}'` | Run a macro as a standalone operation (grants SELECT). |

### Handy flags

- `--target prod` — switch to the prod output in `profiles.yml` (OAuth SP auth).
- `--vars '{start_date: "2024-06-01"}'` — override project variables.
- `--full-refresh` — force a rebuild of incremental models.
- `--fail-fast` — stop on the first failure.
- `-t dev` / `-t prod` — short form of `--target`.

---

## 5. Orchestration — Databricks Asset Bundle (DAB)

The project ships as a **Databricks Asset Bundle** so you can deploy the dbt project
and an ad hoc Lakeflow Job with one command. Files:

- `databricks.yml` — bundle definition, variables (`catalog`, `schema`, `warehouse_id`),
  and `dev` / `prod` targets.
- `resources/dbt_build.job.yml` — a Job with two tasks (`dbt build`, then
  `dbt source freshness`) running on **serverless** compute.

### How auth works in the job (no tokens!)

The `dbt_task` sets `warehouse_id`, `catalog`, and `schema`. When `warehouse_id` is
present, **Databricks auto-generates the dbt profile** and connects using the job's
**run-as identity** — so the job needs no PAT and ignores `profiles.yml`. Deploy
`prod` using a service-principal-authenticated CLI profile so that service principal
becomes the job's run-as identity.

### Deployment-specific values

| Value | How to provide it |
|---|---|
| Workspace host and credentials | Selected Databricks CLI profile |
| `warehouse_id` | `BUNDLE_VAR_warehouse_id` or `--var warehouse_id=<id>` |
| Production run-as identity | Deploy with a service-principal-authenticated profile |
| `permissions.group_name` (prod) | Set the group allowed to manage the job |

### Bundle commands

Set the target warehouse before validating, deploying, or running:

```bash
export BUNDLE_VAR_warehouse_id=<warehouse-id>
```

| Command | What it does |
|---|---|
| `databricks bundle validate -t dev --profile <P>` | Check the bundle config + schema. |
| `databricks bundle deploy -t dev --profile <P>` | Upload the project + create the name-prefixed development Job. |
| `databricks bundle run dbt_build_job -t dev --profile <P>` | Trigger the Job now and stream logs. |
| `databricks bundle deploy -t prod --profile <SP_PROFILE>` | Deploy to prod as the service principal. |
| `databricks bundle destroy -t dev --profile <P>` | Tear down the deployed resources. |

> `dev` uses `mode: development` (resources prefixed `[dev you]`).
> `prod` uses `mode: production`. The Job has no schedule and runs only when triggered.

---

## 6. Suggested learning path

1. `dbt debug` → `dbt deps` → `dbt seed` — get connected and load reference data.
2. `dbt run -s staging` — inspect the **views** in Unity Catalog (`*_staging` schema).
3. `dbt run -s marts.core` — see **ephemeral** models get inlined into **tables**.
4. `dbt test` — watch generic + singular tests run; break a value and see one fail.
5. `dbt snapshot` — change a product price in `raw_products`, re-run, inspect SCD2 rows.
6. `dbt run -s fct_inventory_events` twice with new data — understand **incremental merge**.
7. `dbt build` — run the whole DAG the way CI would.
8. `dbt docs generate && dbt docs serve` — explore lineage, exposures, and descriptions.

---

## 7. Project layout

```
dbt_retail_lakehouse/
├── dbt_project.yml            # project config, materializations by folder
├── packages.yml               # dbt_utils, dbt_expectations
├── profiles.yml               # connection template (env-var driven, placeholders)
├── pyproject.toml             # Python deps managed by uv
├── uv.lock                    # pinned, reproducible dependency lock
├── .env.example               # copy to .env, fill in Databricks values
├── databricks.yml             # Databricks Asset Bundle (targets, variables)
├── resources/
│   └── dbt_build.job.yml      # Lakeflow Job: dbt build on serverless
├── data/                      # generated raw CSVs (load into UC raw schema)
├── scripts/
│   ├── generate_data.py       # synthetic data generator (stdlib only)
│   └── upload_data_to_volume.sh
├── setup/
│   ├── 01_setup_databricks.sql   # catalog, raw tables, volume
│   ├── 02_permissions.sql        # UC grants (placeholders)
│   └── 03_load_raw_copy_into.sql # COPY INTO the raw tables
├── seeds/                     # reference CSVs + tests
├── models/
│   ├── staging/               # sources + stg_* views
│   ├── intermediate/          # int_* ephemeral
│   └── marts/
│       ├── core/              # dim_* / fct_* tables + doc blocks
│       ├── finance/           # payments + revenue-vs-target
│       ├── inventory/         # incremental events + current stock
│       └── _exposures.yml     # dashboards / ML consumers
├── snapshots/                 # SCD2 history (check + timestamp strategies)
├── macros/                    # dollars_to_cents, generate_schema_name, grant op
├── tests/                     # singular tests
└── analyses/                  # compiled-only queries
```

---

## 8. Notes & gotchas on Databricks

- **Three-level namespace**: dbt writes to `catalog.schema.table`; the catalog comes
  from `profiles.yml` (`catalog:`), schema from the model's `+schema` + the custom
  `generate_schema_name` macro.
- **Delta everywhere**: `+file_format: delta` is the default; marts add
  `liquid_clustered_by` and `tblproperties` for performance.
- **SQL Warehouse vs cluster**: `http_path` points at a SQL Warehouse (recommended for
  dbt). All-purpose clusters also work but use a different `http_path` shape.
- **Auth**: dev uses a PAT (fast to start); prod uses **OAuth M2M with a service
  principal** (no long-lived tokens) — the recommended pattern for CI/scheduled runs.
- **`persist_docs`** pushes your dbt descriptions into Unity Catalog table/column
  comments, so they show up in the Databricks Catalog Explorer.
- **Loading raw data (CSV → typed Delta)**: `COPY INTO` reads CSV columns as
  `STRING` (a CSV carries no schema). Loading those straight into the typed raw
  tables fails with `DELTA_FAILED_TO_MERGE_FIELDS` (e.g. `STRING` vs `BIGINT` on
  `customer_id`). `setup/03_load_raw_copy_into.sql` therefore wraps each source in
  `FROM (SELECT CAST(col AS <type>) ... FROM '<path>')` so every column is cast to
  the table's type before the write. (Alternatives: `FORMAT_OPTIONS('inferSchema'='true')`,
  which is less precise — it can pick `INT`/`DOUBLE` and leave timestamps as strings —
  or dropping the `CREATE TABLE` DDL and letting `COPY INTO` create tables from the
  inferred CSV schema.)
- **Bundle job auth** uses the run-as identity + `warehouse_id` (auto-generated dbt
  profile); the `profiles.yml` in this repo is only for **local** dbt runs.
