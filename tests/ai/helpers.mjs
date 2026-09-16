import { execFile } from 'node:child_process'
import { promisify } from 'node:util'
import { fileURLToPath } from 'node:url'
import path from 'node:path'

const exec = promisify(execFile)

export const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..')
export const DB_URL = process.env.TEST_DATABASE_URL || 'postgres://burhan:burhan-test@localhost:55432/burhan_test'


const BASE = ['-X', '-v', 'ON_ERROR_STOP=1', '-d', DB_URL]

function psqlEnv(opts = {}) {
  const env = { ...process.env }
  const gucs = []
  if (opts.role) gucs.push(`role=${opts.role}`)
  if (opts.sub) gucs.push(`request.jwt.claim.sub=${opts.sub}`)
  if (gucs.length) env.PGOPTIONS = `-c ${gucs.join(' -c ')}`
  return env
}

async function raw(args, opts = {}) {
  try {
    const { stdout, stderr } = await exec('psql', [...BASE, ...args], { env: psqlEnv(opts), maxBuffer: 1024 * 1024 * 64 })
    return { ok: true, out: stdout, err: stderr, code: 0 }
  } catch (e) {
    return { ok: false, out: e.stdout || '', err: e.stderr || e.message || String(e), code: e.code || 1 }
  }
}

/** Run SQL, return { ok, out, err, code }. Never throws on DB errors. */
export function r(sql) {
  return raw(['-c', sql])
}

/** Run SQL and return rows as arrays of tab-separated values. */
export async function q(sql) {
  const res = await raw(['-A', '-F', '\t', '-t', '-c', sql])
  if (!res.ok) throw new Error(`SQL failed (${res.code}): ${sql}\n${res.err}`)
  return res.out
    .trim()
    .split('\n')
    .filter((l) => l.length > 0)
    .map((l) => l.split('\t'))
}

/** Run SQL, return single scalar (string) or null. */
export async function q1(sql) {
  const rows = await q(sql)
  return rows.length ? rows[0][0] : null
}

/** Apply a SQL file (rejects on psql failure / nonzero exit). */
export async function applyFile(file) {
  await exec('psql', ['-X', '-v', 'ON_ERROR_STOP=1', '-d', DB_URL, '-f', file], { maxBuffer: 1024 * 1024 * 128 })
}

let ready = false

/** Rebuild the whole test database once per process. */
export async function setup() {
  if (ready) return
  await r('DROP SCHEMA IF EXISTS public CASCADE')
  await r('CREATE SCHEMA public')
  await r('DROP SCHEMA IF EXISTS auth CASCADE')
  await r('DROP SCHEMA IF EXISTS storage CASCADE')
  await r('DROP ROLE IF EXISTS anon')
  await r('DROP ROLE IF EXISTS authenticated')
  await r('DROP ROLE IF EXISTS service_role')
  await applyFile(path.join(ROOT, 'tests', 'ai', 'bootstrap.sql'))
  await applyFile(path.join(ROOT, 'supabase', 'schema.sql'))
  await applyFile(path.join(ROOT, 'tests', 'ai', 'post-setup.sql'))
  await applyFile(path.join(ROOT, 'tests', 'ai', 'seed.sql'))
  ready = true
}

async function qWith(role, sub, sql) {
  const res = await raw(['-A', '-F', '\t', '-t', '-c', sql], { role, sub })
  if (!res.ok) throw new Error(`SQL failed (${res.code}) [role=${role}]: ${sql}\n${res.err}`)
  return res.out
    .trim()
    .split('\n')
    .filter((l) => l.length > 0)
    .map((l) => l.split('\t'))
}

/** Run SQL as an authenticated client with a given JWT sub (RLS on). */
export function asUser(sub, sql) {
  return qWith('authenticated', sub, sql)
}

/** Run SQL as an anonymous client (RLS on, auth.uid() = NULL). */
export function asAnon(sql) {
  return qWith('anon', null, sql)
}

/** Fire several SQL statements as separate concurrent transactions. */
export function concurrent(...statements) {
  return Promise.all(statements.map((sql) => r(sql)))
}

let seq = 0

/** Create an isolated org + member + (optional) branch for a test. Returns ids. */
export async function seedOrg(prefix = 't') {
  seq += 1
  const uid = `${prefix}${Date.now().toString(36)}${seq}`
  const orgId = `00000000-0000-0000-${String(seq).padStart(4, '0')}-000000000001`
  const memberId = `00000000-0000-0000-${String(seq).padStart(4, '0')}-000000000002`

  await r(
    `INSERT INTO organizations (id, name, org_slug, settings) VALUES ('${orgId}', '{"ar":"${uid}"}', '${uid}', '{}');
     INSERT INTO auth.users (id) VALUES ('${memberId}');
     UPDATE profiles SET organization_id = '${orgId}', role = 'member' WHERE id = '${memberId}';
     INSERT INTO branches (id, organization_id, name, slug, module_type)
       VALUES ('00000000-0000-0000-${String(seq).padStart(4, '0')}-000000000003', '${orgId}', '{"ar":"main"}', 'main', 'content');`
  )

  return {
    orgId,
    memberId,
    branchId: `00000000-0000-0000-${String(seq).padStart(4, '0')}-000000000003`,
  }
}

export const U = {
  ADMIN: 'aaaaaaaa-0000-0000-0000-000000000003',
  USER_A: 'aaaaaaaa-0000-0000-0000-000000000001',
  USER_A2: 'aaaaaaaa-0000-0000-0000-000000000005',
  USER_B: 'aaaaaaaa-0000-0000-0000-000000000002',
  USER_X: 'aaaaaaaa-0000-0000-0000-000000000004',
}

export const ORG_A = '11111111-1111-1111-1111-111111111111'
export const ORG_B = '22222222-2222-2222-2222-222222222222'

const RESERVE = (userId, orgId, est, reqLim, tokLim) =>
  `SELECT public.reserve_ai_quota('${userId}', '${orgId}', ${est}, ${reqLim}, ${tokLim});`

export const reserve = (userId, orgId, est, reqLim = 100, tokLim = 1000000) => r(RESERVE(userId, orgId, est, reqLim, tokLim))

const CREATE_JOB = (userId, orgId, branchId, prompt, extra = '') =>
  `SELECT public.create_ai_job('${userId}', '${orgId}', ${branchId ? `'${branchId}'` : 'NULL'}, '${prompt}', NULL, 'ar', 'test-model', 500, 100, 1000000${extra});`

export const createJob = async (userId, orgId, branchId, prompt = 'generate an article') => {
  const res = await r(CREATE_JOB(userId, orgId, branchId, prompt))
  if (!res.ok) return { error: res.err }
  const out = res.out.trim()
  const match = out.match(/"id": "([0-9a-f-]{36})"/)
  return { jobId: match ? match[1] : null, raw: out, ok: res.ok }
}

export const usageOf = (orgId, period) => q(`SELECT requests_used, tokens_reserved, tokens_used FROM ai_usage WHERE organization_id = '${orgId}' AND period_month = '${period}';`)

export const jobRow = (jobId) => q(`SELECT status, tokens_estimated, tokens_used, quota_reconciled, consumed, period_month FROM ai_jobs WHERE id = '${jobId}';`)