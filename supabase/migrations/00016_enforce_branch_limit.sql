-- ============================================================
-- BURHAN PLATFORM — Migration 00016
-- Atomic Enforcement for max_branches Quota
--
-- Scope:
--   Enforce organization branch limit (plans.limits ->> 'max_branches')
--   atomically under concurrent requests using parent organization
--   row-level locking.
--
-- Established Invariants:
--   1. max_branches counts all branch rows for the organization (including 'main').
--   2. Inactive branches (is_active = false) remain counted against quota.
--   3. Deleted branches (DELETE) release quota slots upon commit.
--   4. Canonical unlimited (-1) bypasses count calculation.
--   5. Parent organization row lock (FOR NO KEY UPDATE) guarantees serialization
--      without cross-tenant hash collisions and avoids conflict with FOR KEY SHARE FK checks.
--   6. Strict input parsing prevents integer-out-of-range or cast syntax exceptions.
--   7. Fail-closed on missing active subscription, missing organization, or malformed limits.
--   8. Standard database SQLSTATE 23514 (check_violation) for all constraint rejections.
-- ============================================================

-- 1. Create the enforcement function
-- ============================================================
CREATE OR REPLACE FUNCTION public.check_branch_limit()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_raw_limit text;
  v_limit     integer;
  v_count     bigint;
BEGIN
  -- 1. Parent Organization Row-Level Lock
  --    Acquires a transaction-scoped FOR NO KEY UPDATE lock on the parent organization.
  --    Serializes concurrent branch creations for this specific tenant while
  --    avoiding conflict with concurrent child foreign-key checks (FOR KEY SHARE).
  PERFORM 1
  FROM public.organizations
  WHERE id = NEW.organization_id
  FOR NO KEY UPDATE;

  -- Fail-closed if organization record does not exist
  IF NOT FOUND THEN
    RAISE EXCEPTION 'branch_organization_invalid: organization does not exist'
      USING ERRCODE = 'check_violation';
  END IF;

  -- 2. Resolve active subscription plan limit
  SELECT p.limits->>'max_branches'
  INTO v_raw_limit
  FROM public.subscriptions s
  JOIN public.plans p ON p.id = s.plan_id
  WHERE s.organization_id = NEW.organization_id
    AND s.status = 'active'
    AND (s.expires_at IS NULL OR s.expires_at > now())
  LIMIT 1;

  -- 3. Fail-closed if active subscription is missing
  IF v_raw_limit IS NULL AND NOT EXISTS (
    SELECT 1
    FROM public.subscriptions s
    WHERE s.organization_id = NEW.organization_id
      AND s.status = 'active'
      AND (s.expires_at IS NULL OR s.expires_at > now())
  ) THEN
    RAISE EXCEPTION 'branch_subscription_invalid: no active subscription found for organization'
      USING ERRCODE = 'check_violation';
  END IF;

  -- 4. Safe Integer Parsing & Validation
  --    Accepts ONLY:
  --      -1 (canonical unlimited)
  --      0 .. 2147483647 (valid non-negative 32-bit signed integer)
  --    Rejects null, missing, non-numeric, decimal, negative (< -1), or overflow (> 2147483647)
  --    without triggering an unhandled PostgreSQL cast exception.
  IF v_raw_limit IS NULL THEN
    RAISE EXCEPTION 'branch_limit_invalid: plan limits missing max_branches value'
      USING ERRCODE = 'check_violation';
  ELSIF v_raw_limit = '-1' THEN
    v_limit := -1;
  ELSIF v_raw_limit ~ '^[0-9]{1,10}$' AND v_raw_limit::bigint <= 2147483647 THEN
    v_limit := v_raw_limit::integer;
  ELSE
    RAISE EXCEPTION 'branch_limit_invalid: plan max_branches must be -1 or an integer between 0 and 2147483647'
      USING ERRCODE = 'check_violation';
  END IF;

  -- 5. Canonical Unlimited (-1): bypass branch count check
  IF v_limit = -1 THEN
    RETURN NEW;
  END IF;

  -- 6. Count total existing branches for this organization
  --    Includes 'main' and inactive branches (is_active = false)
  SELECT count(*)
  INTO v_count
  FROM public.branches
  WHERE organization_id = NEW.organization_id;

  -- 7. Quota boundary evaluation
  --    Trigger runs BEFORE INSERT, so v_count represents existing rows prior to NEW.
  IF v_count >= v_limit THEN
    RAISE EXCEPTION 'branch_limit_exceeded: organization has reached its branch limit of %', v_limit
      USING ERRCODE = 'check_violation';
  END IF;

  RETURN NEW;
END;
$$;

-- 2. Privileges Configuration
-- ============================================================
-- Function is strictly an internal trigger routine, not a public callable RPC.
REVOKE ALL ON FUNCTION public.check_branch_limit() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.check_branch_limit() FROM authenticated;
REVOKE ALL ON FUNCTION public.check_branch_limit() FROM service_role;
REVOKE ALL ON FUNCTION public.check_branch_limit() FROM anon;

-- 3. Attach BEFORE INSERT Trigger
-- ============================================================
DROP TRIGGER IF EXISTS trg_enforce_branch_limit ON public.branches;

CREATE TRIGGER trg_enforce_branch_limit
  BEFORE INSERT ON public.branches
  FOR EACH ROW
  EXECUTE FUNCTION public.check_branch_limit();

COMMENT ON FUNCTION public.check_branch_limit() IS
  'Enforces atomic max_branches quota on branch creation via parent organization row locking.';
