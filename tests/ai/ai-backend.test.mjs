import { test, describe, before } from 'node:test'
import assert from 'node:assert/strict'
import { spawn } from 'node:child_process'
import {
  setup, r, q, q1, concurrent, seedOrg, reserve, createJob, usageOf, jobRow, asUser, asAnon,
  U, ORG_A, ORG_B, DB_URL,
} from './helpers.mjs'

const period = () => q1(`SELECT to_char(now(), 'YYYY-MM')`)

before(async () => {
  await setup()
})

// ============================================================
// A. MIGRATION — applies on top of 00001..00009; objects exist
// ============================================================
describe('A. migration', () => {
  test('tables exist with RLS enabled', async () => {
    for (const t of ['ai_jobs', 'ai_usage']) {
      const rows = await q(`SELECT relrowsecurity FROM pg_class WHERE relname = '${t}'`)
      assert.equal(rows.length, 1, `${t} exists`)
      assert.equal(rows[0][0], 't', `${t} RLS enabled`)
    }
  })

  test('expected columns on ai_jobs', async () => {
    const cols = await q(`SELECT column_name FROM information_schema.columns WHERE table_name = 'ai_jobs'`)
    const names = new Set(cols.map((c) => c[0]))
    for (const c of ['quota_reconciled', 'last_heartbeat_at', 'period_month', 'tokens_estimated', 'tokens_used', 'consumed', 'status', 'output_buffer']) {
      assert.ok(names.has(c), `ai_jobs.${c} exists`)
    }
  })

  test('UNIQUE(organization_id, period_month) on ai_usage', async () => {
    const rows = await q(
      `SELECT count(*) FROM pg_indexes WHERE tablename = 'ai_usage' AND indexdef LIKE '%UNIQUE%organization_id, period_month%'`
    )
    assert.equal(rows[0][0], '1')
  })

  test('all RPCs exist, are SECURITY DEFINER, with pinned search_path', async () => {
    const fns = ['ai_reserve_usage', 'ai_reconcile_job', 'reserve_ai_quota', 'create_ai_job', 'start_ai_job',
      'heartbeat_ai_job', 'complete_ai_job', 'fail_ai_job', 'cancel_ai_job', 'consume_ai_job',
      'reap_stale_ai_job', 'reconcile_abandoned_terminal_ai_jobs']
    for (const f of fns) {
      const count = await q1(`SELECT count(*) FROM pg_proc WHERE proname = '${f}'`)
      assert.equal(count, '1', `${f} exists exactly once`)
      const def = await q1(`SELECT prosecdef FROM pg_proc WHERE proname = '${f}'`)
      assert.equal(def, 't', `${f} SECURITY DEFINER`)
      const sp = await q1(`SELECT proconfig::text ILIKE '%search_path=public%' FROM pg_proc WHERE proname = '${f}'`)
      assert.equal(sp, 't', `${f} pins search_path`)
    }
  })

  test('RLS policies present: client SELECT-own only on ai_jobs', async () => {
    const rows = await q(`SELECT policyname, cmd FROM pg_policies WHERE tablename = 'ai_jobs'`)
    assert.equal(rows.length, 1)
    assert.equal(rows[0][0], 'ai_jobs_select_own')
    assert.equal(rows[0][1], 'SELECT')
    const usage = await q(`SELECT policyname, cmd FROM pg_policies WHERE tablename = 'ai_usage'`)
    assert.equal(usage[0][0], 'ai_usage_select_org')
  })

  test('service_role (and only service_role) can EXECUTE the RPCs', async () => {
    const rows = await q(
      `SELECT has_function_privilege('service_role', 'public.create_ai_job(uuid,uuid,uuid,text,text,text,text,integer,integer,integer)', 'EXECUTE'),
              has_function_privilege('authenticated', 'public.create_ai_job(uuid,uuid,uuid,text,text,text,text,integer,integer,integer)', 'EXECUTE'),
              has_function_privilege('anon', 'public.create_ai_job(uuid,uuid,uuid,text,text,text,text,integer,integer,integer)', 'EXECUTE')`
    )
    assert.equal(rows[0][0], 't', 'service_role can EXECUTE')
    assert.equal(rows[0][1], 'f', 'authenticated cannot EXECUTE')
    assert.equal(rows[0][2], 'f', 'anon cannot EXECUTE')
  })
})

