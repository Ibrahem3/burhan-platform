-- ============================================================
-- BURHAN PLATFORM — Initial Schema Migration
-- Multi-tenant SaaS: Central Hub with Slug-Based Tenant Routing
-- ============================================================

-- 0. EXTENSIONS
-- ============================================================
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- 1. CUSTOM ENUMS
-- ============================================================
CREATE TYPE module_type AS ENUM ('content', 'forum', 'media');
CREATE TYPE user_role AS ENUM ('super_admin', 'owner', 'manager', 'member');

-- 2. TABLES
-- ============================================================

-- 2a. organizations — the tenant/brand owner
CREATE TABLE organizations (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name        TEXT NOT NULL,
  org_slug    TEXT UNIQUE NOT NULL,
  settings    JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON COLUMN organizations.settings IS
  'JSON structure: { "colors": { "primary": "#...", "secondary": "#..." }, "logos": { "light": "url", "dark": "url" }, "branding": { ... } }';
CREATE INDEX idx_organizations_org_slug ON organizations (org_slug);

-- 2b. branches — modular sub-sections under an organization
CREATE TABLE branches (
  id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  organization_id   UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  name              JSONB NOT NULL DEFAULT '{"ar": "", "en": ""}'::jsonb,
  module_type       module_type NOT NULL DEFAULT 'content',
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_branches_organization_id ON branches (organization_id);

-- 2c. profiles — extends auth.users with role & org membership
CREATE TABLE profiles (
  id                UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  organization_id   UUID REFERENCES organizations(id) ON DELETE SET NULL,
  full_name         JSONB NOT NULL DEFAULT '{"ar": "", "en": ""}'::jsonb,
  role              user_role NOT NULL DEFAULT 'member',
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_profiles_organization_id ON profiles (organization_id);

-- 2d. entities — the dynamic content engine
CREATE TABLE entities (
  id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  branch_id         UUID NOT NULL REFERENCES branches(id) ON DELETE CASCADE,
  organization_id   UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  title             JSONB NOT NULL DEFAULT '{"ar": "", "en": ""}'::jsonb,
  content           JSONB NOT NULL DEFAULT '{"ar": "", "en": ""}'::jsonb,
  is_public_to_hub  BOOLEAN NOT NULL DEFAULT false,
  -- Video multi-source fields
  video_id          TEXT,
  primary_source    TEXT NOT NULL DEFAULT 'youtube',
  fallback_source   TEXT,
  fallback_url      TEXT,
  -- Academy / Premium monetization
  is_premium        BOOLEAN NOT NULL DEFAULT false,
  price             DECIMAL(10,2),
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_entities_branch_id ON entities (branch_id);
CREATE INDEX idx_entities_organization_id ON entities (organization_id);
CREATE INDEX idx_entities_public_to_hub ON entities (is_public_to_hub) WHERE is_public_to_hub = true;
CREATE INDEX idx_entities_premium ON entities (is_premium);

-- 3. TRIGGER — auto-create profile on user signup
-- ============================================================
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = ''
AS $$
BEGIN
  INSERT INTO public.profiles (id, full_name, role)
  VALUES (
    NEW.id,
    jsonb_build_object('ar', COALESCE(NEW.raw_user_meta_data ->> 'full_name_ar', ''), 'en', COALESCE(NEW.raw_user_meta_data ->> 'full_name_en', '')),
    'member'
  );
  RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION handle_new_user();

-- 4. ROW LEVEL SECURITY
-- ============================================================

-- 4a. organizations
ALTER TABLE organizations ENABLE ROW LEVEL SECURITY;

CREATE POLICY "organizations_select_all"
  ON organizations FOR SELECT
  USING (true);

CREATE POLICY "organizations_insert_super_admin"
  ON organizations FOR INSERT
  WITH CHECK (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'super_admin')
  );

CREATE POLICY "organizations_update_owner_or_super_admin"
  ON organizations FOR UPDATE
  USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND (role = 'super_admin' OR (role = 'owner' AND organization_id = id)))
  );

CREATE POLICY "organizations_delete_super_admin"
  ON organizations FOR DELETE
  USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'super_admin')
  );

-- 4b. branches
ALTER TABLE branches ENABLE ROW LEVEL SECURITY;

CREATE POLICY "branches_select_org_member"
  ON branches FOR SELECT
  USING (
    organization_id IN (
      SELECT organization_id FROM profiles WHERE id = auth.uid()
    )
    OR
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'super_admin')
  );

CREATE POLICY "branches_insert_org_owner_or_manager"
  ON branches FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid()
        AND organization_id = branches.organization_id
        AND role IN ('owner', 'manager')
    )
    OR
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'super_admin')
  );

CREATE POLICY "branches_update_org_owner_or_manager"
  ON branches FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid()
        AND organization_id = branches.organization_id
        AND role IN ('owner', 'manager')
    )
    OR
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'super_admin')
  );

CREATE POLICY "branches_delete_org_owner"
  ON branches FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid()
        AND organization_id = branches.organization_id
        AND role = 'owner'
    )
    OR
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'super_admin')
  );

-- 4c. profiles
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "profiles_select_own"
  ON profiles FOR SELECT
  USING (id = auth.uid());

CREATE POLICY "profiles_select_org_members"
  ON profiles FOR SELECT
  USING (
    organization_id IN (
      SELECT organization_id FROM profiles WHERE id = auth.uid()
    )
    OR
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'super_admin')
  );

CREATE POLICY "profiles_update_own"
  ON profiles FOR UPDATE
  USING (id = auth.uid());

CREATE POLICY "profiles_update_org_owner"
  ON profiles FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid()
        AND organization_id = profiles.organization_id
        AND role = 'owner'
    )
    OR
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'super_admin')
  );

-- 4d. entities — the most critical RLS layer
ALTER TABLE entities ENABLE ROW LEVEL SECURITY;

-- Hub: anyone (even unauthenticated) can read public non-premium entities only
CREATE POLICY "entities_select_public_hub"
  ON entities FOR SELECT
  USING (is_public_to_hub = true AND is_premium = false);

-- Tenant isolation: authenticated members see their org's entities
-- Basic members (role = 'member') are excluded from premium content
-- Owners, managers, and super_admins see everything in their org
CREATE POLICY "entities_select_org_member"
  ON entities FOR SELECT
  USING (
    (
      organization_id IN (
        SELECT organization_id FROM profiles WHERE id = auth.uid()
      )
      AND (
        is_premium = false
        OR
        EXISTS (
          SELECT 1 FROM profiles
          WHERE id = auth.uid()
            AND organization_id = entities.organization_id
            AND role IN ('owner', 'manager')
        )
      )
    )
    OR
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'super_admin')
  );

-- Insert: org owners, managers, and super_admins can insert
CREATE POLICY "entities_insert_org_staff"
  ON entities FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid()
        AND organization_id = entities.organization_id
        AND role IN ('owner', 'manager')
    )
    OR
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'super_admin')
  );

-- Update: org content managers (owner + manager) and super_admins can update any entity in their org
CREATE POLICY "entities_update_org_staff"
  ON entities FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid()
        AND organization_id = entities.organization_id
        AND role IN ('owner', 'manager')
    )
    OR
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'super_admin')
  );

-- Delete: org owners and super_admins
CREATE POLICY "entities_delete_org_owner"
  ON entities FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid()
        AND organization_id = entities.organization_id
        AND role IN ('owner', 'manager')
    )
    OR
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'super_admin')
  );
-- ============================================================
-- BURHAN PLATFORM — Patch: Branches RLS for Public Access
-- 
-- The original branches_select_org_member policy requires
-- auth.uid(), which blocks anonymous users from reading branch
-- metadata. This breaks the hub entity feed (which joins to
-- branches) and the org slug API endpoint.
--
-- Fix: Add a public select policy for non-sensitive branch
-- metadata. The existing org_member policy remains for
-- authenticated writes.
-- ============================================================

-- Allow anonymous/public reads of branch metadata
CREATE POLICY "branches_select_public"
  ON branches FOR SELECT
  USING (true);
-- ============================================================
-- BURHAN PLATFORM — Patch: Fix Profiles RLS Infinite Recursion
-- 
-- Root Cause: profiles_select_org_members and
-- profiles_update_org_owner policies query the profiles table
-- within a policy ON the profiles table. This creates infinite
-- recursion because each policy check triggers another SELECT
-- on profiles, which checks policies again.
--
-- Fix: SECURITY DEFINER functions that bypass RLS to safely
-- resolve the current user's role and organization_id.
-- ============================================================

-- 1. Helper functions (SECURITY DEFINER = bypasses RLS)
-- ============================================================

CREATE OR REPLACE FUNCTION public.get_current_user_role()
RETURNS user_role
LANGUAGE SQL
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT COALESCE(
    (SELECT role FROM profiles WHERE id = auth.uid() LIMIT 1),
    'member'::user_role
  );
$$;

CREATE OR REPLACE FUNCTION public.get_current_user_org_id()
RETURNS UUID
LANGUAGE SQL
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT organization_id FROM profiles WHERE id = auth.uid() LIMIT 1;
$$;

-- 2. Drop broken self-referencing policies
-- ============================================================

DROP POLICY IF EXISTS "profiles_select_org_members" ON profiles;
DROP POLICY IF EXISTS "profiles_update_org_owner" ON profiles;

-- 3. Replace with non-recursive policies using helper functions
-- ============================================================

-- Org members can see other members in the same org
CREATE POLICY "profiles_select_org_members"
  ON profiles FOR SELECT
  USING (
    organization_id = public.get_current_user_org_id()
    OR
    public.get_current_user_role() = 'super_admin'
  );

-- Org owners and super_admins can update profiles in their org
CREATE POLICY "profiles_update_org_staff"
  ON profiles FOR UPDATE
  USING (
    (
      public.get_current_user_role() = 'owner'
      AND
      organization_id = public.get_current_user_org_id()
    )
    OR
    public.get_current_user_role() = 'super_admin'
  );

