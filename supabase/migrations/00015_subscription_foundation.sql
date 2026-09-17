-- ============================================================
-- BURHAN PLATFORM — Migration 00015
-- Subscription Foundation & Commercial Entitlement Layer
--
-- Architecture:
--   Organization -> Subscription -> Plan -> Entitlements/Limits
--
-- Principles:
--   1. Unified self-hosted & SaaS model (perpetual community plan)
--   2. Database RLS validates subscription validity only (is_org_subscription_active)
--   3. Content preservation: expired orgs retain public reads and DELETE sovereignty
--   4. M1 DeAI backend contract remains 100% locked & untouched
-- ============================================================

-- 1. PLANS TABLE
-- ============================================================
CREATE TABLE IF NOT EXISTS plans (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  slug           TEXT UNIQUE NOT NULL,
  name           JSONB NOT NULL,
  description    JSONB NOT NULL DEFAULT '{}'::jsonb,
  is_active      BOOLEAN NOT NULL DEFAULT true,
  price_monthly  NUMERIC(10,2) NOT NULL DEFAULT 0.00,
  price_yearly   NUMERIC(10,2) NOT NULL DEFAULT 0.00,
  currency       TEXT NOT NULL DEFAULT 'USD',
  features       JSONB NOT NULL DEFAULT '{}'::jsonb,
  limits         JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE  plans IS 'Commercial & community service tiers. Limits canonical -1 = unlimited.';
CREATE INDEX IF NOT EXISTS idx_plans_slug ON plans (slug);

-- 2. SUBSCRIPTIONS TABLE
-- ============================================================
CREATE TABLE IF NOT EXISTS subscriptions (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id  UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  plan_id          UUID NOT NULL REFERENCES plans(id) ON DELETE RESTRICT,
  status           TEXT NOT NULL DEFAULT 'active'
                   CHECK (status IN ('active', 'expired', 'cancelled')),
  billing_period   TEXT NOT NULL DEFAULT 'monthly'
                   CHECK (billing_period IN ('monthly', 'yearly')),
  starts_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  expires_at       TIMESTAMPTZ,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE  subscriptions IS 'Organization subscription records. Exactly one active subscription per organization.';
CREATE INDEX IF NOT EXISTS idx_subscriptions_org_id ON subscriptions (organization_id);
CREATE INDEX IF NOT EXISTS idx_subscriptions_plan_id ON subscriptions (plan_id);

-- Enforce exactly one active subscription per organization
CREATE UNIQUE INDEX IF NOT EXISTS idx_subscriptions_one_active_per_org
  ON subscriptions (organization_id)
  WHERE status = 'active';

-- 3. HELPER FUNCTION: is_org_subscription_active
-- ============================================================
CREATE OR REPLACE FUNCTION public.is_org_subscription_active(p_org_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM subscriptions
    WHERE organization_id = p_org_id
      AND status = 'active'
      AND (expires_at IS NULL OR expires_at > now())
  );
$$;

REVOKE EXECUTE ON FUNCTION public.is_org_subscription_active(UUID) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.is_org_subscription_active(UUID) TO authenticated, service_role;

-- 4. RLS ON PLANS & SUBSCRIPTIONS
-- ============================================================
ALTER TABLE plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE subscriptions ENABLE ROW LEVEL SECURITY;

-- Plans: readable by authenticated users (and anon sees active plans)
DROP POLICY IF EXISTS "plans_select_authenticated" ON plans;
CREATE POLICY "plans_select_authenticated"
  ON plans FOR SELECT TO authenticated
  USING (true);

DROP POLICY IF EXISTS "plans_select_anon" ON plans;
CREATE POLICY "plans_select_anon"
  ON plans FOR SELECT TO anon
  USING (is_active = true);

-- Subscriptions: members read own org subscription; super_admin reads all
DROP POLICY IF EXISTS "subscriptions_select_org_members" ON subscriptions;
CREATE POLICY "subscriptions_select_org_members"
  ON subscriptions FOR SELECT TO authenticated
  USING (
    organization_id = public.get_current_user_org_id()
    OR
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'super_admin')
  );

-- 5. RLS MUTATION GATES (ENTITIES, BRANCHES, SERIES, STORAGE)
-- ============================================================

-- 5a. entities INSERT
DROP POLICY IF EXISTS "entities_insert_org_staff" ON entities;
CREATE POLICY "entities_insert_org_staff"
  ON entities FOR INSERT TO authenticated
  WITH CHECK (
    (
      EXISTS (
        SELECT 1 FROM profiles
        WHERE id = auth.uid()
          AND organization_id = entities.organization_id
          AND role IN ('owner', 'manager')
      )
      OR
      EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'super_admin')
    )
    AND public.is_org_subscription_active(entities.organization_id)
  );

-- 5b. entities UPDATE
DROP POLICY IF EXISTS "entities_update_org_staff" ON entities;
CREATE POLICY "entities_update_org_staff"
  ON entities FOR UPDATE TO authenticated
  USING (
    (
      EXISTS (
        SELECT 1 FROM profiles
        WHERE id = auth.uid()
          AND organization_id = entities.organization_id
          AND role IN ('owner', 'manager')
      )
      OR
      EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'super_admin')
    )
    AND public.is_org_subscription_active(entities.organization_id)
  )
  WITH CHECK (
    (
      EXISTS (
        SELECT 1 FROM profiles
        WHERE id = auth.uid()
          AND organization_id = entities.organization_id
          AND role IN ('owner', 'manager')
      )
      OR
      EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'super_admin')
    )
    AND public.is_org_subscription_active(entities.organization_id)
  );

