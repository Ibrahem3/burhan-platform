-- ============================================================
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