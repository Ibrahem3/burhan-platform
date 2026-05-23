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
