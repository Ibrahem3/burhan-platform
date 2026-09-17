import { getSupabaseAdmin } from '../../utils/supabase'
import { resolveCaller } from '../../utils/auth'

export default defineEventHandler(async (event) => {
  const query = getQuery(event)
  const body = await readBody(event).catch(() => ({}))
  const caller = await resolveCaller(event, body)
  const admin = getSupabaseAdmin() as any

  // Derive organization strictly from authenticated caller profile
  const { data: profile, error: profileError } = await admin
    .from('profiles')
    .select('organization_id, role')
    .eq('id', caller.userId)
    .maybeSingle()

  if (profileError || !profile?.organization_id) {
    throw createError({ statusCode: 403, statusMessage: 'User does not belong to an organization' })
  }

  // Owner or super_admin only
  if (profile.role !== 'owner' && profile.role !== 'super_admin') {
    throw createError({ statusCode: 403, statusMessage: 'Owner authorization required' })
  }

  const provider = (query.provider || body.provider) as string | undefined
  const credentialId = (query.id || body.id) as string | undefined

  if (!provider && !credentialId) {
    throw createError({ statusCode: 400, statusMessage: 'Missing provider or credential id to delete' })
  }

  let deleteQuery = admin
    .from('tenant_ai_credentials')
    .delete()
    .eq('organization_id', profile.organization_id)

  if (provider) {
    deleteQuery = deleteQuery.eq('provider', provider)
  } else if (credentialId) {
    deleteQuery = deleteQuery.eq('id', credentialId)
  }

  const { error } = await deleteQuery

  if (error) {
    console.error('[ai-credentials.delete] database error:', error)
    throw createError({ statusCode: 500, statusMessage: 'Failed to delete AI credential' })
  }

  return {
    success: true,
    deleted: true,
  }
})
