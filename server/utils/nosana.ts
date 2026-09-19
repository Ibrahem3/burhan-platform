import { getSupabaseAdmin } from './supabase.ts'
import { decryptSecret } from './crypto.ts'
import { validateProviderEndpointPolicy, safeProviderFetch } from './ssrf.ts'
import {
  buildEditorialMessages,
  validateEditorialOutput,
  EDITORIAL_LIMITS,
  type GenerationMode,
  type EditorialOperation,
} from './editorial.ts'

export interface RunInferenceInput {
  jobId: string
  userId: string
  orgId?: string
  prompt: string
  generationMode?: GenerationMode
  operation?: EditorialOperation
  editorContent?: string | null
  sourceContent?: string | null
  sourceLanguage?: 'ar' | 'en' | null
  targetLanguage?: 'ar' | 'en' | null
  systemPrompt?: string | null
  language?: string
  model?: string | null
}

export interface ParsedSseChunk {
  content?: string
  reasoning?: string
  finishReason?: string
  totalTokens?: number
  promptTokens?: number
  completionTokens?: number
}

export interface NosanaConfig {
  apiEndpoint: string
  clusterKey: string
  defaultModel: string
}

export function getNosanaConfig(): NosanaConfig {
  const config = useRuntimeConfig()
  const apiEndpoint = (config.nosana?.apiEndpoint as string) || process.env.NUXT_NOSANA_API_ENDPOINT || 'https://inference.nosana.com'
  const clusterKey = (config.nosana?.clusterKey as string) || process.env.NUXT_NOSANA_CLUSTER_KEY || ''
  const defaultModel = (config.nosana?.defaultModel as string) || process.env.NUXT_NOSANA_DEFAULT_MODEL || 'qwen/qwen3.8-27b'

  return {
    apiEndpoint,
    clusterKey,
    defaultModel,
  }
}

export function parseSseEvent(lines: string): ParsedSseChunk | null {
  for (const line of lines.split('\n')) {
    if (!line.startsWith('data:')) continue
    const payload = line.slice(5).trim()
    if (payload === '[DONE]') return null
    try {
      const parsed = JSON.parse(payload)
      if (!parsed || typeof parsed !== 'object') return null

      let content: string | undefined
      let reasoning: string | undefined
      let finishReason: string | undefined

      // OpenAI/vLLM/Nosana standard shape: choices[0].delta
      const choice = Array.isArray(parsed.choices) && parsed.choices[0]
      if (choice) {
        if (typeof choice.finish_reason === 'string') {
          finishReason = choice.finish_reason
        }
        if (choice.delta) {
          if (typeof choice.delta.content === 'string') {
            content = choice.delta.content
          }
          if (typeof choice.delta.reasoning === 'string') {
            reasoning = choice.delta.reasoning
          }
        }
      } else if (typeof parsed.content === 'string') {
        // Fallback for flat streams
        content = parsed.content
      }

      let totalTokens: number | undefined
      let promptTokens: number | undefined
      let completionTokens: number | undefined

      if (parsed.usage) {
        if (typeof parsed.usage.total_tokens === 'number' && parsed.usage.total_tokens >= 0) {
          totalTokens = parsed.usage.total_tokens
        }
        if (typeof parsed.usage.prompt_tokens === 'number' && parsed.usage.prompt_tokens >= 0) {
          promptTokens = parsed.usage.prompt_tokens
        }
        if (typeof parsed.usage.completion_tokens === 'number' && parsed.usage.completion_tokens >= 0) {
          completionTokens = parsed.usage.completion_tokens
        }
      }

      if (
        content !== undefined ||
        reasoning !== undefined ||
        finishReason !== undefined ||
        totalTokens !== undefined
      ) {
        return { content, reasoning, finishReason, totalTokens, promptTokens, completionTokens }
      }
      return null
    } catch {
      return null
    }
  }
  return null
}

/**
 * Sanitize error messages from upstream providers to strictly prevent
 * any leaking of Authorization headers, API keys, or raw tokens.
 */
function sanitizeProviderError(status: number, rawDetail: string): string {
  if (status >= 300 && status < 400) {
    return 'AI provider returned an unsupported redirect; automatic redirects are disabled for security'
  }
  if (status === 401 || status === 403) {
    return 'AI provider authentication failed: invalid or revoked credential'
  }
  if (status === 429) {
    return 'AI provider rate limit or quota exceeded'
  }
  if (status >= 500) {
    return 'AI provider temporary server error'
  }
  // Strip any potential bearer/token strings from detail
  const cleaned = (rawDetail || '')
    .replace(/bearer\s+[a-zA-Z0-9_\-\.]+/gi, 'Bearer [REDACTED]')
    .replace(/sk-[a-zA-Z0-9]+/gi, '[REDACTED]')
    .slice(0, 200)
  return `AI provider request failed (${status}): ${cleaned}`
}

