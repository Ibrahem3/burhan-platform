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
