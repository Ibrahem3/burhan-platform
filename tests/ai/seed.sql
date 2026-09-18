-- BURHAN DeAI backend test bootstrap — SEED DATA
-- Fixed UUIDs keep assertions readable.

INSERT INTO organizations (id, name, org_slug, settings) VALUES
  ('11111111-1111-1111-1111-111111111111', '{"ar":"Org A"}', 'org-a', '{}'),
  ('22222222-2222-2222-2222-222222222222', '{"ar":"Org B"}', 'org-b', '{}');

-- Seed active community subscriptions for test organizations (required before branch creation)
INSERT INTO subscriptions (organization_id, plan_id, status, billing_period, starts_at, expires_at)
SELECT o.id, p.id, 'active', 'yearly', now(), NULL
FROM organizations o
CROSS JOIN (SELECT id FROM plans WHERE slug = 'community' LIMIT 1) p
ON CONFLICT DO NOTHING;

-- The on_auth_user_created trigger auto-creates profiles for these users.
INSERT INTO auth.users (id) VALUES
  ('aaaaaaaa-0000-0000-0000-000000000001'),  -- userA  -> Org A member
  ('aaaaaaaa-0000-0000-0000-000000000002'),  -- userB  -> Org B member
  ('aaaaaaaa-0000-0000-0000-000000000003'),  -- admin  -> super_admin (no org)
  ('aaaaaaaa-0000-0000-0000-000000000004'),  -- userX  -> profile removed (unknown)
  ('aaaaaaaa-0000-0000-0000-000000000005');  -- userA2 -> Org A member

INSERT INTO branches (id, organization_id, name, slug, module_type) VALUES
  ('bbbbbbbb-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', '{"ar":"الرئيسي","en":"main"}', 'main', 'content'),
  ('bbbbbbbb-0000-0000-0000-000000000002', '22222222-2222-2222-2222-222222222222', '{"ar":"الرئيسي","en":"main"}', 'main', 'content');

UPDATE profiles
  SET organization_id = '11111111-1111-1111-1111-111111111111', role = 'member'
  WHERE id = 'aaaaaaaa-0000-0000-0000-000000000001';

UPDATE profiles
  SET organization_id = '22222222-2222-2222-2222-222222222222', role = 'member'
  WHERE id = 'aaaaaaaa-0000-0000-0000-000000000002';

UPDATE profiles
  SET organization_id = NULL, role = 'super_admin'
  WHERE id = 'aaaaaaaa-0000-0000-0000-000000000003';

UPDATE profiles
  SET organization_id = '11111111-1111-1111-1111-111111111111', role = 'member'
  WHERE id = 'aaaaaaaa-0000-0000-0000-000000000005';

-- Simulate an unknown user: exists in auth.users but has no profile.
DELETE FROM profiles WHERE id = 'aaaaaaaa-0000-0000-0000-000000000004';

-- A couple of public hub entities for the regression smoke test.
INSERT INTO entities (id, branch_id, organization_id, title, content, is_public_to_hub, is_premium) VALUES
  ('cccccccc-0000-0000-0000-000000000001', 'bbbbbbbb-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', '{"ar":"مادة عامة"}', '{"ar":"نص"}', true, false),
  ('cccccccc-0000-0000-0000-000000000002', 'bbbbbbbb-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', '{"ar":"مادة خاصة","en":"premium"}', '{"ar":"نص"}', true, true);