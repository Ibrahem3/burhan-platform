-- BURHAN DeAI backend test bootstrap — PART 1 (before schema.sql)
-- Real PostgreSQL has no Supabase `auth` / `storage` schemas or base roles.
-- This mimics the minimal host surface that schema.sql depends on.
-- The JWT context is isolated here (NOT part of schema.sql): auth.uid()
-- reads a request.jwt.claim.sub GUC that tests set explicitly.

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN CREATE ROLE anon NOLOGIN; END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN CREATE ROLE authenticated NOLOGIN; END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'service_role') THEN CREATE ROLE service_role NOLOGIN; END IF;
END $$;

CREATE SCHEMA auth;
CREATE TABLE auth.users (
  id                UUID PRIMARY KEY,
  raw_user_meta_data JSONB NOT NULL DEFAULT '{}'::jsonb
);
CREATE OR REPLACE FUNCTION auth.uid()
RETURNS UUID
LANGUAGE SQL
STABLE
AS $$
  SELECT NULLIF(current_setting('request.jwt.claim.sub', TRUE), '')::UUID
$$;
GRANT USAGE ON SCHEMA auth TO anon, authenticated, service_role;

CREATE SCHEMA storage;
CREATE TABLE storage.buckets (
  id                TEXT PRIMARY KEY,
  name              TEXT,
  public            BOOLEAN DEFAULT FALSE,
  file_size_limit   BIGINT,
  allowed_mime_types TEXT[]
);
CREATE TABLE storage.objects (
  id        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  bucket_id TEXT
);
GRANT USAGE ON SCHEMA storage TO anon, authenticated, service_role;

-- Supabase creates this internally (used by its ensure_rls event trigger and
-- referenced by migration 00008). Stubbed here so schema.sql applies verbatim
-- against plain PostgreSQL. Not part of schema.sql itself.
CREATE OR REPLACE FUNCTION public.rls_auto_enable()
RETURNS event_trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  NULL;
END;
$$;