-- 3b. Recreate the update_own policy (wasn't recursive, but ensure it exists)
DROP POLICY IF EXISTS "profiles_update_own" ON profiles;

CREATE POLICY "profiles_update_own"
  ON profiles FOR UPDATE
  USING (id = auth.uid());
-- ============================================================
-- BURHAN PLATFORM — Migration 00004
-- Add slug + is_active to branches table
-- ============================================================

-- 1. Add columns (nullable slug first, is_active with default)
ALTER TABLE branches
  ADD COLUMN IF NOT EXISTS is_active BOOLEAN NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS slug     TEXT;

-- 2. Hydrate existing rows with a fallback slug
--    Uses COALESCE to prefer a slug from name->>'en' if present,
--    falls back to 'main' for rows that are truly empty.
UPDATE branches
  SET slug = COALESCE(
    NULLIF(
      regexp_replace(
        lower(trim(branches.name->>'en')),
        '[^a-z0-9]+', '-', 'g'
      ),
      ''
    ),
    'main'
  )
  WHERE slug IS NULL;

-- 3. Enforce NOT NULL now that data is populated
ALTER TABLE branches
  ALTER COLUMN slug SET NOT NULL;

-- 4. Unique constraint per organization
--    Different orgs may reuse the same slug; the same org may not.
CREATE UNIQUE INDEX IF NOT EXISTS idx_branches_org_slug
  ON branches (organization_id, slug);

-- 5. (Optional but recommended) index for is_active lookups
CREATE INDEX IF NOT EXISTS idx_branches_active
  ON branches (is_active)
  WHERE is_active = true;

-- 6. Comment for clarity
COMMENT ON COLUMN branches.slug       IS 'URL-safe identifier, unique per organization';
COMMENT ON COLUMN branches.is_active  IS 'Soft-delete / visibility toggle for the branch';
-- ============================================================
-- BURHAN PLATFORM — Migration 00005
-- Create organization_assets storage bucket + RLS policies
-- ============================================================

-- 1. Create the bucket (id = name = 'organization_assets')
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'organization_assets',
  'organization_assets',
  true,
  5242880, -- 5 MB
  ARRAY['image/jpeg', 'image/png', 'image/gif', 'image/webp']
)
ON CONFLICT (id) DO NOTHING;

-- 2. Drop any conflicting default policies that Supabase auto-creates
DROP POLICY IF EXISTS "Give users access to own folder 1pkutm_0" ON storage.objects;
DROP POLICY IF EXISTS "Give users access to own folder 1pkutm_1" ON storage.objects;
DROP POLICY IF EXISTS "Give users access to own folder 1pkutm_2" ON storage.objects;
DROP POLICY IF EXISTS "Give users access to own folder 1pkutm_3" ON storage.objects;

-- 3. Allow authenticated users to upload into the bucket
CREATE POLICY "org_assets_insert"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (bucket_id = 'organization_assets');

-- 4. Allow public read (bucket is public)
CREATE POLICY "org_assets_select"
ON storage.objects FOR SELECT TO public
USING (bucket_id = 'organization_assets');

-- 5. Allow authenticated users to update files
CREATE POLICY "org_assets_update"
ON storage.objects FOR UPDATE TO authenticated
USING (bucket_id = 'organization_assets')
WITH CHECK (bucket_id = 'organization_assets');

-- 6. Allow authenticated users to delete files
CREATE POLICY "org_assets_delete"
ON storage.objects FOR DELETE TO authenticated
USING (bucket_id = 'organization_assets');
-- ============================================================
-- BURHAN PLATFORM — Migration 00006
-- Series & Playlists: Course infrastructure for educational tracks
-- ============================================================

-- 1. Create the series table
-- ============================================================
CREATE TABLE series (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  branch_id       UUID NOT NULL REFERENCES branches(id) ON DELETE CASCADE,
  title           JSONB NOT NULL DEFAULT '{"ar": "", "en": ""}'::jsonb,
  description     JSONB DEFAULT '{"ar": "", "en": ""}'::jsonb,
  cover_url       TEXT,
  is_active       BOOLEAN NOT NULL DEFAULT true,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 2. Add series_id and sort_order to entities
-- ============================================================
ALTER TABLE entities
  ADD COLUMN series_id  UUID REFERENCES series(id) ON DELETE SET NULL,
  ADD COLUMN sort_order INT NOT NULL DEFAULT 0;

-- 3. Performance Indexes
-- ============================================================

-- FK indexes (blazing-fast JOINs)
CREATE INDEX idx_series_organization_id ON series (organization_id);
CREATE INDEX idx_series_branch_id       ON series (branch_id);
CREATE INDEX idx_entities_series_id     ON entities (series_id);

-- Composite index for fetching ordered entities within a series
CREATE INDEX idx_entities_series_order
  ON entities (series_id, sort_order, created_at)
  WHERE series_id IS NOT NULL;

-- 4. RLS Policies — series
-- ============================================================

-- SELECT: org members + super_admin
CREATE POLICY series_select_org
  ON series FOR SELECT TO authenticated
  USING (
    organization_id IN (
      SELECT organization_id FROM profiles
      WHERE id = auth.uid()
    )
    OR EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'super_admin')
  );

-- All users can see active series on public hub (joined through org via tenant pages)
CREATE POLICY series_select_public
  ON series FOR SELECT TO anon
  USING (is_active = true);

-- INSERT: owner, manager, super_admin
CREATE POLICY series_insert_org
  ON series FOR INSERT TO authenticated
  WITH CHECK (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND organization_id = series.organization_id AND role IN ('owner', 'manager'))
    OR EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'super_admin')
  );

-- UPDATE: owner, manager, super_admin
CREATE POLICY series_update_org
  ON series FOR UPDATE TO authenticated
  USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND organization_id = series.organization_id AND role IN ('owner', 'manager'))
    OR EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'super_admin')
  )
  WITH CHECK (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND organization_id = series.organization_id AND role IN ('owner', 'manager'))
    OR EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'super_admin')
  );

-- DELETE: owner, super_admin
CREATE POLICY series_delete_org
  ON series FOR DELETE TO authenticated
  USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND organization_id = series.organization_id AND role = 'owner')
    OR EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'super_admin')
  );

-- 5. RLS Policies — entities (extend existing for series scoping)
-- ============================================================

-- Entities remain protected by their existing org-scoped RLS.
-- No new entity policies needed — series_id is just an additional FK.
-- Existing policies on entities already scope by organization_id.

-- 6. Comments
-- ============================================================
COMMENT ON TABLE  series                        IS 'Educational series / playlists — grouped lessons under a branch';
COMMENT ON COLUMN series.id                     IS 'PK, auto-generated UUID';
COMMENT ON COLUMN series.organization_id        IS 'Tenant owner';
COMMENT ON COLUMN series.branch_id              IS 'Parent branch (e.g. Academy)';
COMMENT ON COLUMN series.title                  IS 'Bilingual title {ar, en}';
COMMENT ON COLUMN series.description            IS 'Bilingual description {ar, en}';
COMMENT ON COLUMN series.cover_url              IS 'Path to banner image in organization_assets bucket';
COMMENT ON COLUMN series.is_active              IS 'Soft-toggle for visibility';
COMMENT ON COLUMN entities.series_id            IS 'FK → series — nullable so entities survive series deletion';
COMMENT ON COLUMN entities.sort_order           IS 'Ordinal position within a series (0 = first)';
-- ============================================================
-- BURHAN PLATFORM — Migration 00007
-- Add content_type, audio_url, audio_file to entities
-- ============================================================

-- 1. Add content_type to entities (video / article / audio)
ALTER TABLE entities
  ADD COLUMN IF NOT EXISTS content_type TEXT NOT NULL DEFAULT 'article';

-- 2. Add audio fields for podcast/audio content
ALTER TABLE entities
  ADD COLUMN IF NOT EXISTS audio_url  TEXT,
  ADD COLUMN IF NOT EXISTS audio_file TEXT;

-- 3. Update the type check constraint to include audio
--    (if a CHECK constraint already exists, skip or drop first)
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conrelid = 'entities'::regclass
    AND conname = 'entities_content_type_check'
  ) THEN
    ALTER TABLE entities DROP CONSTRAINT entities_content_type_check;
  END IF;
END $$;

ALTER TABLE entities
  ADD CONSTRAINT entities_content_type_check
  CHECK (content_type IN ('video', 'article', 'audio'));

-- 4. Comments
COMMENT ON COLUMN entities.content_type IS 'Content classification: video, article, or audio';
COMMENT ON COLUMN entities.audio_url     IS 'External streaming URL (SoundCloud, Spotify, etc.)';
COMMENT ON COLUMN entities.audio_file    IS 'Path to self-hosted .mp3 in organization_assets bucket';
-- ============================================================
-- BURHAN PLATFORM — Migration 00008
-- Fix Supabase Linter Security Warnings
--
-- 1. Remove public SELECT (listing) on storage.objects
--    (bucket is public; URL access works without listing)
-- 2. REVOKE EXECUTE on SECURITY DEFINER helper functions from
--    public/anon (they need auth.uid() so anon is useless)
-- 3. REVOKE EXECUTE on trigger handle_new_user() – trigger
--    only, never exposed via RPC
-- 4. DROP orphaned rls_auto_enable() if it exists
-- ============================================================

-- 1. Storage: remove public listing, keep public URL access
-- ============================================================
DROP POLICY IF EXISTS "org_assets_select" ON storage.objects;

-- Also drop any authenticated-only variant left from a previous run
DROP POLICY IF EXISTS "org_assets_select_authenticated" ON storage.objects;

-- 2. Revoke EXECUTE on org-helper functions from anon only
--    (authenticated users still need them for RLS policies;
--     we first strip public, then re-grant to authenticated)
-- ============================================================
REVOKE EXECUTE ON FUNCTION public.get_current_user_org_id()
  FROM public, anon;
GRANT EXECUTE ON FUNCTION public.get_current_user_org_id()
  TO authenticated;

REVOKE EXECUTE ON FUNCTION public.get_current_user_role()
  FROM public, anon;
GRANT EXECUTE ON FUNCTION public.get_current_user_role()
  TO authenticated;

-- 3. Revoke EXECUTE on trigger function from everyone
--    (safe: trigger fires with owner privileges, not via RPC)
-- ============================================================
REVOKE EXECUTE ON FUNCTION public.handle_new_user()
  FROM public, anon, authenticated;

-- 4. rls_auto_enable is used by Supabase internal event trigger
--    `ensure_rls` — can't drop; just revoke all user roles.
--    Trigger runs with owner privileges, so no re-grant needed.
-- ============================================================
REVOKE EXECUTE ON FUNCTION public.rls_auto_enable()
  FROM public, anon, authenticated;