// ============================================================
// B. AUTHORIZATION
// ============================================================
describe('B. authorization', () => {
  test('user A + org A allowed; user A + org B rejected', async () => {
    assert.equal((await reserve(U.USER_A, ORG_A, 10)).ok, true)
    const bad = await reserve(U.USER_A, ORG_B, 10)
    assert.equal(bad.ok, false)
    assert.match(bad.err, /ai_unauthorized/)
  })

  test('unknown user rejected', async () => {
    const bad = await reserve(U.USER_X, ORG_A, 10)
    assert.equal(bad.ok, false)
    assert.match(bad.err, /ai_unauthorized/)
  })

  test('super admin allowed in any org (existing project rule)', async () => {
    assert.equal((await reserve(U.ADMIN, ORG_A, 10)).ok, true)
    assert.equal((await reserve(U.ADMIN, ORG_B, 10)).ok, true)
  })

  test('create_ai_job enforces membership AND branch ownership', async () => {
    const orgB = await q(`SELECT id FROM branches WHERE organization_id = '${ORG_B}' LIMIT 1`)
    const branchB = orgB[0][0]
    // user A + org B -> unauthorized
    const bad = await r(
      `SELECT public.create_ai_job('${U.USER_A}', '${ORG_B}', NULL, 'x', NULL, 'ar', 'm', 500, 100, 1000000)`
    )
    assert.equal(bad.ok, false)
    assert.match(bad.err, /ai_unauthorized/)
    // user A + org A + branch that belongs to org B -> invalid branch
    const mis = await r(
      `SELECT public.create_ai_job('${U.USER_A}', '${ORG_A}', '${branchB}', 'x', NULL, 'ar', 'm', 500, 100, 1000000)`
    )
    assert.equal(mis.ok, false)
    assert.match(mis.err, /ai_invalid_branch/)
  })
})

// ============================================================
// C. SERVICE-ROLE EXECUTION with explicit p_user_id
// ============================================================
describe('C. service-role execution (explicit p_user_id)', () => {
  test('reservation succeeds while auth.uid() is unset/NULL — no auth.uid() dependency', async () => {
    const org = await seedOrg('svc')
    const res = await reserve(org.memberId, org.orgId, 25)
    assert.equal(res.ok, true, `expected success; got ${res.err}`)
  })

  test('authenticated client cannot invoke the RPCs directly', async () => {
    const res = await r(`BEGIN; SET LOCAL request.jwt.claim.sub = '${U.USER_A}'; SET LOCAL ROLE authenticated; SELECT public.reserve_ai_quota('${U.USER_A}', '${ORG_A}', 10, 100, 1000); COMMIT;`)
    assert.equal(res.ok, false)
    assert.match(res.err, /permission denied for function/)
  })
})

