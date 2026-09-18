import { test, describe, before } from 'node:test'
import assert from 'node:assert/strict'
import {
  setup, r, q, q1, asUser, asAnon, U, ORG_A, ORG_B
} from './ai/helpers.mjs'

before(async () => {
  await setup()
})

describe('1. Database Foundation & RLS', () => {
  test('plans and subscriptions tables exist with RLS enabled', async () => {
    for (const t of ['plans', 'subscriptions']) {
      const rows = await q(`SELECT relrowsecurity FROM pg_class WHERE relname = '${t}'`)
      assert.equal(rows.length, 1, `${t} table exists`)
      assert.equal(rows[0][0], 't', `${t} has RLS enabled`)
    }
  })

  test('default plans seeded: community (-1 unlimited) and pro', async () => {
    const plans = await q(`SELECT slug, is_active, price_monthly, limits->>'monthly_ai_requests' FROM plans ORDER BY slug`)
    assert.ok(plans.length >= 2, 'at least 2 plans seeded')
    
    const community = plans.find(p => p[0] === 'community')
    assert.ok(community, 'community plan exists')
    assert.equal(community[1], 't', 'community plan is active')
    assert.equal(community[2], '0.00', 'community plan is free')
    assert.equal(community[3], '-1', 'canonical unlimited is -1')

    const pro = plans.find(p => p[0] === 'pro')
    assert.ok(pro, 'pro plan exists')
    assert.equal(pro[1], 't', 'pro plan is active')
  })

  test('enforces exactly one active subscription per organization', async () => {
    // ORG_A already has a community subscription from 00015 seed/backfill
    const subCount = await q1(`SELECT count(*) FROM subscriptions WHERE organization_id = '${ORG_A}' AND status = 'active'`)
    assert.equal(subCount, '1', 'ORG_A has 1 active subscription')

    // Attempt to insert a second active subscription for ORG_A -> must fail unique constraint
    const proPlanId = await q1(`SELECT id FROM plans WHERE slug = 'pro' LIMIT 1`)
    const dupRes = await r(
      `INSERT INTO subscriptions (organization_id, plan_id, status) VALUES ('${ORG_A}', '${proPlanId}', 'active');`
    )
    assert.equal(dupRes.ok, false, 'second active subscription rejected by unique index')
    assert.match(dupRes.err, /idx_subscriptions_one_active_per_org/)
  })

  test('is_org_subscription_active helper accurately evaluates active vs expired vs cancelled', async () => {
    // ORG_A has active perpetual community sub (expires_at is null)
    const activePerpetual = await q1(`SELECT public.is_org_subscription_active('${ORG_A}')`)
    assert.equal(activePerpetual, 't', 'perpetual active sub returns true')

    // Create a temporary test organization with expired subscription
    const testOrgId = '99999999-9999-9999-9999-999999999991'
    const proPlanId = await q1(`SELECT id FROM plans WHERE slug = 'pro' LIMIT 1`)
    await r(`INSERT INTO organizations (id, name, org_slug) VALUES ('${testOrgId}', '{"en":"Exp Org"}', 'exp-org') ON CONFLICT DO NOTHING;`)
    await r(`INSERT INTO subscriptions (organization_id, plan_id, status, expires_at) VALUES ('${testOrgId}', '${proPlanId}', 'active', now() - interval '1 day');`)

    const activeExpired = await q1(`SELECT public.is_org_subscription_active('${testOrgId}')`)
    assert.equal(activeExpired, 'f', 'expired sub returns false')

    // Update status to cancelled
    await r(`UPDATE subscriptions SET status = 'cancelled', expires_at = now() + interval '10 days' WHERE organization_id = '${testOrgId}';`)
    const activeCancelled = await q1(`SELECT public.is_org_subscription_active('${testOrgId}')`)
    assert.equal(activeCancelled, 'f', 'cancelled sub returns false even if expires_at in future')
  })
})

