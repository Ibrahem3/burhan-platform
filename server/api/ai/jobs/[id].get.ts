import { getSupabaseAdmin } from '../../../utils/supabase'
import { resolveCaller } from '../../../utils/auth'

export default defineEventHandler(async (event) => {
  const id = getRouterParam(event, 'id')
  if (!id) {
    throw createError({ statusCode: 400, statusMessage: 'Missing job id' })
  }

  const caller = await resolveCaller(event)
  // Repo-wide pre-existing issue: the typed client resolves `.from`/`.rpc`
  // to `never`. The service client is untyped here for service-role calls.
  const admin = getSupabaseAdmin() as any

  // Lazy watchdog: a polling read reaps a stale processing job exactly once
  // (atomic conditional transition + reconciliation inside the RPC).
  try {
    await admin.rpc('reap_stale_ai_job', { p_job_id: id, p_stale_after_seconds: 90 })
  } catch {
    // reaping is best-effort; the status read below is authoritative
  }

  const { data, error } = await admin
    .from('ai_jobs')
    .select(
      'id, user_id, status, output_buffer, output_final, error, tokens_estimated, tokens_used, period_month, created_at, updated_at, last_heartbeat_at'
    )
    .eq('id', id)
    .maybeSingle()

  if (error || !data) {
    throw createError({ statusCode: 404, statusMessage: 'AI job not found' })
  }

  if (data.user_id !== caller.userId) {
    const { data: superAdmin } = await admin.rpc('ai_is_super_admin', { p_user_id: caller.userId })
    if (superAdmin !== true) {
      throw createError({ statusCode: 403, statusMessage: 'Forbidden' })
    }
  }

  return {
    jobId: data.id,
    status: data.status,
    output: data.output_final,
    streamBuffer: data.output_buffer,
    error: data.error,
    tokensEstimated: data.tokens_estimated,
    tokensUsed: data.tokens_used,
    periodMonth: data.period_month,
    createdAt: data.created_at,
    updatedAt: data.updated_at,
    lastHeartbeatAt: data.last_heartbeat_at,
  }
})