-- ============================================================
-- BURHAN PLATFORM — Migration 00009
-- Digital Intellectual Observatory (المرصد الرقمي الفكري)
-- Global cross-tenant threat monitoring & refutation module
-- ============================================================

-- 1. OBSERVATORY ANALYSTS (local role table — no global enum change)
-- ============================================================
CREATE TABLE observatory_analysts (
  id           UUID PRIMARY KEY REFERENCES profiles(id) ON DELETE CASCADE,
  role_type    TEXT NOT NULL CHECK (role_type IN ('observatory_manager', 'observatory_analyst')),
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE  observatory_analysts IS 'Observatory module access control — fully isolated from global user_role enum';
COMMENT ON COLUMN observatory_analysts.role_type IS 'observatory_manager = full CRUD; observatory_analyst = select + limited update';

-- 2. OBSERVATORY THREATS
-- ============================================================
CREATE TABLE observatory_threats (
  id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title                TEXT NOT NULL,
  source_url           TEXT NOT NULL,
  platform             TEXT NOT NULL DEFAULT 'unknown',
  danger_level         TEXT NOT NULL DEFAULT 'Medium' CHECK (danger_level IN ('Low', 'Medium', 'High')),
  status               TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'under_review', 'neutralized')),
  assigned_scholar_id  UUID REFERENCES profiles(id) ON DELETE SET NULL,
  reported_by          UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  response_url         TEXT,
  created_at           TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE  observatory_threats IS 'Cross-tenant threat/misconception reports — sovereign global service';
COMMENT ON COLUMN observatory_threats.platform             IS 'Extracted from source_url: tiktok, youtube, facebook, x, instagram, telegram, other';
COMMENT ON COLUMN observatory_threats.danger_level         IS 'Low | Medium | High';
COMMENT ON COLUMN observatory_threats.status               IS 'pending → under_review → neutralized';
COMMENT ON COLUMN observatory_threats.reported_by          IS 'NULL for anonymous reports; FK for authenticated users';

CREATE INDEX idx_threats_status        ON observatory_threats (status);
CREATE INDEX idx_threats_platform      ON observatory_threats (platform);
CREATE INDEX idx_threats_created_at    ON observatory_threats (created_at DESC);
CREATE INDEX idx_threats_neutralized   ON observatory_threats (status) WHERE status = 'neutralized';

-- 3. TRIGGER — Auto-detect platform from source_url
-- ============================================================
CREATE OR REPLACE FUNCTION auto_detect_platform()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.platform := CASE
    WHEN NEW.source_url ~* 'tiktok\.com'     THEN 'tiktok'
    WHEN NEW.source_url ~* 'youtube\.com'    THEN 'youtube'
    WHEN NEW.source_url ~* 'youtu\.be'       THEN 'youtube'
    WHEN NEW.source_url ~* 'facebook\.com'   THEN 'facebook'
    WHEN NEW.source_url ~* 'x\.com'          THEN 'x'
    WHEN NEW.source_url ~* 'twitter\.com'    THEN 'x'
    WHEN NEW.source_url ~* 'instagram\.com'  THEN 'instagram'
    WHEN NEW.source_url ~* 'telegram\.(me|org)' THEN 'telegram'
    ELSE 'other'
  END;
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_auto_detect_platform
  BEFORE INSERT ON observatory_threats
  FOR EACH ROW
  EXECUTE FUNCTION auto_detect_platform();

-- 4. HELPER FUNCTION — Bypass RLS to avoid recursion
-- SECURITY DEFINER lets us query observatory_analysts from its own policies
-- ============================================================
CREATE OR REPLACE FUNCTION is_observatory_manager()
RETURNS BOOLEAN
LANGUAGE SQL
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM observatory_analysts
    WHERE id = auth.uid() AND role_type = 'observatory_manager'
  );
$$;

CREATE OR REPLACE FUNCTION is_super_admin()
RETURNS BOOLEAN
LANGUAGE SQL
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM profiles
    WHERE id = auth.uid() AND role = 'super_admin'
  );
$$;

-- 5. ROW LEVEL SECURITY
-- ============================================================

ALTER TABLE observatory_analysts ENABLE ROW LEVEL SECURITY;
ALTER TABLE observatory_threats  ENABLE ROW LEVEL SECURITY;

-- 5a. observatory_analysts RLS
-- Uses SECURITY DEFINER helpers to prevent recursion
-- ============================================================

CREATE POLICY "analysts_select_own"
  ON observatory_analysts FOR SELECT
  USING (id = auth.uid());

CREATE POLICY "analysts_select_all_manager_or_super_admin"
  ON observatory_analysts FOR SELECT
  USING (is_observatory_manager() OR is_super_admin());

CREATE POLICY "analysts_insert_manager_only"
  ON observatory_analysts FOR INSERT
  WITH CHECK (is_observatory_manager() OR is_super_admin());

CREATE POLICY "analysts_delete_manager_only"
  ON observatory_analysts FOR DELETE
  USING (is_observatory_manager() OR is_super_admin());

-- 5b. observatory_threats RLS
-- ============================================================

-- PUBLIC / Anon: INSERT only, no SELECT/UPDATE/DELETE
CREATE POLICY "threats_insert_public"
  ON observatory_threats FOR INSERT
  TO anon, authenticated
  WITH CHECK (true);

-- Super admin: full access
CREATE POLICY "threats_select_super_admin"
  ON observatory_threats FOR SELECT
  USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'super_admin')
  );

CREATE POLICY "threats_update_super_admin"
  ON observatory_threats FOR UPDATE
  USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'super_admin')
  );

CREATE POLICY "threats_delete_super_admin"
  ON observatory_threats FOR DELETE
  USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'super_admin')
  );

-- Observatory manager: full CRUD (same as super admin for threats)
CREATE POLICY "threats_select_manager"
  ON observatory_threats FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM observatory_analysts
      WHERE id = auth.uid() AND role_type = 'observatory_manager'
    )
  );

CREATE POLICY "threats_update_manager"
  ON observatory_threats FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM observatory_analysts
      WHERE id = auth.uid() AND role_type = 'observatory_manager'
    )
  );

CREATE POLICY "threats_delete_manager"
  ON observatory_threats FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM observatory_analysts
      WHERE id = auth.uid() AND role_type = 'observatory_manager'
    )
  );

-- Observatory analyst: SELECT + limited UPDATE (status, response_url, assigned_scholar_id)
CREATE POLICY "threats_select_analyst"
  ON observatory_threats FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM observatory_analysts
      WHERE id = auth.uid() AND role_type = 'observatory_analyst'
    )
  );

CREATE POLICY "threats_update_analyst"
  ON observatory_threats FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM observatory_analysts
      WHERE id = auth.uid() AND role_type = 'observatory_analyst'
    )
  );

-- 6. PUBLIC SELECT — Allow viewing neutralized threats without auth
-- ============================================================
CREATE POLICY "threats_select_neutralized_public"
  ON observatory_threats FOR SELECT
  TO anon, authenticated
  USING (status = 'neutralized');

-- 7. SEED DATA (Proof of Concept)
-- ============================================================
INSERT INTO observatory_threats (title, source_url, platform, danger_level, status, response_url) VALUES
(
  'شبهة حول تحريف القرآن الكريم',
  'https://www.tiktok.com/@user/video/123456',
  'tiktok',
  'High',
  'neutralized',
  'https://youtube.com/watch?v=demo-refutation-1'
),
(
  'مغالطة علمية حول نظرية التطور',
  'https://www.youtube.com/watch?v=demo-misconception',
  'youtube',
  'Medium',
  'neutralized',
  'https://youtube.com/watch?v=demo-refutation-2'
),
(
  'شائعة عن تحريف الإنجيل في الإسلام',
  'https://www.facebook.com/demo/posts/789',
  'facebook',
  'High',
  'under_review',
  NULL
),
(
  'مغالطة حول حقوق المرأة في الإسلام',
  'https://x.com/demo/status/123456',
  'x',
  'Medium',
  'pending',
  NULL
);
-- ============================================================
-- BURHAN PLATFORM — Migration 00010
-- Hardened DeAI Backend: AI jobs, quota accounting, terminal
-- state machine, watchdog, atomic reconciliation.
--
-- Design summary (see map2.md directive sections 3-21):
--  * Membership authorization uses profiles.id + profiles.organization_id + profiles.role.
--    NO "organization_members" table exists anywhere. Never invent it.
--  * All RPCs accept an explicit p_user_id (service-role path). They never
--    depend on auth.uid() being populated. The Nitro server passes the
--    verified user id (browser JWT -> Nitro auth -> RPC).
--  * reserve_ai_quota / create_ai_job use SELECT ... FOR UPDATE (row lock)
--    + conditional UPDATE so two concurrent reservations cannot oversubscribe.
--  * Terminal transitions (complete/fail/cancel/reap) are ATOMIC with quota
--    reconciliation: the conditional status transition (WHERE status=...) and
--    the ai_usage delta happen in ONE transaction. quota_reconciled guards
--    idempotency; a recovery sweep reconciles any terminal job left
--    unreconciled exactly once (crash-window invariant).
--  * Reconciliation always targets the job's original period_month — never
--    CURRENT_DATE at reconcile time.
--  * Per the 00008 convention: REVOKE EXECUTE FROM public/anon/authenticated
--    and GRANT EXECUTE only to service_role. The browser cannot mutate jobs;
--    the client is limited to a SELECT-own RLS policy.
--  * Quota semantics: requests are consumed at admission (never refunded);
--    tokens are estimated-reserved at admission and reconciled at terminal:
--      completed => tokens_used += actual; tokens_reserved -= estimated (net actual)
--      failed/cancelled => tokens_reserved -= estimated (release 0 - E)
-- ============================================================

-- ============================================================
-- 1. TABLES
-- ============================================================

CREATE TABLE IF NOT EXISTS ai_jobs (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id           UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  organization_id   UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  branch_id         UUID REFERENCES branches(id) ON DELETE SET NULL,
  prompt            TEXT NOT NULL,
  system_prompt     TEXT,
  language          TEXT NOT NULL DEFAULT 'ar',
  model             TEXT,
  status            TEXT NOT NULL DEFAULT 'pending'
                    CHECK (status IN ('pending', 'processing', 'completed', 'failed', 'cancelled')),
  output_buffer     TEXT NOT NULL DEFAULT '',
  output_final      TEXT,
  error             TEXT,
  tokens_estimated  INTEGER NOT NULL DEFAULT 0 CHECK (tokens_estimated >= 0),
  tokens_used       INTEGER CHECK (tokens_used >= 0),
  period_month      TEXT NOT NULL CHECK (period_month ~ '^[0-9]{4}-[0-9]{2}$'),
  quota_reconciled  BOOLEAN NOT NULL DEFAULT FALSE,
  consumed          BOOLEAN NOT NULL DEFAULT FALSE,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  last_heartbeat_at TIMESTAMPTZ
);

