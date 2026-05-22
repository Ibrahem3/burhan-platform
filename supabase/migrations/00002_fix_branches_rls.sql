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