-- 5c. branches INSERT
DROP POLICY IF EXISTS "branches_insert_org_owner_or_manager" ON branches;
CREATE POLICY "branches_insert_org_owner_or_manager"
  ON branches FOR INSERT TO authenticated
  WITH CHECK (
    (
      EXISTS (
        SELECT 1 FROM profiles
        WHERE id = auth.uid()
          AND organization_id = branches.organization_id
          AND role IN ('owner', 'manager')
      )
      OR
      EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'super_admin')
    )
    AND public.is_org_subscription_active(branches.organization_id)
  );

-- 5d. branches UPDATE
DROP POLICY IF EXISTS "branches_update_org_owner_or_manager" ON branches;
CREATE POLICY "branches_update_org_owner_or_manager"
  ON branches FOR UPDATE TO authenticated
  USING (
    (
      EXISTS (
        SELECT 1 FROM profiles
        WHERE id = auth.uid()
          AND organization_id = branches.organization_id
          AND role IN ('owner', 'manager')
      )
      OR
      EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'super_admin')
    )
    AND public.is_org_subscription_active(branches.organization_id)
  )
  WITH CHECK (
    (
      EXISTS (
        SELECT 1 FROM profiles
        WHERE id = auth.uid()
          AND organization_id = branches.organization_id
          AND role IN ('owner', 'manager')
      )
      OR
      EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'super_admin')
    )
    AND public.is_org_subscription_active(branches.organization_id)
  );

-- 5e. series INSERT
DROP POLICY IF EXISTS "series_insert_org" ON series;
CREATE POLICY "series_insert_org"
  ON series FOR INSERT TO authenticated
  WITH CHECK (
    (
      EXISTS (
        SELECT 1 FROM profiles
        WHERE id = auth.uid()
          AND organization_id = series.organization_id
          AND role IN ('owner', 'manager')
      )
      OR
      EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'super_admin')
    )
    AND public.is_org_subscription_active(series.organization_id)
  );

-- 5f. series UPDATE
DROP POLICY IF EXISTS "series_update_org" ON series;
CREATE POLICY "series_update_org"
  ON series FOR UPDATE TO authenticated
  USING (
    (
      EXISTS (
        SELECT 1 FROM profiles
        WHERE id = auth.uid()
          AND organization_id = series.organization_id
          AND role IN ('owner', 'manager')
      )
      OR
      EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'super_admin')
    )
    AND public.is_org_subscription_active(series.organization_id)
  )
  WITH CHECK (
    (
      EXISTS (
        SELECT 1 FROM profiles
        WHERE id = auth.uid()
          AND organization_id = series.organization_id
          AND role IN ('owner', 'manager')
      )
      OR
      EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'super_admin')
    )
    AND public.is_org_subscription_active(series.organization_id)
  );

-- 5g. storage.objects INSERT (Organization Assets)
DROP POLICY IF EXISTS "org_assets_insert" ON storage.objects;
CREATE POLICY "org_assets_insert"
  ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'organization_assets'
    AND (storage.foldername(name))[1] = public.get_current_user_org_id()::text
    AND public.is_org_subscription_active(public.get_current_user_org_id())
  );

-- 6. DEFAULT PLANS SEED DATA
-- ============================================================
INSERT INTO plans (slug, name, description, is_active, price_monthly, price_yearly, currency, features, limits)
VALUES
  (
    'community',
    '{"ar": "مجتمعية (مفتوحة)", "en": "Community (Open)"}'::jsonb,
    '{"ar": "خطة الاستضافة الذاتية المفتوحة الدائمة", "en": "Perpetual self-hosted open-source plan"}'::jsonb,
    true,
    0.00,
    0.00,
    'USD',
    '{"ai_generate": true, "premium_content": true, "custom_branding": true, "audio_podcasts": true}'::jsonb,
    '{"monthly_ai_requests": -1, "monthly_ai_tokens": -1, "max_branches": -1}'::jsonb
  ),
  (
    'pro',
    '{"ar": "احترافية", "en": "Professional"}'::jsonb,
    '{"ar": "خطة العمل السحابية الاحترافية", "en": "Professional commercial SaaS plan"}'::jsonb,
    true,
    29.00,
    290.00,
    'USD',
    '{"ai_generate": true, "premium_content": true, "custom_branding": true, "audio_podcasts": true}'::jsonb,
    '{"monthly_ai_requests": 250, "monthly_ai_tokens": 2000000, "max_branches": 5}'::jsonb
  )
ON CONFLICT (slug) DO NOTHING;

-- 7. BACKFILL EXISTING ORGANIZATIONS WITH PERPETUAL COMMUNITY SUBSCRIPTION
-- ============================================================
INSERT INTO subscriptions (organization_id, plan_id, status, billing_period, starts_at, expires_at)
SELECT
  o.id,
  p.id,
  'active',
  'yearly',
  now(),
  NULL
FROM organizations o
CROSS JOIN (SELECT id FROM plans WHERE slug = 'community' LIMIT 1) p
WHERE NOT EXISTS (
  SELECT 1 FROM subscriptions s
  WHERE s.organization_id = o.id
    AND s.status = 'active'
)
ON CONFLICT DO NOTHING;