// ============================================================
// D. CONCURRENT QUOTA RESERVATION (FOR UPDATE)
// ============================================================
describe('D. concurrent quota reservation', () => {
  test('700 + 700 on limit 1000: exactly one succeeds, one fails', async () => {
    const org = await seedOrg('conq')
    const p = await period()

    // Pre-create the usage row and HOLD the lock so both reservations
    // genuinely contend on SELECT ... FOR UPDATE.
    await r(`INSERT INTO ai_usage (organization_id, period_month) VALUES ('${org.orgId}', '${p}')`)
    const held = spawn('psql', ['-X', '-d', DB_URL], { stdio: ['pipe', 'ignore', 'pipe'] })
    await new Promise((res) => setTimeout(res, 400))
    held.stdin.write(`BEGIN;\nSELECT organization_id FROM ai_usage WHERE organization_id = '${org.orgId}' AND period_month = '${p}' FOR UPDATE;\n`)
    await new Promise((res) => setTimeout(res, 400)) // let the lock be taken

    const resultsP = concurrent(
      `SELECT public.reserve_ai_quota('${org.memberId}', '${org.orgId}', 700, 100, 1000)`,
      `SELECT public.reserve_ai_quota('${org.memberId}', '${org.orgId}', 700, 100, 1000)`,
    )
    await new Promise((res) => setTimeout(res, 800)) // let both connections block on FOR UPDATE
    held.stdin.write('COMMIT;\n')
    held.stdin.end()
    const results = await resultsP

    const ok = results.filter((x) => x.ok).length
    const ko = results.filter((x) => !x.ok)
    assert.equal(ok, 1, 'one succeeds')
    assert.equal(ko.length, 1, 'one fails')
    assert.match(ko[0].err, /ai_quota_exceeded/)

    const usage = await usageOf(org.orgId, p)
    assert.equal(usage[0][0], '1', 'requests_used = 1')
    assert.equal(usage[0][1], '700', 'tokens_reserved = 700 (no oversubscription)')
  })

  test('400 + 400 + 400 on limit 800: exactly two admissions', async () => {
    const org = await seedOrg('con3')
    const results = await concurrent(
      `SELECT public.reserve_ai_quota('${org.memberId}', '${org.orgId}', 400, 100, 800)`,
      `SELECT public.reserve_ai_quota('${org.memberId}', '${org.orgId}', 400, 100, 800)`,
      `SELECT public.reserve_ai_quota('${org.memberId}', '${org.orgId}', 400, 100, 800)`,
    )
    const ok = results.filter((x) => x.ok).length
    const ko = results.filter((x) => !x.ok)
    assert.equal(ok, 2)
    assert.equal(ko.length, 1)
    const usage = await usageOf(org.orgId, await period())
    assert.equal(usage[0][0], '2', 'requests_used = 2')
    assert.equal(usage[0][1], '800', 'tokens_reserved = 800')
  })
})

// ============================================================
// E/F/G/H + addendum 4 — reconciliation & quota semantics
// ============================================================
describe('E-H. reconciliation & quota semantics', () => {
  const start = (jobId, memberId) => r(`SELECT public.start_ai_job('${jobId}', '${memberId}')`)
  const complete = (jobId, memberId, tokens) => r(`SELECT public.complete_ai_job('${jobId}', '${memberId}', ${tokens}, 'DONE')`)
  const fail = (jobId, memberId) => r(`SELECT public.fail_ai_job('${jobId}', '${memberId}', 'inference error')`)
  const cancel = (jobId, memberId) => r(`SELECT public.cancel_ai_job('${jobId}', '${memberId}')`)

  test('E. success: estimated 500 actual 420 -> net tokens_used = 420, reservation released', async () => {
    const org = await seedOrg('e')
    const j = await createJob(org.memberId, org.orgId, org.branchId)
    assert.equal(j.ok, true)
    const p = await period()
    assert.equal((await start(j.jobId, org.memberId)).ok, true)
    assert.equal((await complete(j.jobId, org.memberId, 420)).ok, true)
    const usage = await usageOf(org.orgId, p)
    assert.equal(usage[0][1], '0', 'reservation released')
    assert.equal(usage[0][2], '420', 'final accounting = 420 actual')
    assert.equal(usage[0][0], '1', 'one request consumed')
  })

  test('F. overage: estimated 500 actual 650 -> charged 650 to the SAME period', async () => {
    const org = await seedOrg('f')
    const j = await createJob(org.memberId, org.orgId, org.branchId)
    const p = await period()
    assert.equal((await start(j.jobId, org.memberId)).ok, true)
    assert.equal((await complete(j.jobId, org.memberId, 650)).ok, true)
    const usage = await usageOf(org.orgId, p)
    assert.equal(usage[0][2], '650', 'overage charged')
    assert.equal(usage[0][1], '0', 'reservation released')
  })

  test('G. failure refund: reserved tokens released, request stays consumed', async () => {
    const org = await seedOrg('g')
    const j = await createJob(org.memberId, org.orgId, org.branchId)
    const p = await period()
    assert.equal((await start(j.jobId, org.memberId)).ok, true)
    assert.equal((await fail(j.jobId, org.memberId)).ok, true)
    const usage = await usageOf(org.orgId, p)
    assert.equal(usage[0][1], '0', 'tokens released (0 - E)')
    assert.equal(usage[0][2], '0', 'no billable tokens')
    assert.equal(usage[0][0], '1', 'request NOT refunded (admitted -> consumed)')
  })

  test('H. cancellation refund: releases reservation exactly once, request persists', async () => {
    const org = await seedOrg('h')
    const j = await createJob(org.memberId, org.orgId, org.branchId)
    const p = await period()
    assert.equal((await start(j.jobId, org.memberId)).ok, true)
    assert.equal((await cancel(j.jobId, org.memberId)).ok, true)
    const usage1 = await usageOf(org.orgId, p)
    assert.equal(usage1[0][1], '0')
    assert.equal(usage1[0][0], '1')
    // second cancel: no accounting change
    const again = await cancel(j.jobId, org.memberId)
    assert.match(again.out, /"changed"\s*:\s*false/)
    const usage2 = await usageOf(org.orgId, p)
    assert.equal(usage2[0][1], '0')
    assert.equal(usage2[0][0], '1')
  })

  test('I. reconciliation idempotency: second complete_ai_job is a no-op', async () => {
    const org = await seedOrg('i')
    const j = await createJob(org.memberId, org.orgId, org.branchId)
    const p = await period()
    assert.equal((await start(j.jobId, org.memberId)).ok, true)
    assert.equal((await complete(j.jobId, org.memberId, 420)).ok, true)
    const res = (await complete(j.jobId, org.memberId, 999)).out
    assert.match(res, /"changed"\s*:\s*false/)
    const usage = await usageOf(org.orgId, p)
    assert.equal(usage[0][2], '420', 'no second accounting change')
    assert.equal(usage[0][1], '0')
  })
})