COMMENT ON TABLE  ai_jobs IS 'Server-only AI inference job lifecycle. Client may only SELECT own rows.';
COMMENT ON COLUMN ai_jobs.status IS 'pending -> processing -> {completed|failed|cancelled}; terminal states are immutable.';
COMMENT ON COLUMN ai_jobs.period_month IS 'Immutable original quota period (YYYY-MM); reconciliation uses this, never CURRENT_DATE.';
COMMENT ON COLUMN ai_jobs.quota_reconciled IS 'Idempotency guard: exactly one successful reconciliation per terminal job.';
COMMENT ON COLUMN ai_jobs.last_heartbeat_at IS 'Worker liveness field for the watchdog (kept separate from updated_at).';

CREATE INDEX IF NOT EXISTS idx_ai_jobs_organization_id ON ai_jobs (organization_id);
CREATE INDEX IF NOT EXISTS idx_ai_jobs_user_id         ON ai_jobs (user_id);
CREATE INDEX IF NOT EXISTS idx_ai_jobs_status          ON ai_jobs (status);
CREATE INDEX IF NOT EXISTS idx_ai_jobs_stale
  ON ai_jobs (status, last_heartbeat_at)
  WHERE status IN ('pending', 'processing');

CREATE TABLE IF NOT EXISTS ai_usage (
  organization_id   UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  period_month      TEXT NOT NULL CHECK (period_month ~ '^[0-9]{4}-[0-9]{2}$'),
  requests_used     INTEGER NOT NULL DEFAULT 0 CHECK (requests_used >= 0),
  tokens_reserved   INTEGER NOT NULL DEFAULT 0 CHECK (tokens_reserved >= 0),
  tokens_used       INTEGER NOT NULL DEFAULT 0 CHECK (tokens_used >= 0),
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (organization_id, period_month)
);

COMMENT ON TABLE  ai_usage IS 'Organization/month AI quota accounting. UNIQUE(organization_id, period_month) enforced via PK.';
COMMENT ON COLUMN ai_usage.requests_used   IS 'Admitted requests. Consumed at admission/reservation; never refunded on inference failure/cancellation.';
COMMENT ON COLUMN ai_usage.tokens_reserved IS 'Estimated tokens reserved for in-flight/pending jobs. Released on terminal transition.';
COMMENT ON COLUMN ai_usage.tokens_used     IS 'Final billable tokens for terminal jobs (actual on success, 0 on failure/cancellation).';

-- ============================================================
-- 2. HELPERS (SECURITY DEFINER, narrow responsibility)
-- ============================================================

-- Super-admin check over an explicit user id (service-role path).
CREATE OR REPLACE FUNCTION public.ai_is_super_admin(p_user_id UUID)
RETURNS BOOLEAN
LANGUAGE SQL
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM profiles WHERE id = p_user_id AND role = 'super_admin'
  );
$$;

