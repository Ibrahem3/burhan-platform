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