// ============================================================
// addendum 3 — crash-window invariant + recovery sweep
// ============================================================
describe('crash-window invariant', () => {
  test('terminal-but-unreconciled job is swept exactly once', async () => {
    const org = await seedOrg('cw')
    const j = await createJob(org.memberId, org.orgId, org.branchId)
    const p = await period()
    await r(`SELECT public.start_ai_job('${j.jobId}', '${org.memberId}')`)

    // Simulate a non-atomic transition that died BEFORE reconciliation.
    await r(`UPDATE ai_jobs SET status = 'completed', tokens_used = 420, quota_reconciled = false WHERE id = '${j.jobId}'`)
    let usage = await usageOf(org.orgId, p)
    assert.equal(usage[0][1], '500', 'reservation still reserved (unreconciled)')

    // Re-issuing complete_ai_job must NOT reconcile (job already terminal).
    const again = await r(`SELECT public.complete_ai_job('${j.jobId}', '${org.memberId}', 420)`)
    assert.match(again.out, /"changed"\s*:\s*false/)

    // The recovery sweep reconciles it exactly once.
    const sweep = await r(`SELECT public.reconcile_abandoned_terminal_ai_jobs('${j.jobId}')`)
    assert.match(sweep.out, /"reconciled"\s*:\s*1/)
    usage = await usageOf(org.orgId, p)
    assert.equal(usage[0][1], '0', 'reservation released by sweep')
    assert.equal(usage[0][2], '420', 'actual charged by sweep')
    const row = await jobRow(j.jobId)
    assert.equal(row[0][3], 't', 'quota_reconciled = true')

    // Sweep again: no-op.
    const sweep2 = await r(`SELECT public.reconcile_abandoned_terminal_ai_jobs('${j.jobId}')`)
    assert.match(sweep2.out, /"reconciled"\s*:\s*0/)
  })

  test('global sweep reaches every unreconciled terminal job', async () => {
    const org = await seedOrg('cwg')
    const j = await createJob(org.memberId, org.orgId, org.branchId)
    const p = await period()
    await r(`SELECT public.start_ai_job('${j.jobId}', '${org.memberId}')`)
    await r(`UPDATE ai_jobs SET status = 'failed', quota_reconciled = false WHERE id = '${j.jobId}'`)
    const sweep = await r(`SELECT public.reconcile_abandoned_terminal_ai_jobs(NULL)`)
    assert.match(sweep.out, /"reconciled"\s*:\s*[1-9]/)
    const usage = await usageOf(org.orgId, p)
    assert.equal(usage[0][1], '0')
  })
})

