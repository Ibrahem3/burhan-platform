import { getSupabaseAdmin } from '../../utils/supabase'
import { resolveCaller } from '../../utils/auth'
import { encryptSecret } from '../../utils/crypto'
import { validateProviderEndpointPolicy } from '../../utils/ssrf'

const VALID_PROVIDERS = ['openai', 'nosana', 'openrouter', 'custom'] as const

export default defineEventHandler(async (event) => {
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

  const { provider, apiKey, baseUrl, customModel, isActive } = body

  if (!provider || typeof provider !== 'string' || !VALID_PROVIDERS.includes(provider as any)) {
    throw createError({ statusCode: 400, statusMessage: `Invalid provider. Must be one of: ${VALID_PROVIDERS.join(', ')}` })
  }

  const trimmedKey = typeof apiKey === 'string' ? apiKey.trim() : ''
  if (!trimmedKey) {
    throw createError({ statusCode: 400, statusMessage: 'Missing or empty apiKey' })
  }

  // Validate endpoint against strict deployment & provider policy
  const policyResult = await validateProviderEndpointPolicy(provider, baseUrl)
  if (!policyResult.allowed) {
    throw createError({
      statusCode: policyResult.statusCode || 400,
      statusMessage: policyResult.error || 'Provider endpoint policy violation',
    })
  }

  const normalizedBaseUrl = policyResult.normalizedBaseUrl ?? null

  // Encrypt immediately server-side
  let encryptedPayload
  try {
    encryptedPayload = encryptSecret(trimmedKey)
  } catch (err: any) {
    console.error('[ai-credentials.post] encryption error:', err?.message)
    throw createError({ statusCode: 500, statusMessage: 'Encryption subsystem failure' })
  }

  const keySuffix = trimmedKey.length > 4 ? trimmedKey.slice(-4) : trimmedKey
  const activeFlag = typeof isActive === 'boolean' ? isActive : true

  // In-place rotation or creation on (organization_id, provider)
  const { data, error } = await admin
    .from('tenant_ai_credentials')
    .upsert(
      {
        organization_id: profile.organization_id,
        provider,
        encrypted_key: encryptedPayload.ciphertext,
        key_iv: encryptedPayload.iv,
        key_tag: encryptedPayload.tag,
        key_version: encryptedPayload.keyVersion,
        key_suffix: keySuffix,
        base_url: normalizedBaseUrl,
        custom_model: typeof customModel === 'string' && customModel.trim() ? customModel.trim() : null,
        is_active: activeFlag,
        updated_at: new Date().toISOString(),
      },
      {
        onConflict: 'organization_id, provider',
      }
    )
    .select('id, provider, key_suffix, base_url, custom_model, is_active, updated_at')
    .single()

  if (error) {
    console.error('[ai-credentials.post] database upsert error:', error)
    throw createError({ statusCode: 500, statusMessage: 'Failed to save AI credentials' })
  }

  // Return strictly confirmation metadata; plaintext key is never echoed back
  return {
    success: true,
    id: data.id,
    provider: data.provider,
    keySuffix: data.key_suffix,
    baseUrl: data.base_url,
    customModel: data.custom_model,
    isActive: data.is_active,
    updatedAt: data.updated_at,
  }
})