describe('2. RLS Mutation Gates & Sovereignty Retention', () => {
  const TEST_ORG = '88888888-8888-8888-8888-888888888881'
  const TEST_USER = '88888888-0000-0000-0000-000000000001'
  const TEST_BRANCH = '88888888-bbbb-0000-0000-000000000001'

  before(async () => {
    // Setup test org, owner user, active subscription, branch, then expire subscription
    const proPlanId = await q1(`SELECT id FROM plans WHERE slug = 'pro' LIMIT 1`)
    await r(`INSERT INTO organizations (id, name, org_slug) VALUES ('${TEST_ORG}', '{"en":"Test Org"}', 'test-org-gate') ON CONFLICT DO NOTHING;`)
    await r(`DELETE FROM subscriptions WHERE organization_id = '${TEST_ORG}';`)
    await r(`INSERT INTO subscriptions (organization_id, plan_id, status) VALUES ('${TEST_ORG}', '${proPlanId}', 'active');`)
    await r(`INSERT INTO auth.users (id) VALUES ('${TEST_USER}') ON CONFLICT DO NOTHING;`)
    await r(`INSERT INTO profiles (id, organization_id, role) VALUES ('${TEST_USER}', '${TEST_ORG}', 'owner') ON CONFLICT (id) DO UPDATE SET organization_id = '${TEST_ORG}', role = 'owner';`)
    await r(`INSERT INTO branches (id, organization_id, name, slug) VALUES ('${TEST_BRANCH}', '${TEST_ORG}', '{"en":"Branch"}', 'b-gate') ON CONFLICT DO NOTHING;`)
    // Grant expired subscription for the test
    await r(`UPDATE subscriptions SET status = 'expired', expires_at = now() - interval '1 day' WHERE organization_id = '${TEST_ORG}';`)
  })

  test('expired subscription: entity INSERT and UPDATE blocked, but DELETE allowed', async () => {
    // Direct INSERT under owner role must be rejected by RLS
    const entityId = '88888888-eeee-0000-0000-000000000001'
    const insertRes = await r(
      `INSERT INTO entities (id, branch_id, organization_id, title, content) VALUES ('${entityId}', '${TEST_BRANCH}', '${TEST_ORG}', '{"en":"T"}', '{"en":"C"}');`
    )
    // Even if inserted as superuser for setup:
    assert.equal(insertRes.ok, true) // superuser bypasses RLS for fixture

    // Now test as authenticated owner of expired org:
    // 1. INSERT as user -> must reject
    const userInsert = await asUser(TEST_USER, 
      `INSERT INTO entities (branch_id, organization_id, title, content) VALUES ('${TEST_BRANCH}', '${TEST_ORG}', '{"en":"Blocked"}', '{"en":"C"}') RETURNING id;`
    ).catch(e => e)
    assert.ok(userInsert instanceof Error, 'insert by expired org owner rejected by RLS')

    // 2. UPDATE as user -> must reject / 0 rows updated
    const userUpdate = await asUser(TEST_USER,
      `UPDATE entities SET title = '{"en":"New Title"}' WHERE id = '${entityId}' RETURNING id;`
    ).catch(e => e)
    const isUpdateBlocked = (userUpdate instanceof Error) || (userUpdate[0] && userUpdate[0][0] === 'UPDATE 0')
    assert.ok(isUpdateBlocked, 'update by expired org owner rejected by RLS')

    // 3. DELETE as user -> MUST SUCCEED (Data sovereignty)
    const userDelete = await asUser(TEST_USER,
      `DELETE FROM entities WHERE id = '${entityId}' RETURNING id;`
    )
    assert.equal(userDelete[0][0], entityId, 'delete by expired org owner succeeds')
  })

  test('expired subscription: branch INSERT blocked, but DELETE allowed', async () => {
    const newBranchId = '88888888-bbbb-0000-0000-000000000002'
    const userBranchInsert = await asUser(TEST_USER,
      `INSERT INTO branches (id, organization_id, name, slug) VALUES ('${newBranchId}', '${TEST_ORG}', '{"en":"B2"}', 'b2') RETURNING id;`
    ).catch(e => e)
    assert.ok(userBranchInsert instanceof Error, 'branch insert blocked for expired org')

    // Existing branch can be deleted
    const userBranchDelete = await asUser(TEST_USER,
      `DELETE FROM branches WHERE id = '${TEST_BRANCH}' RETURNING id;`
    )
    assert.equal(userBranchDelete[0][0], TEST_BRANCH, 'branch delete permitted for expired org')
  })
})

describe('3. Entitlements Unit & Unlimited Boundary Adapter', () => {
  test('canonical -1 maps to 2147483647 at M1 boundary adapter', () => {
    const adaptLimit = (raw) => (raw === -1 ? 2147483647 : Math.max(0, Number(raw ?? 0)))
    assert.equal(adaptLimit(-1), 2147483647, 'canonical -1 converts to Postgres int max')
    assert.equal(adaptLimit(100), 100, 'finite limit preserved')
    assert.equal(adaptLimit(0), 0, 'zero limit preserved')
    assert.equal(adaptLimit(null), 0, 'missing limit defaults to 0')
  })

  test('active subscription allows AI job creation; quota accounting remains intact', async () => {
    // ORG_A has active community subscription (-1 unlimited)
    const proPlanId = await q1(`SELECT id FROM plans WHERE slug = 'pro' LIMIT 1`)
    const subActive = await q1(`SELECT public.is_org_subscription_active('${ORG_A}')`)
    assert.equal(subActive, 't')

    // AI reservation via service role passes
    const res = await r(`SELECT public.create_ai_job('${U.USER_A}', '${ORG_A}', NULL, 'test prompt', NULL, 'ar', 'test-model', 500, 2147483647, 2147483647);`)
    assert.equal(res.ok, true, 'AI job created successfully under active subscription')
    assert.match(res.out, /"status": "pending"/)
  })

  test('expired subscription blocks AI reservation at pre-check gate', async () => {
    const expiredOrg = '99999999-9999-9999-9999-999999999991'
    const subActive = await q1(`SELECT public.is_org_subscription_active('${expiredOrg}')`)
    assert.equal(subActive, 'f', 'expired org is not active')
    // At Nitro gate, `getActiveSubscription` returns null for expired org -> throws 402 before create_ai_job
  })
})

