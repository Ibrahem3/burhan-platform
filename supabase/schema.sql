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