-- Internal: validate membership and perform the ATOMIC estimated-token
-- reservation for (organization, current period) under a row lock.
-- Raises:
--   ai_unauthorized            user unknown or not a member of p_org_id
--   ai_invalid_estimate        negative/zero estimate
--   ai_quota_exceeded          request or token limit would be breached
CREATE OR REPLACE FUNCTION public.ai_reserve_usage(
  p_user_id          UUID,
  p_org_id           UUID,
  p_tokens_estimated INTEGER,
  p_request_limit    INTEGER,
  p_token_limit      INTEGER
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_member   BOOLEAN;
  v_period   TEXT;
  v_requests INTEGER;
  v_reserved INTEGER;
BEGIN
  IF p_tokens_estimated IS NULL OR p_tokens_estimated < 0 THEN
    RAISE EXCEPTION 'ai_invalid_estimate'
      USING ERRCODE = 'P0001';
  END IF;
  IF p_request_limit IS NULL OR p_token_limit IS NULL OR p_request_limit < 0 OR p_token_limit < 0 THEN
    RAISE EXCEPTION 'ai_invalid_limit'
      USING ERRCODE = 'P0001';
  END IF;

  -- Authorization: explicit p_user_id must belong to p_org_id (or be super admin).
  SELECT (role = 'super_admin' OR organization_id = p_org_id) INTO v_member
    FROM profiles WHERE id = p_user_id;
  IF v_member IS NULL OR NOT v_member THEN
    RAISE EXCEPTION 'ai_unauthorized'
      USING ERRCODE = 'P0001';
  END IF;

  -- Original quota period is fixed at reservation/admission time.
  v_period := to_char(current_date, 'YYYY-MM');

  -- Create the usage row if necessary, then LOCK it to serialize admissions.
  INSERT INTO ai_usage (organization_id, period_month)
  VALUES (p_org_id, v_period)
  ON CONFLICT (organization_id, period_month) DO NOTHING;

  SELECT requests_used, tokens_reserved INTO v_requests, v_reserved
    FROM ai_usage
    WHERE organization_id = p_org_id AND period_month = v_period
    FOR UPDATE;

  IF v_requests IS NULL THEN
    RAISE EXCEPTION 'ai_usage_row_missing'
      USING ERRCODE = 'P0001';
  END IF;

  -- Checks under the row lock (no SELECT/IF/UPDATE race window).
  IF v_requests + 1 > p_request_limit THEN
    RAISE EXCEPTION 'ai_quota_exceeded'
      USING ERRCODE = 'P0001',
            DETAIL = 'request limit';
  END IF;
  IF v_reserved + p_tokens_estimated > p_token_limit THEN
    RAISE EXCEPTION 'ai_quota_exceeded'
      USING ERRCODE = 'P0001',
            DETAIL = 'token limit';
  END IF;

  -- Increment the reservation (request consumed at admission; never refunded).
  UPDATE ai_usage
    SET requests_used   = requests_used + 1,
        tokens_reserved = tokens_reserved + p_tokens_estimated,
        updated_at      = now()
    WHERE organization_id = p_org_id AND period_month = v_period;

  RETURN jsonb_build_object(
    'organization_id', p_org_id,
    'period_month',    v_period,
    'requests_used',   v_requests + 1,
    'tokens_reserved', v_reserved + p_tokens_estimated
  );
END;
$$;

-- Internal: reconcile a job's quota exactly once (idempotent).
-- Safe to call from: terminal transition RPCs (same transaction) and the
-- recovery sweep for terminal jobs left unreconciled (crash-window invariant).
CREATE OR REPLACE FUNCTION public.ai_reconcile_job(p_job_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_status      TEXT;
  v_org         UUID;
  v_period      TEXT;
  v_estimated   INTEGER;
  v_used        INTEGER;
  v_reconciled  BOOLEAN;
  v_delta_used  INTEGER;
BEGIN
  SELECT status, organization_id, period_month, tokens_estimated,
         COALESCE(tokens_used, tokens_estimated), quota_reconciled
    INTO v_status, v_org, v_period, v_estimated, v_used, v_reconciled
    FROM ai_jobs WHERE id = p_job_id FOR UPDATE;

  IF NOT FOUND OR v_reconciled OR v_status IN ('pending', 'processing') THEN
    RETURN FALSE;
  END IF;

  -- completed => final accounting = actual (A - E net of reservation release).
  -- failed/cancelled => release the reserved estimate (0 - E).
  IF v_status = 'completed' THEN
    v_delta_used := v_used;
  ELSE
    v_delta_used := 0;
  END IF;

  UPDATE ai_usage
    SET tokens_used     = tokens_used + v_delta_used,
        tokens_reserved = tokens_reserved - v_estimated,
        updated_at      = now()
    WHERE organization_id = v_org AND period_month = v_period;

  UPDATE ai_jobs
    SET quota_reconciled = TRUE,
        updated_at       = now()
    WHERE id = p_job_id;

  RETURN TRUE;
END;
$$;

-- ============================================================
-- 3. ADMISSION RPCs (service-role only)
-- ============================================================

-- Standalone atomic reservation (audit + tests + admission primitive).
CREATE OR REPLACE FUNCTION public.reserve_ai_quota(
  p_user_id          UUID,
  p_org_id           UUID,
  p_tokens_estimated INTEGER,
  p_request_limit    INTEGER,
  p_token_limit      INTEGER
)
RETURNS jsonb
LANGUAGE SQL
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT public.ai_reserve_usage(p_user_id, p_org_id, p_tokens_estimated, p_request_limit, p_token_limit);
$$;

-- Atomic admission + job creation in ONE transaction (no orphaned reservation
-- window between reserve and insert).
CREATE OR REPLACE FUNCTION public.create_ai_job(
  p_user_id          UUID,
  p_org_id           UUID,
  p_branch_id        UUID,
  p_prompt           TEXT,
  p_system_prompt    TEXT,
  p_language         TEXT DEFAULT 'ar',
  p_model            TEXT DEFAULT NULL,
  p_tokens_estimated INTEGER DEFAULT 500,
  p_request_limit    INTEGER DEFAULT NULL,
  p_token_limit      INTEGER DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_res     jsonb;
  v_period  TEXT;
  v_job_id  UUID;
BEGIN
  IF p_prompt IS NULL OR length(trim(p_prompt)) = 0 THEN
    RAISE EXCEPTION 'ai_invalid_prompt'
      USING ERRCODE = 'P0001';
  END IF;

  -- Branch, when provided, must belong to the same organization.
  IF p_branch_id IS NOT NULL
     AND NOT EXISTS (SELECT 1 FROM branches WHERE id = p_branch_id AND organization_id = p_org_id) THEN
    RAISE EXCEPTION 'ai_invalid_branch'
      USING ERRCODE = 'P0001';
  END IF;

  v_res := public.ai_reserve_usage(
    p_user_id, p_org_id, p_tokens_estimated, p_request_limit, p_token_limit
  );
  v_period := v_res ->> 'period_month';

  INSERT INTO ai_jobs (
    user_id, organization_id, branch_id, prompt, system_prompt,
    language, model, tokens_estimated, period_month, status
  )
  VALUES (
    p_user_id, p_org_id, p_branch_id, p_prompt, p_system_prompt,
    COALESCE(p_language, 'ar'), p_model, p_tokens_estimated, v_period, 'pending'
  )
  RETURNING id INTO v_job_id;

  RETURN jsonb_build_object(
    'id',              v_job_id,
    'organization_id', p_org_id,
    'period_month',    v_period,
    'status',          'pending'
  );
END;
$$;

-- ============================================================
-- 4. LIFECYCLE RPCs (worker / server-only)
-- ============================================================

-- Claim: pending -> processing (conditional). Sets worker liveness.
CREATE OR REPLACE FUNCTION public.start_ai_job(
  p_job_id UUID,
  p_user_id UUID,
  p_model TEXT DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_out    jsonb;
  v_status TEXT;
  v_owned  BOOLEAN;
BEGIN
  UPDATE ai_jobs
    SET status = 'processing',
        model = COALESCE(p_model, model),
        last_heartbeat_at = now(),
        updated_at = now()
    WHERE id = p_job_id
      AND status = 'pending'
      AND (user_id = p_user_id OR public.ai_is_super_admin(p_user_id))
    RETURNING jsonb_build_object('changed', TRUE, 'status', 'processing') INTO v_out;

  IF v_out IS NOT NULL THEN
    RETURN v_out;
  END IF;

  SELECT status, (user_id = p_user_id OR public.ai_is_super_admin(p_user_id))
    INTO v_status, v_owned
    FROM ai_jobs WHERE id = p_job_id;

  IF v_status IS NULL THEN
    RETURN jsonb_build_object('changed', FALSE, 'reason', 'missing');
  END IF;
  IF NOT v_owned THEN
    RAISE EXCEPTION 'ai_unauthorized' USING ERRCODE = 'P0001';
  END IF;

  RETURN jsonb_build_object('changed', FALSE, 'status', v_status);
END;
$$;

-- Worker liveness + persisted cumulative output buffer. Only valid in
-- 'processing'; never touches terminal jobs.
CREATE OR REPLACE FUNCTION public.heartbeat_ai_job(
  p_job_id        UUID,
  p_user_id       UUID,
  p_output_buffer TEXT DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_status TEXT;
  v_owned  BOOLEAN;
BEGIN
  SELECT status, (user_id = p_user_id OR public.ai_is_super_admin(p_user_id))
    INTO v_status, v_owned
    FROM ai_jobs WHERE id = p_job_id;

  IF v_status IS NULL THEN
    RETURN jsonb_build_object('changed', FALSE, 'reason', 'missing');
  END IF;
  IF NOT v_owned THEN
    RAISE EXCEPTION 'ai_unauthorized' USING ERRCODE = 'P0001';
  END IF;
  IF v_status <> 'processing' THEN
    RETURN jsonb_build_object('changed', FALSE, 'status', v_status);
  END IF;

  UPDATE ai_jobs
    SET last_heartbeat_at = now(),
        output_buffer     = COALESCE(p_output_buffer, output_buffer),
        updated_at        = now()
    WHERE id = p_job_id;

  RETURN jsonb_build_object('changed', TRUE, 'status', 'processing');
END;
$$;

-- ============================================================
-- 5. TERMINAL TRANSITIONS — each is ATOMIC with reconciliation
-- ============================================================

-- processing -> completed. Reconciles tokens_used += actual (reservation released).
CREATE OR REPLACE FUNCTION public.complete_ai_job(
  p_job_id       UUID,
  p_user_id      UUID,
  p_tokens_used  INTEGER DEFAULT NULL,
  p_output_final TEXT DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_status TEXT;
  v_owned  BOOLEAN;
BEGIN
  SELECT status, (user_id = p_user_id OR public.ai_is_super_admin(p_user_id))
    INTO v_status, v_owned
    FROM ai_jobs WHERE id = p_job_id FOR UPDATE;

  IF v_status IS NULL THEN
    RETURN jsonb_build_object('changed', FALSE, 'reason', 'missing');
  END IF;
  IF NOT v_owned THEN
    RAISE EXCEPTION 'ai_unauthorized' USING ERRCODE = 'P0001';
  END IF;
  IF v_status <> 'processing' THEN
    RETURN jsonb_build_object('changed', FALSE, 'status', v_status);
  END IF;

  -- Conditional transition (we own it). Reconciliation follows in the SAME transaction.
  UPDATE ai_jobs
    SET status      = 'completed',
        tokens_used = COALESCE(p_tokens_used, tokens_estimated),
        output_final = COALESCE(p_output_final, output_buffer),
        error       = NULL,
        updated_at  = now()
    WHERE id = p_job_id;

  PERFORM public.ai_reconcile_job(p_job_id);

  RETURN jsonb_build_object('changed', TRUE, 'status', 'completed');
END;
$$;

-- {pending|processing} -> failed. Releases the reserved estimate (0 - E).
CREATE OR REPLACE FUNCTION public.fail_ai_job(
  p_job_id  UUID,
  p_user_id UUID,
  p_error   TEXT DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_status TEXT;
  v_owned  BOOLEAN;
BEGIN
  SELECT status, (user_id = p_user_id OR public.ai_is_super_admin(p_user_id))
    INTO v_status, v_owned
    FROM ai_jobs WHERE id = p_job_id FOR UPDATE;

  IF v_status IS NULL THEN
    RETURN jsonb_build_object('changed', FALSE, 'reason', 'missing');
  END IF;
  IF NOT v_owned THEN
    RAISE EXCEPTION 'ai_unauthorized' USING ERRCODE = 'P0001';
  END IF;
  IF v_status NOT IN ('pending', 'processing') THEN
    RETURN jsonb_build_object('changed', FALSE, 'status', v_status);
  END IF;

  UPDATE ai_jobs
    SET status     = 'failed',
        error      = COALESCE(p_error, 'Inference failed'),
        updated_at = now()
    WHERE id = p_job_id;

  PERFORM public.ai_reconcile_job(p_job_id);

  RETURN jsonb_build_object('changed', TRUE, 'status', 'failed');
END;
$$;

-- {pending|processing} -> cancelled (strict ownership: own job only or super admin).
-- Releases the reserved estimate exactly once.
CREATE OR REPLACE FUNCTION public.cancel_ai_job(
  p_job_id  UUID,
  p_user_id UUID
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_status TEXT;
  v_owned  BOOLEAN;
BEGIN
  SELECT status, (user_id = p_user_id OR public.ai_is_super_admin(p_user_id))
    INTO v_status, v_owned
    FROM ai_jobs WHERE id = p_job_id FOR UPDATE;

  IF v_status IS NULL THEN
    RETURN jsonb_build_object('changed', FALSE, 'reason', 'missing');
  END IF;
  IF NOT v_owned THEN
    RAISE EXCEPTION 'ai_unauthorized' USING ERRCODE = 'P0001';
  END IF;
  IF v_status NOT IN ('pending', 'processing') THEN
    RETURN jsonb_build_object('changed', FALSE, 'status', v_status);
  END IF;

  UPDATE ai_jobs
    SET status     = 'cancelled',
        updated_at = now()
    WHERE id = p_job_id;

  PERFORM public.ai_reconcile_job(p_job_id);

  RETURN jsonb_build_object('changed', TRUE, 'status', 'cancelled');
END;
$$;

-- Consumed marker (Accept/Discard completed flow). No accounting change.
CREATE OR REPLACE FUNCTION public.consume_ai_job(
  p_job_id  UUID,
  p_user_id UUID
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_ok BOOLEAN;
BEGIN
  UPDATE ai_jobs
    SET consumed   = TRUE,
        updated_at = now()
    WHERE id = p_job_id
      AND user_id = p_user_id
      AND status = 'completed'
    RETURNING TRUE INTO v_ok;

  IF v_ok THEN
    RETURN jsonb_build_object('changed', TRUE, 'consumed', TRUE);
  END IF;

  SELECT (status = 'completed' AND user_id = p_user_id)
    INTO v_ok
    FROM ai_jobs WHERE id = p_job_id;

  RETURN jsonb_build_object('changed', FALSE, 'consumed', COALESCE(v_ok, FALSE));
END;
$$;

-- ============================================================
-- 6. WATCHDOG (lazy reaper) — conditional, idempotent, reconciles
--    ONLY when it actually transitioned processing -> failed.
-- ============================================================
CREATE OR REPLACE FUNCTION public.reap_stale_ai_job(
  p_job_id               UUID,
  p_stale_after_seconds  INTEGER DEFAULT 90
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_status         TEXT;
  v_hb             TIMESTAMPTZ;
  v_max            TIMESTAMPTZ;
BEGIN
  v_max := now() - make_interval(secs => GREATEST(p_stale_after_seconds, 1));

  SELECT status, last_heartbeat_at INTO v_status, v_hb
    FROM ai_jobs WHERE id = p_job_id FOR UPDATE;

  IF NOT FOUND OR v_status IS NULL THEN
    RETURN jsonb_build_object('changed', FALSE, 'reason', 'missing');
  END IF;

  -- Only an in-flight job with a stale (or never-beaten) heartbeat is eligible.
  IF v_status <> 'processing'
     OR (v_hb IS NOT NULL AND v_hb >= v_max) THEN
    RETURN jsonb_build_object('changed', FALSE, 'status', v_status);
  END IF;

  UPDATE ai_jobs
    SET status     = 'failed',
        error      = 'Watchdog: stale heartbeat (no heartbeat within ' || p_stale_after_seconds || 's)',
        updated_at = now()
    WHERE id = p_job_id;

  -- Only after the conditional transition succeeded may we reconcile.
  PERFORM public.ai_reconcile_job(p_job_id);

  RETURN jsonb_build_object('changed', TRUE, 'status', 'failed');
END;
$$;

-- ============================================================
-- 7. RECOVERY SWEEP — crash-window invariant:
--    every terminal job gets exactly one reconciliation; no terminal job
--    may remain permanently unreconciled. Normally a no-op because the
--    terminal transition RPCs are atomic with reconciliation.
-- ============================================================
CREATE OR REPLACE FUNCTION public.reconcile_abandoned_terminal_ai_jobs(
  p_job_id UUID DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_row   RECORD;
  v_count INTEGER := 0;
BEGIN
  FOR v_row IN
    SELECT id FROM ai_jobs
    WHERE status IN ('completed', 'failed', 'cancelled')
      AND quota_reconciled = FALSE
      AND (p_job_id IS NULL OR id = p_job_id)
    ORDER BY id
    FOR UPDATE SKIP LOCKED
  LOOP
    IF public.ai_reconcile_job(v_row.id) THEN
      v_count := v_count + 1;
    END IF;
  END LOOP;

  RETURN jsonb_build_object('reconciled', v_count);
END;
$$;

-- ============================================================
-- 8. ROW LEVEL SECURITY
-- ============================================================

ALTER TABLE ai_jobs  ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_usage ENABLE ROW LEVEL SECURITY;

-- Client: SELECT own jobs only. No INSERT/UPDATE/DELETE policies:
-- job lifecycle is server-only (service-role path).
CREATE POLICY "ai_jobs_select_own"
  ON ai_jobs FOR SELECT TO authenticated
  USING (user_id = auth.uid());

-- Client: read own organization's usage (existing helper pattern from 00003).
CREATE POLICY "ai_usage_select_org"
  ON ai_usage FOR SELECT TO authenticated
  USING (
    organization_id = public.get_current_user_org_id()
    OR public.get_current_user_role() = 'super_admin'
  );

-- ============================================================
-- 9. PRIVILEGES
-- ============================================================

-- Server-only lifecycle: strip accidental client write privileges that
-- Supabase default privileges would otherwise bestow on new tables.
REVOKE INSERT, UPDATE, DELETE ON ai_jobs  FROM anon, authenticated;
REVOKE INSERT, UPDATE, DELETE ON ai_usage FROM anon, authenticated;
REVOKE SELECT ON ai_jobs  FROM anon;
REVOKE SELECT ON ai_usage FROM anon;
GRANT SELECT ON ai_jobs  TO authenticated;

-- RPCs are service-role only (server path). Supabase complains loudly if we
-- expose strongly privileged SECURITY DEFINER functions to the client.
REVOKE EXECUTE ON FUNCTION public.ai_is_super_admin(UUID)     FROM public, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.ai_reserve_usage(UUID, UUID, INTEGER, INTEGER, INTEGER) FROM public, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.ai_reconcile_job(UUID)      FROM public, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.reserve_ai_quota(UUID, UUID, INTEGER, INTEGER, INTEGER) FROM public, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.create_ai_job(UUID, UUID, UUID, TEXT, TEXT, TEXT, TEXT, INTEGER, INTEGER, INTEGER) FROM public, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.start_ai_job(UUID, UUID, TEXT)            FROM public, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.heartbeat_ai_job(UUID, UUID, TEXT)        FROM public, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.complete_ai_job(UUID, UUID, INTEGER, TEXT) FROM public, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.fail_ai_job(UUID, UUID, TEXT)             FROM public, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.cancel_ai_job(UUID, UUID)                 FROM public, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.consume_ai_job(UUID, UUID)                FROM public, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.reap_stale_ai_job(UUID, INTEGER)          FROM public, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.reconcile_abandoned_terminal_ai_jobs(UUID) FROM public, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.ai_is_super_admin(UUID)     TO service_role;
GRANT EXECUTE ON FUNCTION public.ai_reserve_usage(UUID, UUID, INTEGER, INTEGER, INTEGER) TO service_role;
GRANT EXECUTE ON FUNCTION public.ai_reconcile_job(UUID)      TO service_role;
GRANT EXECUTE ON FUNCTION public.reserve_ai_quota(UUID, UUID, INTEGER, INTEGER, INTEGER) TO service_role;
GRANT EXECUTE ON FUNCTION public.create_ai_job(UUID, UUID, UUID, TEXT, TEXT, TEXT, TEXT, INTEGER, INTEGER, INTEGER) TO service_role;
GRANT EXECUTE ON FUNCTION public.start_ai_job(UUID, UUID, TEXT)            TO service_role;
GRANT EXECUTE ON FUNCTION public.heartbeat_ai_job(UUID, UUID, TEXT)        TO service_role;
GRANT EXECUTE ON FUNCTION public.complete_ai_job(UUID, UUID, INTEGER, TEXT) TO service_role;
GRANT EXECUTE ON FUNCTION public.fail_ai_job(UUID, UUID, TEXT)             TO service_role;
GRANT EXECUTE ON FUNCTION public.cancel_ai_job(UUID, UUID)                 TO service_role;
GRANT EXECUTE ON FUNCTION public.consume_ai_job(UUID, UUID)                TO service_role;
GRANT EXECUTE ON FUNCTION public.reap_stale_ai_job(UUID, INTEGER)          TO service_role;
GRANT EXECUTE ON FUNCTION public.reconcile_abandoned_terminal_ai_jobs(UUID) TO service_role;-- ============================================================
-- BURHAN PLATFORM — Migration 00011
-- Restore Anonymous Public-Read RLS Paths (00008 regression fix)
--
-- Problem (regression introduced by applying 00008 as written):
--   00008 REVOKE'd EXECUTE on get_current_user_org_id() /
--   get_current_user_role() FROM public, anon (granting only to
--   authenticated). PostgreSQL evaluates the RLS SELECT qualifier
--   as the OR of ALL permissive SELECT policies applicable to the
--   requesting role. Migrations 00001/00009 created the privileged
--   tenant/role SELECT policies WITHOUT a `TO role` clause, so they
--   applied to every role (polroles = 0 = public), including anon.
--   Under anon their predicates are always FALSE (id = auth.uid()
--   with auth.uid() NULL), but PostgreSQL still EXECUTES those
--   predicate expressions; the correlated `profiles` subqueries hit
--   profiles RLS (profiles_select_org_members) which calls the
--   now-revoked helpers => 42501 `permission denied for function
--   get_current_user_org_id`. The error aborts the whole statement,
--   so even rows that the separate public-read policy would admit
--   become unreadable (anonymous public entity reads, the Nitrogen
--   `/api/entities/public` feed, and neutralized Observatory reads).
--
-- Fix (preserves the 00008 security tightening):
--   Do NOT re-grant EXECUTE to public/anon. Instead scope the
--   privileged SELECT policies to `TO authenticated` so anonymous
--   requests evaluate ONLY the public-read policy. This follows the
--   repository's existing convention of explicit role arms already
--   used by 00006 (series_select_org TO authenticated /
--   series_select_public TO anon) and 00010 (ai_jobs_select_own
--   TO authenticated).
--
-- Anonymous public-read is already owned by separate public policies
-- which are intentionally left untouched:
--   * entities_select_public_hub       USING (is_public_to_hub = true AND is_premium = false)
--   * threats_select_neutralized_public TO anon, authenticated USING (status = 'neutralized')
--
-- The four predicates below are purely privileged/authenticated
-- (they require id = auth.uid() membership/role and are FALSE for
-- anon); scoping them to `authenticated` changes NO row visibility
-- and removes the anon 42501 abort path.
-- ============================================================

-- ============================================================
-- 1. entities — tenant-scoped select policy
-- ============================================================
DROP POLICY IF EXISTS "entities_select_org_member" ON entities;

CREATE POLICY "entities_select_org_member"
  ON entities FOR SELECT TO authenticated
  USING (
    (
      organization_id IN (
        SELECT organization_id FROM profiles WHERE id = auth.uid()
      )
      AND (
        is_premium = false
        OR
        EXISTS (
          SELECT 1 FROM profiles
          WHERE id = auth.uid()
            AND organization_id = entities.organization_id
            AND role IN ('owner', 'manager')
        )
      )
    )
    OR
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'super_admin')
  );

-- ============================================================
-- 2. observatory_threats — privileged role select policies
-- ============================================================

-- Super admin: full visibility
DROP POLICY IF EXISTS "threats_select_super_admin" ON observatory_threats;

CREATE POLICY "threats_select_super_admin"
  ON observatory_threats FOR SELECT TO authenticated
  USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'super_admin')
  );

-- Observatory manager: full visibility (same as super admin for threats)
DROP POLICY IF EXISTS "threats_select_manager" ON observatory_threats;

CREATE POLICY "threats_select_manager"
  ON observatory_threats FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM observatory_analysts
      WHERE id = auth.uid() AND role_type = 'observatory_manager'
    )
  );

-- Observatory analyst: SELECT (plus limited UPDATE outside this migration)
DROP POLICY IF EXISTS "threats_select_analyst" ON observatory_threats;

CREATE POLICY "threats_select_analyst"
  ON observatory_threats FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM observatory_analysts
      WHERE id = auth.uid() AND role_type = 'observatory_analyst'
    )
  );

-- ============================================================
-- BURHAN PLATFORM — Migration 00012
-- Storage Tenant Isolation (organization_assets)
--
-- M1.6 regression gate confirmed a cross-tenant Storage mutation
-- gap: the 00005 policies only checked `bucket_id`, so any
-- authenticated user could INSERT/UPDATE/DELETE objects under
-- another organization's prefix.
--
-- Contract: "{organizationId}/entities/{uuid}.{ext}"
-- An authenticated user may mutate a Storage object only when the
-- first path segment equals their own profile.organization_id.
--
-- Scope (additive, policy-only):
--   - recreate org_assets_insert / org_assets_update / org_assets_delete
--   - strict tenant isolation: no super_admin cross-org exception
--     (super_admin has organization_id = NULL and no storage workflow)
--   - org_assets_select is intentionally NOT recreated: it was
--     dropped by 00008; the bucket is public, so URL access works
--     without listing.
--   - service_role continues to bypass RLS for server/admin cleanup.
-- ============================================================

-- 1. INSERT: tenant-scoped WITH CHECK
-- ============================================================
DROP POLICY IF EXISTS "org_assets_insert" ON storage.objects;

CREATE POLICY "org_assets_insert"
  ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'organization_assets'
    AND (storage.foldername(name))[1] = public.get_current_user_org_id()::text
  );

-- 2. UPDATE: tenant-scoped USING + WITH CHECK
-- ============================================================
DROP POLICY IF EXISTS "org_assets_update" ON storage.objects;

CREATE POLICY "org_assets_update"
  ON storage.objects FOR UPDATE TO authenticated
  USING (
    bucket_id = 'organization_assets'
    AND (storage.foldername(name))[1] = public.get_current_user_org_id()::text
  )
  WITH CHECK (
    bucket_id = 'organization_assets'
    AND (storage.foldername(name))[1] = public.get_current_user_org_id()::text
  );

-- 3. DELETE: tenant-scoped USING
-- ============================================================
DROP POLICY IF EXISTS "org_assets_delete" ON storage.objects;

CREATE POLICY "org_assets_delete"
  ON storage.objects FOR DELETE TO authenticated
  USING (
    bucket_id = 'organization_assets'
    AND (storage.foldername(name))[1] = public.get_current_user_org_id()::text
  );

-- ============================================================
-- BURHAN PLATFORM — Migration 00013
-- Align organization_assets bucket config with the app contract
--
-- Established contract (00005 + SUPABASE.md):
--   * max file size : 5 MB (5242880 bytes)
--   * allowed MIME  : image/jpeg, image/png, image/webp
--
-- GIF note: 00005 / SUPABASE.md list image/gif, but the application
-- never uploads a GIF. app/utils/compressImage.ts always transcodes
-- the selected file to image/webp before upload (all four callers in
-- app/pages/dashboard/{entities,series}/), so GIF never reaches the
-- bucket. This repair does not add a format the application cannot
-- produce; the effective contract excludes GIF.
--
-- Live drift corrected here:
--   * file_size_limit was 2097152 (2 MB) instead of 5242880 (5 MB)
--   * allowed_mime_types already matched the effective set (no GIF)
--
-- Additive + idempotent. Does not touch any other storage setting.
-- ============================================================

UPDATE storage.buckets
SET file_size_limit    = 5242880,
    allowed_mime_types = ARRAY['image/jpeg', 'image/png', 'image/webp']
WHERE id = 'organization_assets';

-- ============================================================
-- BURHAN PLATFORM — Migration 00014
-- Restore entities.content_type CHECK constraint
--
-- 00007 declared:
--   CHECK (content_type IN ('video', 'article', 'audio'))
-- but the live database does not enforce it (invalid values such as
-- 'bogus' were accepted during M1.6). This restores the exact
-- repository contract without redesigning the content model.
--
-- Additive + idempotent. No valid values are changed.
-- ============================================================

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conrelid = 'public.entities'::regclass
      AND conname  = 'entities_content_type_check'
  ) THEN
    ALTER TABLE public.entities
      ADD CONSTRAINT entities_content_type_check
      CHECK (content_type IN ('video', 'article', 'audio'));
  END IF;
END $$;-- ============================================================
-- BURHAN PLATFORM — Migration 00015
-- Subscription Foundation & Commercial Entitlement Layer
--
-- Architecture:
--   Organization -> Subscription -> Plan -> Entitlements/Limits
--
-- Principles:
--   1. Unified self-hosted & SaaS model (perpetual community plan)
--   2. Database RLS validates subscription validity only (is_org_subscription_active)
--   3. Content preservation: expired orgs retain public reads and DELETE sovereignty
--   4. M1 DeAI backend contract remains 100% locked & untouched
-- ============================================================

-- 1. PLANS TABLE
-- ============================================================
CREATE TABLE IF NOT EXISTS plans (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  slug           TEXT UNIQUE NOT NULL,
  name           JSONB NOT NULL,
  description    JSONB NOT NULL DEFAULT '{}'::jsonb,
  is_active      BOOLEAN NOT NULL DEFAULT true,
  price_monthly  NUMERIC(10,2) NOT NULL DEFAULT 0.00,
  price_yearly   NUMERIC(10,2) NOT NULL DEFAULT 0.00,
  currency       TEXT NOT NULL DEFAULT 'USD',
  features       JSONB NOT NULL DEFAULT '{}'::jsonb,
  limits         JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE  plans IS 'Commercial & community service tiers. Limits canonical -1 = unlimited.';
CREATE INDEX IF NOT EXISTS idx_plans_slug ON plans (slug);

-- 2. SUBSCRIPTIONS TABLE
-- ============================================================
CREATE TABLE IF NOT EXISTS subscriptions (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id  UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  plan_id          UUID NOT NULL REFERENCES plans(id) ON DELETE RESTRICT,
  status           TEXT NOT NULL DEFAULT 'active'
                   CHECK (status IN ('active', 'expired', 'cancelled')),
  billing_period   TEXT NOT NULL DEFAULT 'monthly'
                   CHECK (billing_period IN ('monthly', 'yearly')),
  starts_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  expires_at       TIMESTAMPTZ,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE  subscriptions IS 'Organization subscription records. Exactly one active subscription per organization.';
CREATE INDEX IF NOT EXISTS idx_subscriptions_org_id ON subscriptions (organization_id);
CREATE INDEX IF NOT EXISTS idx_subscriptions_plan_id ON subscriptions (plan_id);

-- Enforce exactly one active subscription per organization
CREATE UNIQUE INDEX IF NOT EXISTS idx_subscriptions_one_active_per_org
  ON subscriptions (organization_id)
  WHERE status = 'active';

-- 3. HELPER FUNCTION: is_org_subscription_active
-- ============================================================
CREATE OR REPLACE FUNCTION public.is_org_subscription_active(p_org_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM subscriptions
    WHERE organization_id = p_org_id
      AND status = 'active'
      AND (expires_at IS NULL OR expires_at > now())
  );
$$;

REVOKE EXECUTE ON FUNCTION public.is_org_subscription_active(UUID) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.is_org_subscription_active(UUID) TO authenticated, service_role;

-- 4. RLS ON PLANS & SUBSCRIPTIONS
-- ============================================================
ALTER TABLE plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE subscriptions ENABLE ROW LEVEL SECURITY;

-- Plans: readable by authenticated users (and anon sees active plans)
DROP POLICY IF EXISTS "plans_select_authenticated" ON plans;
CREATE POLICY "plans_select_authenticated"
  ON plans FOR SELECT TO authenticated
  USING (true);

DROP POLICY IF EXISTS "plans_select_anon" ON plans;
CREATE POLICY "plans_select_anon"
  ON plans FOR SELECT TO anon
  USING (is_active = true);

-- Subscriptions: members read own org subscription; super_admin reads all
DROP POLICY IF EXISTS "subscriptions_select_org_members" ON subscriptions;
CREATE POLICY "subscriptions_select_org_members"
  ON subscriptions FOR SELECT TO authenticated
  USING (
    organization_id = public.get_current_user_org_id()
    OR
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'super_admin')
  );

-- 5. RLS MUTATION GATES (ENTITIES, BRANCHES, SERIES, STORAGE)
-- ============================================================

-- 5a. entities INSERT
DROP POLICY IF EXISTS "entities_insert_org_staff" ON entities;
CREATE POLICY "entities_insert_org_staff"
  ON entities FOR INSERT TO authenticated
  WITH CHECK (
    (
      EXISTS (
        SELECT 1 FROM profiles
        WHERE id = auth.uid()
          AND organization_id = entities.organization_id
          AND role IN ('owner', 'manager')
      )
      OR
      EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'super_admin')
    )
    AND public.is_org_subscription_active(entities.organization_id)
  );

-- 5b. entities UPDATE
DROP POLICY IF EXISTS "entities_update_org_staff" ON entities;
CREATE POLICY "entities_update_org_staff"
  ON entities FOR UPDATE TO authenticated
  USING (
    (
      EXISTS (
        SELECT 1 FROM profiles
        WHERE id = auth.uid()
          AND organization_id = entities.organization_id
          AND role IN ('owner', 'manager')
      )
      OR
      EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'super_admin')
    )
    AND public.is_org_subscription_active(entities.organization_id)
  )
  WITH CHECK (
    (
      EXISTS (
        SELECT 1 FROM profiles
        WHERE id = auth.uid()
          AND organization_id = entities.organization_id
          AND role IN ('owner', 'manager')
      )
      OR
      EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'super_admin')
    )
    AND public.is_org_subscription_active(entities.organization_id)
  );

