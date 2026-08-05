# Supabase DB Schema Automation

Automated database schema deployment to Supabase via GitHub Actions.

## How it works

Every time a pull request touching `supabase/phase_1/` is merged to `master`, the pipeline:
1. **Validates headers** — checks `-- file:` and `-- date:` format on every `.sql` file (PR check — blocks merge on failure)
2. **Validates SQL syntax** — runs each file inside a rolled-back transaction against the real DB, catching syntax and semantic errors before they hit production (PR check — blocks merge on failure)
3. **Checksums** all files and uploads an artifact for audit
4. **Deploys** via `psql` to your Supabase database
5. **Updates** the `phase_1_registry.yml` with the deployment sequence and commits it back

## Project structure

```
supabase-db-schema-automation/
├── .github/
│   └── workflows/
│       ├── deploy.yml                  # CI/CD — deploys on push to master
│       └── validate_sql_headers.yml    # PR checks — header format + SQL syntax
├── scripts/
│   ├── update_registry.sh             # Auto-updates phase_1_registry.yml
│   ├── validate_sql_headers.sh        # Checks -- file: and -- date: headers
│   └── validate_sql_syntax.sh         # Dry-run SQL syntax check via rollback
├── supabase/
│   ├── config.toml                    # Supabase CLI config
│   ├── phase_1_registry.yml           # Deployment sequence log (auto-managed)
│   └── phase_1/
│       └── YYYYMMDDHHMMSS_name.sql    # SQL files
└── README.md
```

## SQL file header format (required)

Every `.sql` file in `supabase/phase_1/` **must** start with these exact two lines:

```sql
-- file:<filename>.sql
-- date:<YYYYMMDD>
```

Example for a file named `admin_20260806_01.sql`:

```sql
-- file:admin_20260806_01.sql
-- date:20260806

CREATE TABLE IF NOT EXISTS ...
```

The PR validation check will **block the merge** if any file is missing or has an incorrect header.

## Setup

### 1. Add GitHub Secrets

Go to your repo → **Settings → Secrets and variables → Actions** and add:

| Secret | Where to find it |
|---|---|
| `SUPABASE_ACCESS_TOKEN` | [supabase.com/dashboard/account/tokens](https://supabase.com/dashboard/account/tokens) |
| `SUPABASE_PROJECT_REF` | Project → Settings → General → Reference ID |
| `SUPABASE_DB_PASSWORD` | Project → Settings → Database → Database password |

### 2. (Recommended) Protect the master branch

Go to **Settings → Branches → Add branch protection rule** for `master` and enable:
- ✅ Require status checks to pass before merging
- ✅ Select `Validate SQL Headers` as a required check
- ✅ Select `Validate SQL Syntax` as a required check
- ✅ Require a pull request before merging (recommended)

Both checks must pass before any PR can be merged.

### 3. Add a new SQL file

Create a file in `supabase/phase_1/` with the required header:

```sql
-- file:admin_20260807_01.sql
-- date:20260807

ALTER TABLE users ADD COLUMN phone TEXT;
```

### 4. Open a PR and merge

```bash
git checkout -b add-phone-column
git add supabase/phase_1/admin_20260807_01.sql
git commit -m "feat: add phone column to users"
git push origin add-phone-column
# Open PR → header check runs automatically → merge → deploy runs
```

## Local validation

Run the header check locally before pushing:

```bash
bash scripts/validate_sql_headers.sh
```

## Local development

```bash
# Install Supabase CLI
npm install -g supabase

# Start local Supabase stack
supabase start

# Apply phase_1 files locally
supabase db push --migrations-dir supabase/phase_1
```

## Audit trail

After each deployment, query your database to see what was applied:

```sql
SELECT * FROM supabase_migrations.schema_migrations ORDER BY inserted_at;
```

The `supabase/phase_1_registry.yml` file in this repo also tracks every deployment with sequence number, checksum, actor, and run ID.