// ============================================================
// J. worker/watchdog race — exactly one terminal state wins
// ============================================================
describe('J. worker/watchdog race', () => {
  const mkStaleJob = async (tag) => {
    const org = await seedOrg(tag)
    const j = await createJob(org.memberId, org.orgId, org.branchId)
    await r(`SELECT public.start_ai_job('${j.jobId}', '${org.memberId}')`)
    await r(`UPDATE ai_jobs SET last_heartbeat_at = now() - interval '10 minutes' WHERE id = '${j.jobId}'`)
    return { org, jobId: j.jobId }
  }

  test('worker=completed vs watchdog=failed run concurrently: one wins, one no-op, single reconciliation', async () => {
    const { org, jobId } = await mkStaleJob('jrace')
    const p = await period()
    const [worker, reaper] = await concurrent(
      `SELECT public.complete_ai_job('${jobId}', '${org.memberId}', 420, 'DONE')`,
      `SELECT public.reap_stale_ai_job('${jobId}', 90)`,
    )
    const row = await jobRow(jobId)
    const status = row[0][0]
    assert.ok(['completed', 'failed'].includes(status), `status=${status}`)
    assert.equal(row[0][3], 't', 'quota_reconciled once')

    const okWorkers = [worker, reaper].filter((x) => /"changed"\s*:\s*true/.test(x.out)).length
    assert.equal(okWorkers, 1, 'exactly one transition changed the row')

    const usage = await usageOf(org.orgId, p)
    assert.equal(usage[0][1], '0', 'reservation released exactly once')
    assert.equal(usage[0][2], status === 'completed' ? '420' : '0')

    // No double reconciliation afterwards.
    const sweep = await r(`SELECT public.reconcile_abandoned_terminal_ai_jobs('${jobId}')`)
    assert.match(sweep.out, /"reconciled"\s*:\s*0/)
  })

  test('watchdog first, then worker: completed attempt is a no-op', async () => {
    const { org, jobId } = await mkStaleJob('jrev')
    const p = await period()
    const reaper = await r(`SELECT public.reap_stale_ai_job('${jobId}', 90)`)
    assert.match(reaper.out, /"changed"\s*:\s*true/)
    const worker = await r(`SELECT public.complete_ai_job('${jobId}', '${org.memberId}', 420, 'DONE')`)
    assert.match(worker.out, /"changed"\s*:\s*false/)
    const row = await jobRow(jobId)
    assert.equal(row[0][0], 'failed')
    const usage = await usageOf(org.orgId, p)
    assert.equal(usage[0][1], '0')
    assert.equal(usage[0][2], '0')
  })

  test('worker first, then watchdog: watchdog is a no-op', async () => {
    const { org, jobId } = await mkStaleJob('jfwd')
    const worker = await r(`SELECT public.complete_ai_job('${jobId}', '${org.memberId}', 420, 'DONE')`)
    assert.match(worker.out, /"changed"\s*:\s*true/)
    const reaper = await r(`SELECT public.reap_stale_ai_job('${jobId}', 90)`)
    assert.match(reaper.out, /"changed"\s*:\s*false/)
    const row = await jobRow(jobId)
    assert.equal(row[0][0], 'completed')
  })
})