-- 5c. branches INSERT
DROP POLICY IF EXISTS "branches_insert_org_owner_or_manager" ON branches;
CREATE POLICY "branches_insert_org_owner_or_manager"
  ON branches FOR INSERT TO authenticated
  WITH CHECK (
    (
      EXISTS (
        SELECT 1 FROM profiles
        WHERE id = auth.uid()
          AND organization_id = branches.organization_id
          AND role IN ('owner', 'manager')
      )
      OR
      EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'super_admin')
    )
    AND public.is_org_subscription_active(branches.organization_id)
  );

-- 5d. branches UPDATE
DROP POLICY IF EXISTS "branches_update_org_owner_or_manager" ON branches;
CREATE POLICY "branches_update_org_owner_or_manager"
  ON branches FOR UPDATE TO authenticated
  USING (
    (
      EXISTS (
        SELECT 1 FROM profiles
        WHERE id = auth.uid()
          AND organization_id = branches.organization_id
          AND role IN ('owner', 'manager')
      )
      OR
      EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'super_admin')
    )
    AND public.is_org_subscription_active(branches.organization_id)
  )
  WITH CHECK (
    (
      EXISTS (
        SELECT 1 FROM profiles
        WHERE id = auth.uid()
          AND organization_id = branches.organization_id
          AND role IN ('owner', 'manager')
      )
      OR
      EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'super_admin')
    )
    AND public.is_org_subscription_active(branches.organization_id)
  );

