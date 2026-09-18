import { getSupabaseAdmin } from '../../../../utils/supabase'
import { resolveCaller } from '../../../../utils/auth'

export default defineEventHandler(async (event) => {
  const id = getRouterParam(event, 'id')
  if (!id) {
    throw createError({ statusCode: 400, statusMessage: 'Missing job id' })
  }

  const body = await readBody(event).catch(() => ({}))
  const caller = await resolveCaller(event, body)
  // Repo-wide pre-existing issue: the typed client resolves `.from`/`.rpc`
  // to `never`. The service client is untyped here for service-role calls.
  const admin = getSupabaseAdmin() as any

  // Only the job owner may consume; only completed jobs can be consumed.
  const { data, error } = await admin.rpc('consume_ai_job', {
    p_job_id: id,
    p_user_id: caller.userId,
  })

  if (error || !data) {
    throw createError({ statusCode: 500, statusMessage: error?.message || 'Failed to consume AI job' })
  }

  return { consumed: data.consumed === true }
})