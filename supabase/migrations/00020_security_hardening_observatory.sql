-- ============================================================
-- BURHAN PLATFORM — Migration 00020
-- Security Hardening: Observatory Module & Trigger Isolation
--
-- Scope:
--   1. auto_detect_platform: Fix mutable search_path (Trigger logic untouched)
--   2. Drop obsolete permissive public insert policy on observatory_threats
--   3. Revoke public/anon execute on Observatory administrative helpers
--   4. Scope analyst management policies explicitly to authenticated users
--
-- IMMUTABLE CORE (STRICTLY UNTOUCHED):
--   - public.get_current_user_org_id()
--   - public.get_current_user_role()
--   - public.is_org_subscription_active(uuid)
-- ============================================================

-- 1. auto_detect_platform: Fix mutable search_path
CREATE OR REPLACE FUNCTION public.auto_detect_platform()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
BEGIN
  NEW.platform := CASE 
    WHEN NEW.source_url ~* 'tiktok\.com' THEN 'tiktok'
    WHEN NEW.source_url ~* 'youtube\.com' THEN 'youtube'
    WHEN NEW.source_url ~* 'youtu\.be' THEN 'youtube'
    WHEN NEW.source_url ~* 'facebook\.com' THEN 'facebook'
    WHEN NEW.source_url ~* 'x\.com' THEN 'x'
    WHEN NEW.source_url ~* 'twitter\.com' THEN 'x'
    WHEN NEW.source_url ~* 'instagram\.com' THEN 'instagram'
    WHEN NEW.source_url ~* 'telegram\.me' THEN 'telegram'
    WHEN NEW.source_url ~* 't\.me' THEN 'telegram'
    ELSE 'other'
  END;
  RETURN NEW;
END;
$$;

-- 2. Remove obsolete permissive public insert policy
DROP POLICY IF EXISTS "threats_insert_public" ON public.observatory_threats;

-- 3. Revoke public/anon execute on Observatory administrative helpers
REVOKE EXECUTE ON FUNCTION public.is_observatory_manager() FROM public, anon;
GRANT EXECUTE ON FUNCTION public.is_observatory_manager() TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public.is_super_admin() FROM public, anon;
GRANT EXECUTE ON FUNCTION public.is_super_admin() TO authenticated, service_role;

-- 4. Scope analyst management policies explicitly to authenticated users
DROP POLICY IF EXISTS "analysts_select_all_manager_or_super_admin" ON public.observatory_analysts;
CREATE POLICY "analysts_select_all_manager_or_super_admin"
  ON public.observatory_analysts FOR SELECT TO authenticated
  USING (is_observatory_manager() OR is_super_admin());

DROP POLICY IF EXISTS "analysts_insert_manager_only" ON public.observatory_analysts;
CREATE POLICY "analysts_insert_manager_only"
  ON public.observatory_analysts FOR INSERT TO authenticated
  WITH CHECK (is_observatory_manager() OR is_super_admin());

DROP POLICY IF EXISTS "analysts_delete_manager_only" ON public.observatory_analysts;
CREATE POLICY "analysts_delete_manager_only"
  ON public.observatory_analysts FOR DELETE TO authenticated
  USING (is_observatory_manager() OR is_super_admin());
