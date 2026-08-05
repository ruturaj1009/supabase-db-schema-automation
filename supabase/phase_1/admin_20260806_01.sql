-- file:admin_20260806_01.sql
-- date:20260806
-- last-modified:20260806

-- Create admin schema if it does not exist
CREATE SCHEMA IF NOT EXISTS admin;

-- Organisation info table
-- Stores core organisation identifiers and audit timestamps
CREATE TABLE IF NOT EXISTS admin.org_info (
  id         UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id     BIGINT      NOT NULL UNIQUE,
  spid       TEXT        NOT NULL UNIQUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
