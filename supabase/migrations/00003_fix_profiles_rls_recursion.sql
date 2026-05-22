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
