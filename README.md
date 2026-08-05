# Supabase DB Schema Automation

Automated database schema deployment to Supabase via GitHub Actions.

## How it works

Every time a pull request touching `supabase/phase_1/` is merged to `master`, the pipeline:
1. **Validates headers** — checks `-- file:` and `-- date:` format on every `.sql` file (blocks merge on failure)
2. **Validates SQL syntax** — dry-runs each file inside a rolled-back transaction against the real DB (blocks merge on failure)
3. **Checksums** all files and uploads an artifact for 90-day audit retention
4. **Deploys** via `psql` to your Supabase database using the connection pooler
5. **Updates** `phase_1_registry.yml` with sequence, checksum, actor, and run ID, then commits it back

## Project structure

```
supabase-db-schema-automation/
├── .github/
│   └── workflows/
│       ├── deploy.yml                  # Deploys on push to master
│       └── validate_sql_headers.yml    # PR checks: header format + SQL syntax
├── scripts/
│   ├── update_registry.sh             # Auto-updates phase_1_registry.yml
│   ├── validate_sql_headers.sh        # Checks -- file: and -- date: headers
│   └── validate_sql_syntax.sh         # Dry-run SQL syntax check via rollback
├── supabase/
│   ├── config.toml                    # Supabase CLI config
│   ├── phase_1_registry.yml           # Deployment sequence log (auto-managed)
│   └── phase_1/
│       └── admin_20260806_01.sql      # Phase 1 SQL files
└── README.md
```

## Phase 1 schema

### `admin` schema

| Table | Column | Type | Notes |
|---|---|---|---|
| `admin.org_info` | `id` | `UUID` | Primary key, auto-generated |
| | `org_id` | `BIGINT` | Unique organisation identifier |
| | `spid` | `TEXT` | Unique service provider ID |
| | `created_at` | `TIMESTAMPTZ` | Auto-set on insert |
| | `updated_at` | `TIMESTAMPTZ` | Auto-set on insert |

## SQL file header format (required)

Every `.sql` file in `supabase/phase_1/` **must** start with these exact two lines:

```sql
-- file:<filename>.sql
-- date:<YYYYMMDD>
```

Example:

```sql
-- file:admin_20260806_01.sql
-- date:20260806

CREATE SCHEMA IF NOT EXISTS admin;

CREATE TABLE IF NOT EXISTS admin.org_info (
  id         UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id     BIGINT      NOT NULL UNIQUE,
  spid       TEXT        NOT NULL UNIQUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

The PR check will **block the merge** if any file is missing or has an incorrect header.

## Setup

### 1. Add the GitHub secret

Go to your repo → **Settings → Secrets and variables → Actions → New repository secret**:

| Secret | Value |
|---|---|
| `SUPABASE_DB_URL` | Connection pooler URI from Supabase (see below) |

**Getting the correct URL:**
1. Supabase → your project → **Settings → Database**
2. Scroll to **Connection pooler** → select **Session mode**
3. Copy the **URI** — it looks like:
   ```
   postgresql://postgres.xxxxxxxxxxxxxxxxxxxx:[PASSWORD]@aws-0-region.pooler.supabase.com:6543/postgres
   ```
   Use port **6543** (pooler), not port 5432 (direct). GitHub Actions runners block IPv6 which the direct connection uses.

### 2. Protect the master branch

Go to **Settings → Branches → Add branch protection rule** for `master`:
- ✅ Require status checks to pass before merging
- ✅ Select `Validate SQL Headers` as a required check
- ✅ Select `Validate SQL Syntax` as a required check
- ✅ Require a pull request before merging

> These check names only appear after the first PR run has completed at least once.

## Adding a new SQL file

1. Create the file with the required header:

```sql
-- file:admin_20260807_01.sql
-- date:20260807

ALTER TABLE admin.org_info ADD COLUMN phone TEXT;
```

2. Open a PR:

```bash
git checkout -b feat/add-phone-column
git add supabase/phase_1/admin_20260807_01.sql
git commit -m "feat: add phone column to org_info"
git push origin feat/add-phone-column
# Open PR → both checks run → merge → deploy runs automatically
```

## Local validation

Run the header check locally before pushing:

```bash
bash scripts/validate_sql_headers.sh
```

## Audit trail

Query your database anytime to see applied files:

```sql
SELECT * FROM supabase_migrations.schema_migrations ORDER BY inserted_at;
```

The `supabase/phase_1_registry.yml` in this repo also tracks every deployment with sequence number, checksum, actor, and GitHub run ID.
