# Migrating this project to dbt Cloud

This project runs as **dbt Core** locally (managed by `uv`) against Databricks, and
is orchestrated by a **Databricks Asset Bundle (DAB)**. Moving to dbt Cloud means
swapping the *local machinery* for dbt Cloud's *managed equivalents* — your models,
seeds, snapshots, macros, tests, and `packages.yml` transfer **unchanged**.

| Local (dbt Core)                     | dbt Cloud equivalent                          |
| ------------------------------------ | --------------------------------------------- |
| `profiles.yml` + `.env`              | UI-configured **connection** + **credentials**|
| `pyproject.toml` / `uv.lock` / uv    | dbt Cloud-managed runtime (adapter built in)  |
| PyPI proxy index                     | n/a (Cloud installs the adapter itself)       |
| DAB (`databricks.yml`, `resources/`) | **dbt Cloud Jobs** (scheduler)                |
| Running `dbt` from your shell        | dbt Cloud **IDE** / Jobs                       |

> The **raw-data loading stays on Databricks and is unchanged** — `setup/01–03`
> (catalog, raw tables, `COPY INTO`) and `scripts/*` still run against Databricks.
> dbt Cloud only orchestrates the transformations; it does not land your raw CSVs.

---

## Prerequisites

- A dbt Cloud account entitled to a **Databricks** connection.
- The project pushed to a **Git repo** (GitHub / GitLab / Azure DevOps / Bitbucket).
  dbt Cloud pulls from Git — it never reads your local disk.

---

## 1. Put the project in Git

The dbt project (the folder containing `dbt_project.yml`) is **nested** at
`dbt_retail_lakehouse/`. Pick your repo root and push:

```bash
cd .../dbt_primark          # or dbt_retail_lakehouse — your choice of repo root
git init && git add -A && git commit -m "Initial dbt retail lakehouse project"
git remote add origin <your-remote> && git push -u origin main
```

`.gitignore` already excludes `.venv/`, `target/`, `dbt_packages/`, and `.env`.

## 2. Create the dbt Cloud project

- **Account settings → Projects → New Project**, connect the Git repo.
- Set **Project subdirectory = `dbt_retail_lakehouse`** (because `dbt_project.yml`
  is not at the repo root). This is the most commonly missed step.

## 3. Configure the Databricks connection (replaces `profiles.yml`)

dbt Cloud **does not use `profiles.yml`** — it builds the connection from the UI:

- **Adapter:** Databricks
- **Server hostname:** your workspace host (e.g. `adb-1234567890123456.7.azuredatabricks.net`)
- **HTTP path:** your SQL Warehouse HTTP path
- **Catalog:** `retail_lakehouse_dbt` (Unity Catalog)

These files become **local-dev-only** (Cloud ignores them; leave them in the repo):
`profiles.yml`, `pyproject.toml`, `uv.lock`, `.env` / `.env.example`, and the
`[[tool.uv.index]]` PyPI-proxy config.

## 4. Set up environments + credentials

dbt Cloud separates **development** (the IDE, your personal creds) from
**deployment** (jobs, a service identity):

- **Development credentials** → your PAT or user OAuth + a personal schema
  (e.g. `dbt_cyril`). Equivalent to the local `dev` target.
- **Deployment environment (Prod)** → a **service principal** token / OAuth M2M +
  schema `analytics`. Equivalent to the local `prod` target and the DAB `run_as`.

> The dbt-databricks 1.10 "more than one authorization method configured"
> conflict is **local-only** (it came from `.env` + `~/.databrickscfg`). dbt Cloud
> holds one credential per environment, so it does not occur there.

## 5. Pick the dbt version

In each environment choose a **release track / version ≥ 1.10** (or "Latest").
You do **not** manage `dbt-core` / `dbt-databricks` pins in Cloud — `pyproject.toml`'s
`>=1.10,<2.0` now governs only local runs.

## 6. Handle the `env_var()` references

`models/staging/_sources.yml` uses `env_var('DATABRICKS_CATALOG', 'retail_lakehouse_dbt')`:

- It has a **default**, so it resolves to `retail_lakehouse_dbt` in Cloud with no
  config — fine as long as the connection catalog matches.
- To override it from the UI, note dbt Cloud environment variables must be
  **prefixed `DBT_`**, so `DATABRICKS_CATALOG` can't be set as-is. Cleanest
  long-term fix: point the source `database:` at the connection catalog via
  `target.database` instead of an env var (optional).

## 7. Verify in the Cloud IDE

Open the IDE and run the same commands you run locally:

```
dbt deps        # installs dbt_utils + dbt_expectations from the hub
dbt debug       # tests the Databricks connection
dbt build       # seeds → models → snapshots → tests, exactly as local
```

Everything behaves identically — views, tables, the `fct_inventory_events`
incremental merge, and both snapshots — same adapter, same SQL.

## 8. Recreate orchestration as a dbt Cloud Job (replaces the DAB)

The DAB (`databricks.yml` + `resources/dbt_build.job.yml`) is a Databricks Lakeflow
Job. In Cloud, create a **dbt Cloud Job** in the Prod environment instead:

- Commands: `dbt deps`, `dbt build`, `dbt source freshness`
- Schedule: daily 06:00 Europe/Dublin (matches the DAB cron `0 0 6 * * ?`)
- Failure notifications → email / Slack

Then decide: **keep the DAB** (Databricks-native orchestration) **or** use **dbt Cloud
Jobs** — they are alternatives, not both. Going all-in on Cloud, the DAB files
become unused; keep them only to retain the option of running via Databricks directly.

## 9. (Optional) CI

Add a **CI job** triggered on pull requests using Slim CI:

```
dbt build --select state:modified+ --defer --state <prod-artifacts>
```

so PRs build/test only what changed relative to production.

---

## Keep / drop reference

| Transfers unchanged | Local-only (Cloud ignores) | Becomes optional |
| --- | --- | --- |
| `models/`, `seeds/`, `snapshots/`, `macros/`, `tests/`, `analyses/`, `packages.yml`, `dbt_project.yml`, `setup/`, `scripts/` | `profiles.yml`, `pyproject.toml`, `uv.lock`, `.env` / `.env.example`, uv proxy index | `databricks.yml` + `resources/` (DAB) → replaced by dbt Cloud Jobs |

## References

- dbt Cloud + Databricks setup: <https://docs.getdbt.com/docs/cloud/connect-data-platform/connect-databricks>
- dbt Cloud environments & jobs: <https://docs.getdbt.com/docs/deploy/deploy-environments>
- Slim CI: <https://docs.getdbt.com/docs/deploy/ci-jobs>
