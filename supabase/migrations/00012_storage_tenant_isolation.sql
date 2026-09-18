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