// ============================================================
// watchdog semantics: conditional + target only stale processing jobs
// ============================================================
describe('watchdog conditioning', () => {
  test('never touches terminal, pending, or fresh-processing jobs', async () => {
    const org = await seedOrg('wd')
    // pending
    const jp = await createJob(org.memberId, org.orgId, org.branchId)
    const rp = await r(`SELECT public.reap_stale_ai_job('${jp.jobId}', 90)`)
    assert.match(rp.out, /"changed"\s*:\s*false/)
    assert.equal((await jobRow(jp.jobId))[0][0], 'pending')
    // fresh processing (recent heartbeat)
    await r(`SELECT public.start_ai_job('${jp.jobId}', '${org.memberId}')`)
    const rp2 = await r(`SELECT public.reap_stale_ai_job('${jp.jobId}', 90)`)
    assert.match(rp2.out, /"changed"\s*:\s*false/)
    assert.equal((await jobRow(jp.jobId))[0][0], 'processing')
    // terminal
    await r(`UPDATE ai_jobs SET last_heartbeat_at = now() - interval '1 hour' WHERE id = '${jp.jobId}'`)
    await r(`SELECT public.complete_ai_job('${jp.jobId}', '${org.memberId}', 100)`)
    const rp3 = await r(`SELECT public.reap_stale_ai_job('${jp.jobId}', 90)`)
    assert.match(rp3.out, /"changed"\s*:\s*false/)
    assert.equal((await jobRow(jp.jobId))[0][0], 'completed')
  })
})

// ============================================================
// heartbeat semantics
// ============================================================
describe('heartbeat', () => {
  test('only touches processing jobs; sets last_heartbeat_at; no-op on terminal', async () => {
    const org = await seedOrg('hb')
    const j = await createJob(org.memberId, org.orgId, org.branchId)
    // pending -> no-op
    const pre = await r(`SELECT public.heartbeat_ai_job('${j.jobId}', '${org.memberId}', 'partial')`)
    assert.match(pre.out, /"changed"\s*:\s*false/)
    // start -> heartbeat works
    await r(`SELECT public.start_ai_job('${j.jobId}', '${org.memberId}')`)
    const ok = await r(`SELECT public.heartbeat_ai_job('${j.jobId}', '${org.memberId}', 'partial')`)
    assert.match(ok.out, /"changed"\s*:\s*true/)
    const row = await q(`SELECT last_heartbeat_at IS NOT NULL, output_buffer FROM ai_jobs WHERE id = '${j.jobId}'`)
    assert.equal(row[0][0], 't')
    assert.equal(row[0][1], 'partial')
    // terminal -> no-op
    await r(`SELECT public.fail_ai_job('${j.jobId}', '${org.memberId}', 'x')`)
    const post = await r(`SELECT public.heartbeat_ai_job('${j.jobId}', '${org.memberId}', 'more')`)
    assert.match(post.out, /"changed"\s*:\s*false/)
  })
})

// ============================================================
// K. terminal immutability
// ============================================================
describe('K. terminal immutability', () => {
  test('completed/failed/cancelled cannot be resurrected', async () => {
    const org = await seedOrg('k')
    const trans = async () => {
      const j = await createJob(org.memberId, org.orgId, org.branchId)
      await r(`SELECT public.start_ai_job('${j.jobId}', '${org.memberId}')`)
      return j.jobId
    }

    const completed = await trans()
    await r(`SELECT public.complete_ai_job('${completed}', '${org.memberId}', 100)`)
    const rc = await r(`SELECT public.fail_ai_job('${completed}', '${org.memberId}', 'x')`)
    assert.match(rc.out, /"changed"\s*:\s*false/)
    assert.equal((await jobRow(completed))[0][0], 'completed')

    const failed = await trans()
    await r(`SELECT public.fail_ai_job('${failed}', '${org.memberId}', 'x')`)
    const rf = await r(`SELECT public.complete_ai_job('${failed}', '${org.memberId}', 100)`)
    assert.match(rf.out, /"changed"\s*:\s*false/)
    assert.equal((await jobRow(failed))[0][0], 'failed')

    const cancelled = await trans()
    await r(`SELECT public.cancel_ai_job('${cancelled}', '${org.memberId}')`)
    const rc2 = await r(`SELECT public.complete_ai_job('${cancelled}', '${org.memberId}', 100)`)
    assert.match(rc2.out, /"changed"\s*:\s*false/)
    assert.equal((await jobRow(cancelled))[0][0], 'cancelled')
  })
})

