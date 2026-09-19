import { getSupabaseAdmin } from '../../utils/supabase'
import { resolveCaller } from '../../utils/auth'
import { runInference } from '../../utils/nosana'
import { getActiveSubscription } from '../../utils/entitlements'
import { EDITORIAL_LIMITS } from '../../utils/editorial'

export default defineEventHandler(async (event) => {
  const config = useRuntimeConfig()

  // Kill switch — checked BEFORE any quota reservation or job creation.
  if (config.public.ai?.generateEnabled === false) {
    throw createError({ statusCode: 503, statusMessage: 'AI generation is currently disabled' })
  }

  const body = await readBody(event).catch(() => ({}))
  const caller = await resolveCaller(event, body)

  const {
    prompt,
    generationMode,
    operation,
    editorContent,
    sourceContent,
    sourceLanguage,
    targetLanguage,
    systemPrompt,
    language,
    model,
    branchId,
  } = body

  const trimmed = typeof prompt === 'string' ? prompt.trim() : ''
  if (!trimmed) {
    throw createError({ statusCode: 400, statusMessage: 'Missing required fields' })
  }

  // Safety boundaries: validate instruction and editor content limits
  if (trimmed.length > EDITORIAL_LIMITS.MAX_INSTRUCTION_CHARS) {
    throw createError({
      statusCode: 400,
      statusMessage: `Instruction exceeds maximum allowed length of ${EDITORIAL_LIMITS.MAX_INSTRUCTION_CHARS} characters`,
    })
  }

  const cleanEditorContent = typeof editorContent === 'string' && editorContent.trim() ? editorContent.trim() : null
  if (cleanEditorContent && cleanEditorContent.length > EDITORIAL_LIMITS.MAX_EDITOR_CONTENT_CHARS) {
    throw createError({
      statusCode: 400,
      statusMessage: `Editor content exceeds maximum allowed length of ${EDITORIAL_LIMITS.MAX_EDITOR_CONTENT_CHARS} characters`,
    })
  }

  const cleanSourceContent = typeof sourceContent === 'string' && sourceContent.trim() ? sourceContent.trim() : null
  if (cleanSourceContent && cleanSourceContent.length > EDITORIAL_LIMITS.MAX_EDITOR_CONTENT_CHARS) {
    throw createError({
      statusCode: 400,
      statusMessage: `Source content exceeds maximum allowed length of ${EDITORIAL_LIMITS.MAX_EDITOR_CONTENT_CHARS} characters`,
    })
  }

  const totalChars = trimmed.length + (cleanEditorContent?.length || 0) + (cleanSourceContent?.length || 0)
  if (totalChars > EDITORIAL_LIMITS.MAX_TOTAL_CONTEXT_CHARS) {
    throw createError({
      statusCode: 400,
      statusMessage: 'Total context size exceeds maximum allowed limit',
    })
  }

  const resolvedTargetLang = (targetLanguage === 'en' || language === 'en') ? 'en' : 'ar'
  const resolvedSourceLang = (sourceLanguage === 'en' || sourceLanguage === 'ar') ? sourceLanguage : null

  // Repo-wide pre-existing issue: the typed client resolves `.from`/`.rpc`
  // to `never`. The service client is untyped here for service-role calls.
  const admin = getSupabaseAdmin() as any

  // The caller must belong to an organization (membership is the only
  // authorization source; there is no separate organization_members table).
  const { data: profile, error: profileError } = await admin
    .from('profiles')
    .select('organization_id')
    .eq('id', caller.userId)
    .maybeSingle()

  if (profileError || !profile?.organization_id) {
    throw createError({ statusCode: 403, statusMessage: 'User does not belong to an organization' })
  }

  const orgId = profile.organization_id

  // Resolve organization active subscription & entitlements
  const sub = await getActiveSubscription(orgId)
  if (!sub) {
    throw createError({ statusCode: 402, statusMessage: 'Active subscription required' })
  }

  if (sub.features.ai_generate !== true) {
    throw createError({ statusCode: 403, statusMessage: 'AI generation is not enabled for this subscription plan' })
  }

  // Check whether the organization has an active BYOK credential
  const { data: activeByok } = await admin
    .from('tenant_ai_credentials')
    .select('id')
    .eq('organization_id', orgId)
    .eq('is_active', true)
    .limit(1)
    .maybeSingle()

  const isByokActive = !!activeByok?.id

  // Abuse protection: monthly_ai_requests remains strictly enforced for all jobs
  const reqLimitRaw = sub.limits.monthly_ai_requests ?? 0
  const tokLimitRaw = sub.limits.monthly_ai_tokens ?? 0

  const requestLimit = reqLimitRaw === -1 ? 2147483647 : Math.max(0, Number(reqLimitRaw))

  // Token boundary adapter:
  // For BYOK: tenant pays provider directly -> passes canonical M1 unlimited adapter (2147483647)
  // For Platform: respects organization plan limits
  const tokenLimit = isByokActive
    ? 2147483647
    : (tokLimitRaw === -1 ? 2147483647 : Math.max(0, Number(tokLimitRaw)))

  const isTranslation = operation === 'translation' || Boolean(
    cleanSourceContent && resolvedSourceLang && resolvedSourceLang !== resolvedTargetLang
  )
  const isBilingualLegacy = generationMode === 'both'
  const estimatedTokens = isBilingualLegacy ? 1000 : 500
  const jobLanguage = isBilingualLegacy ? 'both' : resolvedTargetLang

  const { data, error } = await admin.rpc('create_ai_job', {
    p_user_id: caller.userId,
    p_org_id: orgId,
    p_branch_id: branchId || null,
    p_prompt: trimmed,
    p_system_prompt: systemPrompt || null,
    p_language: jobLanguage,
    p_model: model || null,
    p_tokens_estimated: estimatedTokens,
    p_request_limit: requestLimit,
    p_token_limit: tokenLimit,
  })

  if (error || !data?.id) {
    console.error('[ai/generate] create_ai_job error:', error)
    const message = error?.message || 'Failed to create AI job'
    if (message.startsWith('ai_quota_exceeded')) {
      throw createError({ statusCode: 429, statusMessage: 'AI quota exceeded for this period' })
    }
    if (message.startsWith('ai_invalid_branch')) {
      throw createError({ statusCode: 400, statusMessage: 'Invalid branch for this organization' })
    }
    if (message.startsWith('ai_invalid_limit')) {
      throw createError({ statusCode: 400, statusMessage: 'Invalid AI limits' })
    }
    if (message.startsWith('ai_unauthorized')) {
      throw createError({ statusCode: 403, statusMessage: 'Not a member of this organization' })
    }
    throw createError({ statusCode: 500, statusMessage: message })
  }

  // Honest, bounded background work: Nitro's event.waitUntil is awaited by the
  // worker as fast as possible, and inference carries its own hard cap.
  event.waitUntil(
    runInference({
      jobId: data.id,
      userId: caller.userId,
      orgId,
      prompt: trimmed,
      generationMode: isBilingualLegacy ? 'both' : 'current',
      operation: isTranslation ? 'translation' : 'generation',
      editorContent: cleanEditorContent,
      sourceContent: cleanSourceContent,
      sourceLanguage: resolvedSourceLang,
      targetLanguage: resolvedTargetLang,
      systemPrompt: systemPrompt || null,
      language: jobLanguage,
      model: model || null,
    })
  )

  return {
    jobId: data.id,
    status: data.status,
    periodMonth: data.period_month,
  }
})