-- 5e. series INSERT
DROP POLICY IF EXISTS "series_insert_org" ON series;
CREATE POLICY "series_insert_org"
  ON series FOR INSERT TO authenticated
  WITH CHECK (
    (
      EXISTS (
        SELECT 1 FROM profiles
        WHERE id = auth.uid()
          AND organization_id = series.organization_id
          AND role IN ('owner', 'manager')
      )
      OR
      EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'super_admin')
    )
    AND public.is_org_subscription_active(series.organization_id)
  );

-- 5f. series UPDATE
DROP POLICY IF EXISTS "series_update_org" ON series;
CREATE POLICY "series_update_org"
  ON series FOR UPDATE TO authenticated
  USING (
    (
      EXISTS (
        SELECT 1 FROM profiles
        WHERE id = auth.uid()
          AND organization_id = series.organization_id
          AND role IN ('owner', 'manager')
      )
      OR
      EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'super_admin')
    )
    AND public.is_org_subscription_active(series.organization_id)
  )
  WITH CHECK (
    (
      EXISTS (
        SELECT 1 FROM profiles
        WHERE id = auth.uid()
          AND organization_id = series.organization_id
          AND role IN ('owner', 'manager')
      )
      OR
      EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'super_admin')
    )
    AND public.is_org_subscription_active(series.organization_id)
  );

