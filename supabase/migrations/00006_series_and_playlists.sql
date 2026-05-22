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
