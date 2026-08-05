-- file:admin_20260806_01.sql
-- date:20260806

-- Create admin schema if it does not exist
CREATE SCHEMA IF NOT EXISTS admin;

-- Organisation details table
-- Stores organisation profile information and audit timestamps
CREATE TABLE IF NOT EXISTS admin.org_details (
  id         UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  spid       TEXT        NOT NULL UNIQUE,
  email      TEXT        NOT NULL UNIQUE,
  mobile     TEXT,
  mobile_code TEXT,
  first_name TEXT,
  last_name  TEXT,
  org_name   TEXT,
  avatar_url TEXT,
  banner_url TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
