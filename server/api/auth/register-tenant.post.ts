import { getSupabaseAdmin } from '../../utils/supabase'

export default defineEventHandler(async (event) => {
  const body = await readBody(event).catch(() => ({}))
  const { accessToken, orgName, orgSlug } = body

  // 1. Validate payload
  if (!accessToken || typeof accessToken !== 'string') {
    throw createError({
      statusCode: 400,
      statusMessage: 'Access token is required',
      data: { code: 'invalid_payload' },
    })
  }

  const trimmedName = typeof orgName === 'string' ? orgName.trim() : ''
  const trimmedSlug = typeof orgSlug === 'string' ? orgSlug.trim().toLowerCase() : ''

  if (!trimmedName || trimmedName.length < 2) {
    throw createError({
      statusCode: 400,
      statusMessage: 'Organization name must be at least 2 characters',
      data: { code: 'invalid_payload' },
    })
  }

  if (!trimmedSlug || trimmedSlug.length < 2 || !/^[a-z0-9-]+$/.test(trimmedSlug)) {
    throw createError({
      statusCode: 400,
      statusMessage: 'Organization slug must be alphanumeric with hyphens (min 2 chars)',
      data: { code: 'invalid_payload' },
    })
  }

  // 2. Validate session & caller identity via Supabase Auth
  const admin = getSupabaseAdmin() as any
  const { data: userData, error: userError } = await admin.auth.getUser(accessToken)

  if (userError || !userData?.user) {
    throw createError({
      statusCode: 401,
      statusMessage: 'Invalid or expired session',
      data: { code: 'invalid_session' },
    })
  }

  const user = userData.user

  // 3. Email Confirmation Gate (Defense-in-depth)
  // Check Supabase Auth user confirmed_at or email_confirmed_at
  const isEmailConfirmed = Boolean(user.email_confirmed_at || user.confirmed_at)
  if (!isEmailConfirmed) {
    throw createError({
      statusCode: 403,
      statusMessage: 'Email address must be confirmed before provisioning an organization',
      data: { code: 'email_not_confirmed' },
    })
  }

  // 4. Execute Atomic Provisioning RPC
  const { data: result, error: rpcError } = await admin.rpc('provision_tenant', {
    p_user_id: user.id,
    p_org_name: trimmedName,
    p_org_slug: trimmedSlug,
  })

  if (rpcError || !result) {
    console.error('[register-tenant] RPC error:', rpcError)
    const rawMsg = rpcError?.message || ''

    if (rawMsg.includes('slug_already_taken') || rpcError?.code === '23505') {
      throw createError({
        statusCode: 409,
        statusMessage: 'Organization slug is already registered',
        data: { code: 'slug_already_taken' },
      })
    }

    if (rawMsg.includes('user_already_has_tenant')) {
      throw createError({
        statusCode: 409,
        statusMessage: 'User already owns an organization',
        data: { code: 'user_already_has_tenant' },
      })
    }

    if (rawMsg.includes('invalid_payload')) {
      throw createError({
        statusCode: 400,
        statusMessage: 'Invalid organization registration parameters',
        data: { code: 'invalid_payload' },
      })
    }

    if (rawMsg.includes('tenant_state_corrupted')) {
      throw createError({
        statusCode: 500,
        statusMessage: 'Existing organization state is incomplete or corrupted',
        data: { code: 'tenant_state_corrupted' },
      })
    }

    // Default sanitized server failure (never leak Postgres internal syntax)
    throw createError({
      statusCode: 500,
      statusMessage: 'Failed to provision organization',
      data: { code: 'provisioning_failed' },
    })
  }

  // 5. Success Response
  // 200 for idempotent re-retrieval, 201 for freshly created tenant
  if (result.is_existing) {
    setResponseStatus(event, 200)
  } else {
    setResponseStatus(event, 201)
  }

  return {
    org: result.org,
    branch: result.branch,
    isExisting: Boolean(result.is_existing),
  }
})