/**
 * Runs one inference job against a chosen provider (Tenant BYOK or Platform Nosana).
 *
 * Responsibilities:
 *  - Claims the job (pending -> processing) with the atomic RPC
 *  - Resolves active tenant BYOK credential or falls back to platform Nosana
 *  - Streams the SSE response, buffering `output_buffer`
 *  - Heartbeat debounced to ~3s so `last_heartbeat_at` reflects liveness
 *  - Terminates atomically (complete/fail) which ALSO reconciles quota
 *
 * Plaintext Lifetime Invariant:
 *  Decrypted API keys live strictly in local function variables during the fetch call
 *  and are never logged, persisted, or returned to clients.
 */
export async function runInference(input: RunInferenceInput): Promise<void> {
  const admin = getSupabaseAdmin() as any

  const claim = await admin.rpc('start_ai_job', {
    p_job_id: input.jobId,
    p_user_id: input.userId,
    p_model: input.model,
  })

  if (claim.error || claim.data?.changed !== true) {
    return
  }

  // 1. Resolve Provider Credentials (BYOK vs Platform)
  let endpoint = ''
  let apiKey = ''
  let resolvedModel = input.model || ''
  let providerType = 'platform_nosana'

  // Attempt to load active tenant BYOK if organization ID is known
  let targetOrgId = input.orgId
  if (!targetOrgId) {
    const { data: jobRow } = await admin
      .from('ai_jobs')
      .select('organization_id')
      .eq('id', input.jobId)
      .maybeSingle()
    targetOrgId = jobRow?.organization_id
  }

  if (targetOrgId) {
    const { data: byok, error: byokError } = await admin
      .from('tenant_ai_credentials')
      .select('provider, encrypted_key, key_iv, key_tag, key_version, base_url, custom_model')
      .eq('organization_id', targetOrgId)
      .eq('is_active', true)
      .order('created_at', { ascending: false })
      .limit(1)
      .maybeSingle()

    if (!byokError && byok) {
      try {
        // Enforce runtime deployment & provider endpoint policy
        const policy = await validateProviderEndpointPolicy(byok.provider, byok.base_url)
        if (!policy.allowed) {
          console.error(`[runInference] Runtime BYOK policy rejection for provider '${byok.provider}': ${policy.error}`)
          await admin.rpc('fail_ai_job', {
            p_job_id: input.jobId,
            p_user_id: input.userId,
            p_error: 'Tenant AI provider configuration is invalid or disallowed by platform policy',
          })
          return
        }

        apiKey = decryptSecret(byok.encrypted_key, byok.key_iv, byok.key_tag, byok.key_version)
        providerType = `byok_${byok.provider}`

        if (policy.endpoint) {
          endpoint = policy.endpoint.replace(/\/+$/, '')
        } else {
          const cfg = getNosanaConfig()
          endpoint = cfg.apiEndpoint.replace(/\/+$/, '')
        }

        if (!resolvedModel) {
          resolvedModel = byok.custom_model || (byok.provider === 'openai' ? 'gpt-4o-mini' : '')
        }
      } catch (decryptErr: any) {
        console.error('[runInference] failed to decrypt tenant BYOK credential:', decryptErr?.message)
        await admin.rpc('fail_ai_job', {
          p_job_id: input.jobId,
          p_user_id: input.userId,
          p_error: 'Failed to decrypt tenant AI credentials',
        })
        return
      }
    }
  }

  // Fallback to platform Nosana if no active BYOK resolved
  if (!apiKey) {
    const cfg = getNosanaConfig()
    endpoint = cfg.apiEndpoint.replace(/\/+$/, '')
    apiKey = cfg.clusterKey
    if (!resolvedModel) {
      resolvedModel = cfg.defaultModel
    }

    if (!endpoint || !apiKey) {
      await admin.rpc('fail_ai_job', {
        p_job_id: input.jobId,
        p_user_id: input.userId,
        p_error: 'AI inference is not configured (no active BYOK or platform provider)',
      })
      return
    }
  }

  const model = resolvedModel || 'default'
  const targetLang = (input.targetLanguage || (input.language === 'en' ? 'en' : 'ar')) as 'ar' | 'en'
  const isTranslationOp = input.operation === 'translation' || Boolean(
    input.sourceContent && input.sourceLanguage && input.sourceLanguage !== targetLang
  )

  const messages = buildEditorialMessages({
    instruction: input.prompt,
    generationMode: input.generationMode,
    operation: isTranslationOp ? 'translation' : 'generation',
    editorContent: input.editorContent,
    sourceContent: input.sourceContent,
    sourceLanguage: input.sourceLanguage,
    targetLanguage: targetLang,
    systemPromptOverride: input.systemPrompt,
    interfaceLanguage: targetLang,
  })

  const maxTokens = EDITORIAL_LIMITS.MAX_OUTPUT_TOKENS

  const controller = new AbortController()
  const hardCapMs = 120000
  const timer = setTimeout(() => controller.abort(new Error('Inference exceeded the hard time cap (120s)')), hardCapMs)

  let buffer = ''
  let lastHeartbeat = 0
  let tokensUsed: number | null = null
  let promptTokens: number | null = null
  let completionTokens: number | null = null
  let finishReason: string | null = null

  const heartbeat = async () => {
    lastHeartbeat = Date.now()
    await admin.rpc('heartbeat_ai_job', {
      p_job_id: input.jobId,
      p_user_id: input.userId,
      p_output_buffer: buffer,
    })
  }

  try {
    await heartbeat()

    const targetUrl = `${endpoint}/v1/chat/completions`

    const res = await safeProviderFetch(targetUrl, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${apiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model,
        messages,
        stream: true,
        max_tokens: maxTokens,
      }),
      signal: controller.signal,
    })

    if (!res.ok || !res.body) {
      const detail = await res.text().catch(() => '')
      const sanitizedError = sanitizeProviderError(res.status, detail)
      await admin.rpc('fail_ai_job', {
        p_job_id: input.jobId,
        p_user_id: input.userId,
        p_error: sanitizedError,
      })
      return
    }

    const reader = res.body.getReader()
    const decoder = new TextDecoder()
    let chunk = ''

    // eslint-disable-next-line no-constant-condition
    while (true) {
      const { done, value } = await reader.read()
      if (done) break

      chunk += decoder.decode(value, { stream: true })
      const events = chunk.split('\n\n')
      chunk = events.pop() || ''

      for (const evt of events) {
        const delta = parseSseEvent(evt)
        if (!delta) continue

        if (typeof delta.content === 'string' && delta.content.length > 0) {
          buffer += delta.content
        }
        if (delta.finishReason) {
          finishReason = delta.finishReason
        }
        if (typeof delta.totalTokens === 'number') {
          tokensUsed = delta.totalTokens
        }
        if (typeof delta.promptTokens === 'number') {
          promptTokens = delta.promptTokens
        }
        if (typeof delta.completionTokens === 'number') {
          completionTokens = delta.completionTokens
        }

        // Keep liveness heartbeat active even during pure reasoning phases
        if (Date.now() - lastHeartbeat >= 3000) {
          await heartbeat()
        }
      }
    }

    if (Date.now() - lastHeartbeat >= 3000) {
      await heartbeat()
    }

    // Server-side validation contract before marking completed
    const validation = validateEditorialOutput(buffer, {
      isTranslation: isTranslationOp,
      targetLanguage: targetLang,
      finishReason,
    })

    if (!validation.valid) {
      const validationError = validation.error || 'Editorial output validation failed'
      console.warn(`[runInference] AI job ${input.jobId} validation failed: ${validationError}`)
      await admin.rpc('fail_ai_job', {
        p_job_id: input.jobId,
        p_user_id: input.userId,
        p_error: validationError,
      })
      return
    }

    const validatedFinal = validation.cleanContent || buffer

    // Structured observability logging (sanitized, non-sensitive)
    console.log(
      `[runInference] Completed AI job ${input.jobId}: ` +
      `model=${model}, operation=${isTranslationOp ? 'translation' : 'generation'}, ` +
      `finishReason=${finishReason || 'stop'}, promptTokens=${promptTokens ?? 'n/a'}, ` +
      `completionTokens=${completionTokens ?? 'n/a'}, totalTokens=${tokensUsed ?? 'n/a'}, ` +
      `outputLength=${validatedFinal.length}`
    )

    await admin.rpc('complete_ai_job', {
      p_job_id: input.jobId,
      p_user_id: input.userId,
      p_tokens_used: tokensUsed,
      p_output_final: validatedFinal,
    })
  } catch (err: any) {
    const errorMsg = (err?.message || 'Inference failed')
      .replace(/bearer\s+[a-zA-Z0-9_\-\.]+/gi, 'Bearer [REDACTED]')
      .slice(0, 300)

    await admin.rpc('fail_ai_job', {
      p_job_id: input.jobId,
      p_user_id: input.userId,
      p_error: errorMsg,
    })
  } finally {
    clearTimeout(timer)
  }
}