-- 5g. storage.objects INSERT (Organization Assets)
DROP POLICY IF EXISTS "org_assets_insert" ON storage.objects;
CREATE POLICY "org_assets_insert"
  ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'organization_assets'
    AND (storage.foldername(name))[1] = public.get_current_user_org_id()::text
    AND public.is_org_subscription_active(public.get_current_user_org_id())
  );

-- 6. DEFAULT PLANS SEED DATA
-- ============================================================
INSERT INTO plans (slug, name, description, is_active, price_monthly, price_yearly, currency, features, limits)
VALUES
  (
    'community',
    '{"ar": "مجتمعية (مفتوحة)", "en": "Community (Open)"}'::jsonb,
    '{"ar": "خطة الاستضافة الذاتية المفتوحة الدائمة", "en": "Perpetual self-hosted open-source plan"}'::jsonb,
    true,
    0.00,
    0.00,
    'USD',
    '{"ai_generate": true, "premium_content": true, "custom_branding": true, "audio_podcasts": true}'::jsonb,
    '{"monthly_ai_requests": -1, "monthly_ai_tokens": -1, "max_branches": -1}'::jsonb
  ),
  (
    'pro',
    '{"ar": "احترافية", "en": "Professional"}'::jsonb,
    '{"ar": "خطة العمل السحابية الاحترافية", "en": "Professional commercial SaaS plan"}'::jsonb,
    true,
    29.00,
    290.00,
    'USD',
    '{"ai_generate": true, "premium_content": true, "custom_branding": true, "audio_podcasts": true}'::jsonb,
    '{"monthly_ai_requests": 250, "monthly_ai_tokens": 2000000, "max_branches": 5}'::jsonb
  )
ON CONFLICT (slug) DO NOTHING;

-- 7. BACKFILL EXISTING ORGANIZATIONS WITH PERPETUAL COMMUNITY SUBSCRIPTION
-- ============================================================
INSERT INTO subscriptions (organization_id, plan_id, status, billing_period, starts_at, expires_at)
SELECT
  o.id,
  p.id,
  'active',
  'yearly',
  now(),
  NULL
FROM organizations o
CROSS JOIN (SELECT id FROM plans WHERE slug = 'community' LIMIT 1) p
WHERE NOT EXISTS (
  SELECT 1 FROM subscriptions s
  WHERE s.organization_id = o.id
    AND s.status = 'active'
)
ON CONFLICT DO NOTHING;

-- ============================================================
-- BURHAN PLATFORM — Migration 00016
-- Atomic Enforcement for max_branches Quota
-- ============================================================

-- 1. Create the enforcement function
CREATE OR REPLACE FUNCTION public.check_branch_limit()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_raw_limit text;
  v_limit     integer;
  v_count     bigint;
BEGIN
  PERFORM 1
  FROM public.organizations
  WHERE id = NEW.organization_id
  FOR NO KEY UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'branch_organization_invalid: organization does not exist'
      USING ERRCODE = 'check_violation';
  END IF;

  SELECT p.limits->>'max_branches'
  INTO v_raw_limit
  FROM public.subscriptions s
  JOIN public.plans p ON p.id = s.plan_id
  WHERE s.organization_id = NEW.organization_id
    AND s.status = 'active'
    AND (s.expires_at IS NULL OR s.expires_at > now())
  LIMIT 1;

  IF v_raw_limit IS NULL AND NOT EXISTS (
    SELECT 1
    FROM public.subscriptions s
    WHERE s.organization_id = NEW.organization_id
      AND s.status = 'active'
      AND (s.expires_at IS NULL OR s.expires_at > now())
  ) THEN
    RAISE EXCEPTION 'branch_subscription_invalid: no active subscription found for organization'
      USING ERRCODE = 'check_violation';
  END IF;

  IF v_raw_limit IS NULL THEN
    RAISE EXCEPTION 'branch_limit_invalid: plan limits missing max_branches value'
      USING ERRCODE = 'check_violation';
  ELSIF v_raw_limit = '-1' THEN
    v_limit := -1;
  ELSIF v_raw_limit ~ '^[0-9]{1,10}$' AND v_raw_limit::bigint <= 2147483647 THEN
    v_limit := v_raw_limit::integer;
  ELSE
    RAISE EXCEPTION 'branch_limit_invalid: plan max_branches must be -1 or an integer between 0 and 2147483647'
      USING ERRCODE = 'check_violation';
  END IF;

  IF v_limit = -1 THEN
    RETURN NEW;
  END IF;

  SELECT count(*)
  INTO v_count
  FROM public.branches
  WHERE organization_id = NEW.organization_id;

  IF v_count >= v_limit THEN
    RAISE EXCEPTION 'branch_limit_exceeded: organization has reached its branch limit of %', v_limit
      USING ERRCODE = 'check_violation';
  END IF;

  RETURN NEW;
END;
$$;

-- 2. Privileges Configuration
REVOKE ALL ON FUNCTION public.check_branch_limit() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.check_branch_limit() FROM authenticated;
REVOKE ALL ON FUNCTION public.check_branch_limit() FROM service_role;
REVOKE ALL ON FUNCTION public.check_branch_limit() FROM anon;

-- 3. Attach BEFORE INSERT Trigger
DROP TRIGGER IF EXISTS trg_enforce_branch_limit ON public.branches;

CREATE TRIGGER trg_enforce_branch_limit
  BEFORE INSERT ON public.branches
  FOR EACH ROW
  EXECUTE FUNCTION public.check_branch_limit();

COMMENT ON FUNCTION public.check_branch_limit() IS
  'Enforces atomic max_branches quota on branch creation via parent organization row locking.';


-- ============================================================
-- BURHAN PLATFORM — Migration 00017
-- Membership Security, Self-Assignment Prevention, and Destination Subscription Gate
-- ============================================================

-- 1. Tighten RLS Policies on profiles
DROP POLICY IF EXISTS "profiles_update_own" ON public.profiles;

CREATE POLICY "profiles_update_own"
  ON public.profiles FOR UPDATE TO authenticated
  USING (id = auth.uid())
  WITH CHECK (
    id = auth.uid()
    AND (
      public.get_current_user_role() = 'super_admin'
      OR (
        role = public.get_current_user_role()
        AND organization_id IS NOT DISTINCT FROM public.get_current_user_org_id()
      )
    )
  );

DROP POLICY IF EXISTS "profiles_update_org_staff" ON public.profiles;

CREATE POLICY "profiles_update_org_staff"
  ON public.profiles FOR UPDATE TO authenticated
  USING (
    (
      public.get_current_user_role() = 'owner'
      AND organization_id = public.get_current_user_org_id()
    )
    OR public.get_current_user_role() = 'super_admin'
  )
  WITH CHECK (
    public.get_current_user_role() = 'super_admin'
    OR (
      public.get_current_user_role() = 'owner'
      AND organization_id = public.get_current_user_org_id()
      AND role IN ('owner', 'manager', 'member')
    )
  );

-- 2. Enforcement Function: enforce_profile_security
CREATE OR REPLACE FUNCTION public.enforce_profile_security()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_is_service_role boolean;
  v_caller_role     public.user_role;
  v_caller_org_id   uuid;
  v_caller_id       uuid;
BEGIN
  v_is_service_role := (
    current_user IN ('service_role', 'postgres', 'supabase_admin')
    OR session_user IN ('postgres', 'burhan')
    OR COALESCE(
         nullif(current_setting('request.jwt.claim.role', true), ''),
         (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'role')
       ) = 'service_role'
  );

  IF NEW.organization_id IS NOT NULL 
     AND (OLD.organization_id IS NULL OR OLD.organization_id IS DISTINCT FROM NEW.organization_id) THEN
    IF NOT public.is_org_subscription_active(NEW.organization_id) THEN
      RAISE EXCEPTION 'member_subscription_invalid: destination organization has no active subscription'
        USING ERRCODE = 'check_violation';
    END IF;
  END IF;

  IF v_is_service_role THEN
    RETURN NEW;
  END IF;

  v_caller_id     := auth.uid();
  v_caller_role   := public.get_current_user_role();
  v_caller_org_id := public.get_current_user_org_id();

  IF v_caller_role = 'super_admin' THEN
    RETURN NEW;
  END IF;

  IF v_caller_id IS NOT NULL AND v_caller_id = NEW.id THEN
    IF NEW.organization_id IS DISTINCT FROM OLD.organization_id THEN
      RAISE EXCEPTION 'profile_org_immutable: users cannot modify their own organization'
        USING ERRCODE = 'check_violation';
    END IF;

    IF NEW.role IS DISTINCT FROM OLD.role THEN
      RAISE EXCEPTION 'profile_role_immutable: users cannot modify their own role'
        USING ERRCODE = 'check_violation';
    END IF;

    RETURN NEW;
  END IF;

  IF v_caller_role = 'owner' THEN
    IF NEW.organization_id IS DISTINCT FROM OLD.organization_id THEN
      RAISE EXCEPTION 'member_org_immutable: owners cannot reassign organization membership'
        USING ERRCODE = 'check_violation';
    END IF;

    IF OLD.organization_id IS DISTINCT FROM v_caller_org_id THEN
      RAISE EXCEPTION 'member_unauthorized: owner can only manage staff of their own organization'
        USING ERRCODE = 'check_violation';
    END IF;

    IF NEW.role = 'super_admin' AND OLD.role IS DISTINCT FROM 'super_admin' THEN
      RAISE EXCEPTION 'member_role_invalid: owners cannot grant super_admin role'
        USING ERRCODE = 'check_violation';
    END IF;

    RETURN NEW;
  END IF;

  RAISE EXCEPTION 'profile_unauthorized: unauthorized profile modification'
    USING ERRCODE = 'check_violation';

END;
$$;

-- 3. Privileges Configuration
REVOKE ALL ON FUNCTION public.enforce_profile_security() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.enforce_profile_security() FROM authenticated;
REVOKE ALL ON FUNCTION public.enforce_profile_security() FROM service_role;
REVOKE ALL ON FUNCTION public.enforce_profile_security() FROM anon;

-- 4. Attach BEFORE UPDATE Trigger
DROP TRIGGER IF EXISTS trg_enforce_profile_security ON public.profiles;

CREATE TRIGGER trg_enforce_profile_security
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.enforce_profile_security();

COMMENT ON FUNCTION public.enforce_profile_security() IS
  'Enforces membership integrity, self-escalation prevention, and destination subscription validity.';