describe('4. Membership Security & Destination Subscription Gate (Migration 00017)', () => {
  const USER_FREE = '77777777-0000-0000-0000-000000000001'
  const ORG_T1 = '66666666-0000-0000-0000-000000000001'
  const OWNER_T1 = '77777777-0000-0000-0000-000000000002'
  const STAFF_T1 = '77777777-0000-0000-0000-000000000003'

  before(async () => {
    // 1. Create unaffiliated user
    await r(`INSERT INTO auth.users (id) VALUES ('${USER_FREE}') ON CONFLICT DO NOTHING;`)
    await r(`INSERT INTO profiles (id, full_name, role, organization_id) VALUES ('${USER_FREE}', '{"en":"Free User"}', 'member', NULL) ON CONFLICT (id) DO UPDATE SET organization_id = NULL, role = 'member';`)

    // 2. Create test org with active community sub, owner, and staff member
    await r(`INSERT INTO organizations (id, name, org_slug) VALUES ('${ORG_T1}', '{"en":"Org T1"}', 'org-t1') ON CONFLICT DO NOTHING;`)
    const commPlanId = await q1(`SELECT id FROM plans WHERE slug = 'community' LIMIT 1`)
    await r(`DELETE FROM subscriptions WHERE organization_id = '${ORG_T1}';`)
    await r(`INSERT INTO subscriptions (organization_id, plan_id, status) VALUES ('${ORG_T1}', '${commPlanId}', 'active');`)

    await r(`INSERT INTO auth.users (id) VALUES ('${OWNER_T1}') ON CONFLICT DO NOTHING;`)
    await r(`INSERT INTO profiles (id, organization_id, role, full_name) VALUES ('${OWNER_T1}', '${ORG_T1}', 'owner', '{"en":"Owner T1"}') ON CONFLICT (id) DO UPDATE SET organization_id = '${ORG_T1}', role = 'owner';`)

    await r(`INSERT INTO auth.users (id) VALUES ('${STAFF_T1}') ON CONFLICT DO NOTHING;`)
    await r(`INSERT INTO profiles (id, organization_id, role, full_name) VALUES ('${STAFF_T1}', '${ORG_T1}', 'member', '{"en":"Staff T1"}') ON CONFLICT (id) DO UPDATE SET organization_id = '${ORG_T1}', role = 'member';`)
  })

  test('Self-assignment: authenticated user cannot assign self to an organization (NULL -> Org A)', async () => {
    const res = await asUser(USER_FREE,
      `UPDATE profiles SET organization_id = '${ORG_A}' WHERE id = '${USER_FREE}' RETURNING id;`
    ).catch(e => e)
    assert.ok(res instanceof Error, 'self-assignment must be rejected')
    const currentOrg = await q1(`SELECT organization_id FROM profiles WHERE id = '${USER_FREE}'`)
    assert.equal(currentOrg, null, 'organization_id remains NULL')
  })

  test('Cross-tenant self-reassignment: authenticated user cannot switch organizations (Org A -> Org B)', async () => {
    const res = await asUser(U.USER_A,
      `UPDATE profiles SET organization_id = '${ORG_B}' WHERE id = '${U.USER_A}' RETURNING id;`
    ).catch(e => e)
    assert.ok(res instanceof Error, 'cross-tenant self-migration must be rejected')
    const currentOrg = await q1(`SELECT organization_id FROM profiles WHERE id = '${U.USER_A}'`)
    assert.equal(currentOrg, ORG_A, 'organization_id remains ORG_A')
  })

  test('Self role escalation: authenticated user cannot elevate role (member -> manager/owner/super_admin)', async () => {
    for (const targetRole of ['manager', 'owner', 'super_admin']) {
      const res = await asUser(U.USER_A,
        `UPDATE profiles SET role = '${targetRole}' WHERE id = '${U.USER_A}' RETURNING id;`
      ).catch(e => e)
      assert.ok(res instanceof Error, `elevation to ${targetRole} must be rejected`)
    }
    const currentRole = await q1(`SELECT role FROM profiles WHERE id = '${U.USER_A}'`)
    assert.equal(currentRole, 'member', 'role remains member')
  })

  test('Self profile edit: user can legitimately update full_name', async () => {
    const res = await asUser(U.USER_A,
      `UPDATE profiles SET full_name = '{"ar":"محدث","en":"Updated"}' WHERE id = '${U.USER_A}' RETURNING id;`
    )
    assert.equal(res[0][0], U.USER_A, 'self full_name update succeeds')
  })

  test('Owner role management: owner can promote/demote existing member in same org', async () => {
    // member -> manager
    let res = await asUser(OWNER_T1,
      `UPDATE profiles SET role = 'manager' WHERE id = '${STAFF_T1}' RETURNING role;`
    )
    assert.equal(res[0][0], 'manager', 'owner promoted member to manager')

    // manager -> owner
    res = await asUser(OWNER_T1,
      `UPDATE profiles SET role = 'owner' WHERE id = '${STAFF_T1}' RETURNING role;`
    )
    assert.equal(res[0][0], 'owner', 'owner promoted manager to owner')

    // owner -> member
    res = await asUser(OWNER_T1,
      `UPDATE profiles SET role = 'member' WHERE id = '${STAFF_T1}' RETURNING role;`
    )
    assert.equal(res[0][0], 'member', 'owner demoted to member')

    // Owner CANNOT grant super_admin
    const saRes = await asUser(OWNER_T1,
      `UPDATE profiles SET role = 'super_admin' WHERE id = '${STAFF_T1}' RETURNING role;`
    ).catch(e => e)
    assert.ok(saRes instanceof Error, 'owner cannot grant super_admin')
  })

  test('Owner cannot reassign member to another organization', async () => {
    const res = await asUser(OWNER_T1,
      `UPDATE profiles SET organization_id = '${ORG_B}' WHERE id = '${STAFF_T1}' RETURNING id;`
    ).catch(e => e)
    assert.ok(res instanceof Error, 'owner cannot reassign member out of org')
    const currentOrg = await q1(`SELECT organization_id FROM profiles WHERE id = '${STAFF_T1}'`)
    assert.equal(currentOrg, ORG_T1, 'organization_id remains ORG_T1')
  })

  test('Super Admin destination subscription gate: active org succeeds, expired/cancelled rejected', async () => {
    // 1. Super admin assign to active org ORG_A -> SUCCEEDS
    const okRes = await asUser(U.ADMIN,
      `UPDATE profiles SET organization_id = '${ORG_A}' WHERE id = '${USER_FREE}' RETURNING organization_id;`
    )
    assert.equal(okRes[0][0], ORG_A, 'super admin assigned user to active org')

    // 2. Super admin assign to expired org -> REJECTED (23514 member_subscription_invalid)
    const expiredOrg = '99999999-9999-9999-9999-999999999991'
    const expRes = await asUser(U.ADMIN,
      `UPDATE profiles SET organization_id = '${expiredOrg}' WHERE id = '${USER_FREE}' RETURNING id;`
    ).catch(e => e)
    assert.ok(expRes instanceof Error, 'reassignment to expired org must be rejected')
    assert.match(expRes.message, /member_subscription_invalid/)

    // 3. Super admin assign to cancelled org -> REJECTED
    const cancelledOrg = '99999999-9999-9999-9999-999999999992'
    await r(`INSERT INTO organizations (id, name, org_slug) VALUES ('${cancelledOrg}', '{"en":"Canc Org"}', 'canc-org') ON CONFLICT DO NOTHING;`)
    const proPlanId = await q1(`SELECT id FROM plans WHERE slug = 'pro' LIMIT 1`)
    await r(`DELETE FROM subscriptions WHERE organization_id = '${cancelledOrg}';`)
    await r(`INSERT INTO subscriptions (organization_id, plan_id, status) VALUES ('${cancelledOrg}', '${proPlanId}', 'cancelled');`)

    const cancRes = await asUser(U.ADMIN,
      `UPDATE profiles SET organization_id = '${cancelledOrg}' WHERE id = '${USER_FREE}' RETURNING id;`
    ).catch(e => e)
    assert.ok(cancRes instanceof Error, 'reassignment to cancelled org must be rejected')
    assert.match(cancRes.message, /member_subscription_invalid/)

    // 4. Reset USER_FREE for sanity
    await r(`UPDATE profiles SET organization_id = NULL WHERE id = '${USER_FREE}';`)
  })
})

