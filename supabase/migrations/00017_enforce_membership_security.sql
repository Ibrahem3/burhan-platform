-- ============================================================
-- BURHAN PLATFORM — Migration 00017
-- Membership Security, Self-Assignment Prevention, and Destination Subscription Gate
--
-- Scope:
--   1. Tighten RLS policies on public.profiles to prevent self-assignment and privilege escalation.
--   2. Enforce database-level transition rules via a BEFORE UPDATE trigger on public.profiles.
--   3. Gate organization assignment/reassignment behind an active destination subscription (fail-closed).
--   4. Preserve legitimate profile editing (full_name), owner staff management, and super_admin authority.
--   5. Maintain seamless compatibility with trusted service_role bootstrap (register-tenant).
-- ============================================================

-- 1. Tighten RLS Policies on profiles
-- ============================================================

-- 1a. profiles_update_own: Allow users to edit their own profile, but restrict
--     organization_id and role changes at the RLS layer without causing recursion.
DROP POLICY IF EXISTS "profiles_update_own" ON public.profiles;

CREATE POLICY "profiles_update_own"
  ON public.profiles FOR UPDATE TO authenticated
  USING (id = auth.uid())
  WITH CHECK (
    id = auth.uid()
    AND (
      public.get_current_user_role() = 'super_admin'
      OR (
        role = public.get_current_user_role()
        AND organization_id IS NOT DISTINCT FROM public.get_current_user_org_id()
      )
    )
  );

-- 1b. profiles_update_org_staff: Allow owners to update staff in their own organization,
--     preventing cross-tenant reassignment or granting super_admin role.
DROP POLICY IF EXISTS "profiles_update_org_staff" ON public.profiles;

CREATE POLICY "profiles_update_org_staff"
  ON public.profiles FOR UPDATE TO authenticated
  USING (
    (
      public.get_current_user_role() = 'owner'
      AND organization_id = public.get_current_user_org_id()
    )
    OR public.get_current_user_role() = 'super_admin'
  )
  WITH CHECK (
    public.get_current_user_role() = 'super_admin'
    OR (
      public.get_current_user_role() = 'owner'
      AND organization_id = public.get_current_user_org_id()
      AND role IN ('owner', 'manager', 'member')
    )
  );

-- 2. Enforcement Function: enforce_profile_security
-- ============================================================
CREATE OR REPLACE FUNCTION public.enforce_profile_security()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_is_service_role boolean;
  v_caller_role     public.user_role;
  v_caller_org_id   uuid;
  v_caller_id       uuid;
BEGIN
  -- 1. Identify trusted backend / superuser context
  v_is_service_role := (
    current_user IN ('service_role', 'postgres', 'supabase_admin')
    OR session_user IN ('postgres', 'burhan')
    OR COALESCE(
         nullif(current_setting('request.jwt.claim.role', true), ''),
         (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'role')
       ) = 'service_role'
  );

  -- 2. Destination Subscription Gate
  --    Whenever a profile is assigned or reassigned to an organization,
  --    the destination organization MUST have an active subscription.
  --    This applies to all callers (including Super Admin and service_role).
  IF NEW.organization_id IS NOT NULL 
     AND (OLD.organization_id IS NULL OR OLD.organization_id IS DISTINCT FROM NEW.organization_id) THEN
    IF NOT public.is_org_subscription_active(NEW.organization_id) THEN
      RAISE EXCEPTION 'member_subscription_invalid: destination organization has no active subscription'
        USING ERRCODE = 'check_violation';
    END IF;
  END IF;

  -- 3. Trusted service_role bypass for remaining authorization checks (e.g. tenant registration bootstrap)
  IF v_is_service_role THEN
    RETURN NEW;
  END IF;

  -- 4. Resolve caller identity
  v_caller_id     := auth.uid();
  v_caller_role   := public.get_current_user_role();
  v_caller_org_id := public.get_current_user_org_id();

  -- 5. Super Admin authorization
  --    Super admin is permitted to reassign organizations and modify roles
  --    (destination subscription check was already enforced above).
  IF v_caller_role = 'super_admin' THEN
    RETURN NEW;
  END IF;

  -- 6. Self-update by profile owner (v_caller_id = NEW.id)
  IF v_caller_id IS NOT NULL AND v_caller_id = NEW.id THEN
    -- Prevent self-assignment or cross-tenant migration
    IF NEW.organization_id IS DISTINCT FROM OLD.organization_id THEN
      RAISE EXCEPTION 'profile_org_immutable: users cannot modify their own organization'
        USING ERRCODE = 'check_violation';
    END IF;

    -- Prevent self-escalation or role change
    IF NEW.role IS DISTINCT FROM OLD.role THEN
      RAISE EXCEPTION 'profile_role_immutable: users cannot modify their own role'
        USING ERRCODE = 'check_violation';
    END IF;

    -- Allowed: updating full_name and other ordinary profile fields
    RETURN NEW;
  END IF;

  -- 7. Organization Owner managing staff (v_caller_role = 'owner')
  IF v_caller_role = 'owner' THEN
    -- Owner cannot reassign user's organization
    IF NEW.organization_id IS DISTINCT FROM OLD.organization_id THEN
      RAISE EXCEPTION 'member_org_immutable: owners cannot reassign organization membership'
        USING ERRCODE = 'check_violation';
    END IF;

    -- Target user must already belong to the owner's organization
    IF OLD.organization_id IS DISTINCT FROM v_caller_org_id THEN
      RAISE EXCEPTION 'member_unauthorized: owner can only manage staff of their own organization'
        USING ERRCODE = 'check_violation';
    END IF;

    -- Owner cannot grant super_admin role
    IF NEW.role = 'super_admin' AND OLD.role IS DISTINCT FROM 'super_admin' THEN
      RAISE EXCEPTION 'member_role_invalid: owners cannot grant super_admin role'
        USING ERRCODE = 'check_violation';
    END IF;

    -- Allowed: role updates within the same organization (member <-> manager <-> owner)
    RETURN NEW;
  END IF;

  -- 8. Fallback reject for any unauthorized mutation
  RAISE EXCEPTION 'profile_unauthorized: unauthorized profile modification'
    USING ERRCODE = 'check_violation';

END;
$$;

-- 3. Privileges Configuration
-- ============================================================
-- Function is strictly an internal trigger routine, not a public callable RPC.
REVOKE ALL ON FUNCTION public.enforce_profile_security() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.enforce_profile_security() FROM authenticated;
REVOKE ALL ON FUNCTION public.enforce_profile_security() FROM service_role;
REVOKE ALL ON FUNCTION public.enforce_profile_security() FROM anon;

-- 4. Attach BEFORE UPDATE Trigger
-- ============================================================
DROP TRIGGER IF EXISTS trg_enforce_profile_security ON public.profiles;

CREATE TRIGGER trg_enforce_profile_security
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.enforce_profile_security();

COMMENT ON FUNCTION public.enforce_profile_security() IS
  'Enforces membership integrity, self-escalation prevention, and destination subscription validity.';
