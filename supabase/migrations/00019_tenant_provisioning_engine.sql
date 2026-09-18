-- ============================================================
-- BURHAN PLATFORM — Migration 00019
-- Atomic Tenant Provisioning Engine (Transactional RPC)
--
-- Scope:
--   1. Replaces legacy multi-step non-atomic tenant registration with
--      a single atomic PostgreSQL function.
--   2. Ensures full rollback if any pillar fails (organization, subscription,
--      main branch, or profile ownership).
--   3. Enforces strict idempotency and concurrency locking on the user profile row.
--   4. Eliminates TOCTOU slug races by relying directly on the organizations.org_slug
--      UNIQUE constraint and mapping collisions precisely.
--   5. Fully integrates with Migration 00015 (Subscription Foundation),
--      00016 (Branch Limits), and 00017 (Membership Security).
--   6. Hardens execution privileges: service_role ONLY.
-- ============================================================

-- 1. Create the atomic provisioning function
-- ============================================================
CREATE OR REPLACE FUNCTION public.provision_tenant(
  p_user_id   UUID,
  p_org_name  TEXT,
  p_org_slug  TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_trimmed_slug     TEXT;
  v_trimmed_name     TEXT;
  v_profile          RECORD;
  v_existing_org     RECORD;
  v_existing_sub     RECORD;
  v_existing_branch  RECORD;
  v_community_plan   RECORD;
  v_new_org          RECORD;
  v_new_branch       RECORD;
BEGIN
  -- 1. Validate Input Parameters
  v_trimmed_slug := lower(trim(p_org_slug));
  v_trimmed_name := trim(p_org_name);

  IF p_user_id IS NULL THEN
    RAISE EXCEPTION 'invalid_payload: user id is required'
      USING ERRCODE = 'invalid_parameter_value';
  END IF;

  IF v_trimmed_name IS NULL OR length(v_trimmed_name) < 2 THEN
    RAISE EXCEPTION 'invalid_payload: organization name must be at least 2 characters'
      USING ERRCODE = 'invalid_parameter_value';
  END IF;

  IF v_trimmed_slug IS NULL OR length(v_trimmed_slug) < 2 OR v_trimmed_slug !~ '^[a-z0-9-]+$' THEN
    RAISE EXCEPTION 'invalid_payload: organization slug must be alphanumeric with hyphens (min 2 chars)'
      USING ERRCODE = 'invalid_parameter_value';
  END IF;

  -- 2. Concurrency Lock on User Profile
  --    Acquires an exclusive row-level lock on the profile row.
  --    Serializes concurrent provisioning attempts for the exact same user.
  SELECT id, organization_id, role
  INTO v_profile
  FROM public.profiles
  WHERE id = p_user_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'invalid_payload: user profile does not exist'
      USING ERRCODE = 'invalid_parameter_value';
  END IF;

  -- 3. Evaluate User Tenant State (Idempotency vs Multiple Tenant Prohibition)
  IF v_profile.organization_id IS NOT NULL THEN
    -- User already has an organization assignment.
    -- Check the 4 pillars of complete provisioning for this tenant.
    SELECT id, org_slug, name
    INTO v_existing_org
    FROM public.organizations
    WHERE id = v_profile.organization_id;

    -- Pillar 2: Active subscription (respecting 00015 semantics)
    SELECT id, status, plan_id
    INTO v_existing_sub
    FROM public.subscriptions
    WHERE organization_id = v_profile.organization_id
      AND status = 'active'
      AND (expires_at IS NULL OR expires_at > now())
    LIMIT 1;

    -- Pillar 3: Main branch
    SELECT id, slug, name
    INTO v_existing_branch
    FROM public.branches
    WHERE organization_id = v_profile.organization_id
      AND slug = 'main'
    LIMIT 1;

    -- Pillar 4: Profile role is owner
    IF v_existing_org.id IS NOT NULL
       AND v_existing_sub.id IS NOT NULL
       AND v_existing_branch.id IS NOT NULL
       AND v_profile.role = 'owner' THEN

      -- If the requested slug matches their existing organization slug: Idempotent return
      IF v_existing_org.org_slug = v_trimmed_slug THEN
        RETURN jsonb_build_object(
          'org', jsonb_build_object(
            'id', v_existing_org.id,
            'org_slug', v_existing_org.org_slug,
            'name', v_existing_org.name
          ),
          'branch', jsonb_build_object(
            'id', v_existing_branch.id,
            'slug', v_existing_branch.slug
          ),
          'is_existing', true
        );
      ELSE
        -- The user already owns an organization with a DIFFERENT slug.
        -- Per Burhan platform invariant: 1 user may only own 1 organization.
        RAISE EXCEPTION 'user_already_has_tenant: user already owns organization with slug %', v_existing_org.org_slug
          USING ERRCODE = 'unique_violation';
      END IF;
    ELSE
      -- State is incomplete/corrupted (linked org_id but missing pillars)
      RAISE EXCEPTION 'tenant_state_corrupted: organization exists but pillars are incomplete'
        USING ERRCODE = 'data_corrupted';
    END IF;
  END IF;

  -- 4. User is eligible for initial provisioning (profile.organization_id IS NULL)
  --    Resolve default community plan first (fail-closed if missing)
  SELECT id
  INTO v_community_plan
  FROM public.plans
  WHERE slug = 'community'
    AND is_active = true
  LIMIT 1;

  IF NOT FOUND OR v_community_plan.id IS NULL THEN
    RAISE EXCEPTION 'community_plan_missing: default community plan is not active in database'
      USING ERRCODE = 'data_exception';
  END IF;

  -- 5. Insert Organization
  --    Rely on the DB UNIQUE constraint on organizations.org_slug to eliminate race conditions.
  BEGIN
    INSERT INTO public.organizations (
      name,
      org_slug,
      settings
    )
    VALUES (
      v_trimmed_name,
      v_trimmed_slug,
      '{}'::jsonb
    )
    RETURNING id, org_slug, name INTO v_new_org;
  EXCEPTION
    WHEN unique_violation THEN
      -- Map uniquely to slug_already_taken
      RAISE EXCEPTION 'slug_already_taken: organization slug % is already registered', v_trimmed_slug
        USING ERRCODE = 'unique_violation';
  END;

  -- 6. Insert Perpetual Community Subscription
  INSERT INTO public.subscriptions (
    organization_id,
    plan_id,
    status,
    billing_period,
    starts_at,
    expires_at
  )
  VALUES (
    v_new_org.id,
    v_community_plan.id,
    'active',
    'yearly',
    now(),
    NULL
  );

  -- 7. Insert Initial Main Branch
  --    Triggers 00016 check_branch_limit naturally under service_role
  INSERT INTO public.branches (
    organization_id,
    name,
    slug,
    module_type
  )
  VALUES (
    v_new_org.id,
    jsonb_build_object('ar', 'الفرع الرئيسي', 'en', 'Main Branch'),
    'main',
    'content'
  )
  RETURNING id, slug INTO v_new_branch;

  -- 8. Assign User Profile to Organization as Owner
  --    Triggers 00017 enforce_profile_security naturally (active subscription gate passes)
  UPDATE public.profiles
  SET
    organization_id = v_new_org.id,
    role = 'owner'
  WHERE id = p_user_id;

  -- 9. Return Canonical Provisioning Payload
  RETURN jsonb_build_object(
    'org', jsonb_build_object(
      'id', v_new_org.id,
      'org_slug', v_new_org.org_slug,
      'name', v_new_org.name
    ),
    'branch', jsonb_build_object(
      'id', v_new_branch.id,
      'slug', v_new_branch.slug
    ),
    'is_existing', false
  );
END;
$$;

-- 2. Privileges & Security Hardening
-- ============================================================
-- The provisioning engine is strictly server-orchestrated via Nitro.
-- Web clients (anon and authenticated) are strictly forbidden from calling it.
REVOKE EXECUTE ON FUNCTION public.provision_tenant(UUID, TEXT, TEXT) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.provision_tenant(UUID, TEXT, TEXT) TO service_role;

COMMENT ON FUNCTION public.provision_tenant(UUID, TEXT, TEXT) IS
  'Atomic tenant provisioning: organization, community subscription, main branch, and owner profile update in a single transaction.';