// ============================================================
// L. period boundary — job period immutability
// ============================================================
describe('L. period boundary', () => {
  test('September job completed in "October" reconciles into 2026-09', async () => {
    const org = await seedOrg('lb')
    const j = await createJob(org.memberId, org.orgId, org.branchId)
    const current = await period()
    await r(`SELECT public.start_ai_job('${j.jobId}', '${org.memberId}')`)

    // Job started in 2026-09; completion happens later. period_month is immutable.
    await r(`UPDATE ai_jobs SET period_month = '2026-09' WHERE id = '${j.jobId}'`)
    await r(`INSERT INTO ai_usage (organization_id, period_month) VALUES ('${org.orgId}', '2026-09') ON CONFLICT (organization_id, period_month) DO NOTHING`)

    await r(`SELECT public.complete_ai_job('${j.jobId}', '${org.memberId}', 500, 'DONE')`)

    const sep = await usageOf(org.orgId, '2026-09')
    assert.equal(sep[0][2], '500', 'accounting lands in the ORIGINAL period')
    assert.equal(sep[0][1], '0', 'reservation released in the ORIGINAL period')

    if (current !== '2026-09') {
      const cur = await usageOf(org.orgId, current)
      assert.equal(cur[0][1], '500', 'current month untouched (reservation stays until its own period reconciles)')
      assert.equal(cur[0][2], '0')
    }
  })
})

// ============================================================
// section 15 — server-only lifecycle / client RLS
// ============================================================
describe('server-only lifecycle (RLS)', () => {
  test('client SELECT-own only; no INSERT/UPDATE/DELETE possible', async () => {
    const org = await seedOrg('rls')
    const j = await createJob(org.memberId, org.orgId, org.branchId)

    const own = await asUser(org.memberId, `SELECT count(*) FROM ai_jobs WHERE id = '${j.jobId}'`)
    assert.equal(own[0][0], '1', 'owner can SELECT own job')

    const other = await asUser(U.USER_B, `SELECT count(*) FROM ai_jobs WHERE id = '${j.jobId}'`)
    assert.equal(other[0][0], '0', 'other user cannot see it')

    const ins = await r(`BEGIN; SET LOCAL request.jwt.claim.sub = '${org.memberId}'; SET LOCAL ROLE authenticated; INSERT INTO ai_jobs (user_id, organization_id, prompt, period_month) VALUES ('${org.memberId}', '${org.orgId}', 'x', '2026-09'); COMMIT;`)
    assert.equal(ins.ok, false, 'no client INSERT')
    assert.match(ins.err, /permission denied/)

    const upd = await r(`BEGIN; SET LOCAL request.jwt.claim.sub = '${org.memberId}'; SET LOCAL ROLE authenticated; UPDATE ai_jobs SET status = 'failed' WHERE id = '${j.jobId}'; COMMIT;`)
    assert.equal(upd.ok, false, 'no client UPDATE')
    assert.match(upd.err, /permission denied/)

    const del = await r(`BEGIN; SET LOCAL request.jwt.claim.sub = '${org.memberId}'; SET LOCAL ROLE authenticated; DELETE FROM ai_jobs WHERE id = '${j.jobId}'; COMMIT;`)
    assert.equal(del.ok, false, 'no client DELETE')
    assert.match(del.err, /permission denied/)
  })

  test('ai_usage read restricted to own organization', async () => {
    const org = await seedOrg('rlsu')
    await reserve(org.memberId, org.orgId, 10)
    const p = await period()
    const own = await asUser(org.memberId, `SELECT count(*) FROM ai_usage WHERE organization_id = '${org.orgId}' AND period_month = '${p}'`)
    assert.equal(own[0][0], '1', 'owner org can read usage')
    const other = await asUser(U.USER_B, `SELECT count(*) FROM ai_usage WHERE organization_id = '${org.orgId}' AND period_month = '${p}'`)
    assert.equal(other[0][0], '0', 'other org cannot read it')
  })
})

