import { getSupabaseAdmin } from '../../utils/supabase'
import { resolveCaller } from '../../utils/auth'

export default defineEventHandler(async (event) => {
  const caller = await resolveCaller(event)
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

  const { data: credentials, error } = await admin
    .from('tenant_ai_credentials')
    .select('id, provider, key_suffix, base_url, custom_model, is_active, key_version, created_at, updated_at')
    .eq('organization_id', profile.organization_id)
    .order('created_at', { ascending: false })

  if (error) {
    console.error('[ai-credentials.get] database error:', error)
    throw createError({ statusCode: 500, statusMessage: 'Failed to retrieve AI credentials' })
  }

  // Return strictly metadata; encrypted ciphertext, IV, and tag are never emitted
  return (credentials || []).map((row: any) => ({
    id: row.id,
    provider: row.provider,
    keySuffix: row.key_suffix,
    baseUrl: row.base_url,
    customModel: row.custom_model,
    isActive: row.is_active,
    keyVersion: row.key_version,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  }))
})
