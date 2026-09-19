-- ============================================================
-- BURHAN PLATFORM — Migration 00021
-- Fix: Restore Public Series Read for Authenticated Users
--
-- Problem:
--   Migration 00006 created `series_select_public` scoped strictly `TO anon`.
--   Consequently, any authenticated user browsing an organization they do not
--   belong to was denied access to published public series (is_active = true)
--   because `series_select_org` only permits members of their own organization.
--
-- Solution:
--   Re-create `series_select_public` targeting `anon, authenticated` with
--   `USING (is_active = true)`.
--   - Unauthenticated visitors and authenticated cross-tenant visitors can see active series.
--   - Inactive/draft series remain strictly protected by `series_select_org` (own members/super_admin).
-- ============================================================

DROP POLICY IF EXISTS "series_select_public" ON public.series;

CREATE POLICY "series_select_public"
  ON public.series FOR SELECT TO anon, authenticated
  USING (is_active = true);