// ============================================================
// M. existing-platform regression smoke
// ============================================================
describe('M. regression smoke (existing platform untouched)', () => {
  test('profiles RLS: own + org members still resolve', async () => {
    const own = await asUser(U.USER_A, `SELECT count(*) FROM profiles WHERE id = '${U.USER_A}'`)
    assert.equal(own[0][0], '1')
    const members = await asUser(U.USER_A, `SELECT count(*) FROM profiles WHERE organization_id = '${ORG_A}'`)
    assert.equal(members[0][0], '2', 'userA sees userA + userA2')
  })

  test('organizations resolution unaffected', async () => {
    const slug = await asUser(U.USER_A, `SELECT org_slug FROM organizations WHERE id = '${ORG_A}'`)
    assert.equal(slug[0][0], 'org-a')
  })

  test('public entity/branch reads: member feed + anon branch metadata work; anon hub read matches pre-existing baseline', async () => {
    // Authenticated member sees the public hub feed (non-premium).
    const feed = await asUser(U.USER_A, `SELECT count(*) FROM entities WHERE is_public_to_hub = true AND is_premium = false`)
    assert.equal(feed[0][0], '1', 'member sees public hub feed')

    // Anonymous: public branch metadata is still readable.
    const branches = await asAnon(`SELECT count(*) FROM branches`)
    assert.ok(Number(branches[0][0]) >= 2, `anon branch metadata readable, got ${branches[0][0]}`)

    // Anonymous hub entity read is rejected by the EXISTING profiles-RLS chain
    // (migration 00008 revokes EXECUTE on get_current_user_org_id from anon;
    // entities_select_org_member has no TO-clause and is applied to everyone).
    // Reproduced identically with only 00001-00009 applied — pre-existing and
    // untouched by 00010 (which only adds new tables/RPCs/policies).
    await assert.rejects(
      asAnon(`SELECT count(*) FROM entities WHERE is_public_to_hub = true AND is_premium = false`),
      /get_current_user_org_id/,
    )
  })

  test('observatory: public insert policy still accepts anon reports', async () => {
    // Insert WITHOUT RETURNING: RETURNING forces SELECT-policy evaluation on the
    // new row, which is blocked by the same pre-existing revoked-helper chain for
    // anonymous clients. The guaranteed-op anonymous path is a plain INSERT.
    await asAnon(`INSERT INTO observatory_threats (title, source_url) VALUES ('smoke-anon', 'https://x.com/anon-smoke')`)
    const rows = await q(`SELECT count(*) FROM observatory_threats WHERE title = 'smoke-anon'`)
    assert.equal(rows[0][0], '1', 'anon report row persisted')
    await r(`DELETE FROM observatory_threats WHERE title = 'smoke-anon'`)
  })

  test('existing helper functions still behave (is_super_admin / org resolution)', async () => {
    const admin = await asUser(U.ADMIN, `SELECT public.is_super_admin()`)
    assert.equal(admin[0][0], 't' )
    const orgId = await asUser(U.USER_A, `SELECT public.get_current_user_org_id()`)
    assert.equal(orgId[0][0], ORG_A)
  })

  test('consume_ai_job flips consumed for owner; ignored for others', async () => {
    const org = await seedOrg('cons')
    const j = await createJob(org.memberId, org.orgId, org.branchId)
    await r(`SELECT public.start_ai_job('${j.jobId}', '${org.memberId}')`)
    await r(`SELECT public.complete_ai_job('${j.jobId}', '${org.memberId}', 100)`)
    const other = await r(`SELECT public.consume_ai_job('${j.jobId}', '${U.USER_B}')`)
    assert.equal((await jobRow(j.jobId))[0][4], 'f')
    const mine = await r(`SELECT public.consume_ai_job('${j.jobId}', '${org.memberId}')`)
    assert.match(mine.out, /"consumed"\s*:\s*true/)
    assert.equal((await jobRow(j.jobId))[0][4], 't')
  })
})