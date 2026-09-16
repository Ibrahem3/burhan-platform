import { getSupabaseAdmin } from './supabase'

export interface RunInferenceInput {
  jobId: string
  userId: string
  prompt: string
  systemPrompt?: string | null
  language?: string
  model?: string | null
}

interface ChatDelta {
  content?: string
  role?: string
}

export interface NosanaConfig {
  apiEndpoint: string
  clusterKey: string
  defaultModel: string
}

export function getNosanaConfig(): NosanaConfig {
  const config = useRuntimeConfig()
  return {
    apiEndpoint: (config.nosana?.apiEndpoint as string) || '',
    clusterKey: (config.nosana?.clusterKey as string) || '',
    defaultModel: (config.nosana?.defaultModel as string) || '',
  }
}

function parseSseEvent(lines: string): ChatDelta | null {
  for (const line of lines.split('\n')) {
    if (!line.startsWith('data:')) continue
    const payload = line.slice(5).trim()
    if (payload === '[DONE]') return null
    try {
      return JSON.parse(payload) as ChatDelta
    } catch {
      return null
    }
  }
  return null
}

/**
 * Runs one inference job against a Nosana (OpenAI-compatible) chat endpoint.
 *
 * Responsibilities:
 *  - Claims the job (pending -> processing) with the atomic RPC
 *  - Streams the SSE response, buffering `output_buffer`
 *  - Heartbeat debounced to ~3s so `last_heartbeat_at` reflects liveness
 *  - Terminates atomically (complete/fail) which ALSO reconciles quota
 *
 * All lifecycle transitions go through the SECURITY DEFINER RPCs
 * (granted to the service role only).
 */
export async function runInference(input: RunInferenceInput): Promise<void> {
  // The repo's Database-generic typed client resolves every RPC to `never`
  // (pre-existing, repo-wide). Service RPCs are intentionally untyped here.
  const admin = getSupabaseAdmin() as any

  const claim = await admin.rpc('start_ai_job', {
    p_job_id: input.jobId,
    p_user_id: input.userId,
    p_model: input.model,
  })

  if (claim.error || claim.data?.changed !== true) {
    return
  }

  const cfg = getNosanaConfig()
  const endpoint = cfg.apiEndpoint.replace(/\/+$/, '')
  if (!endpoint || !cfg.clusterKey) {
    await admin.rpc('fail_ai_job', {
      p_job_id: input.jobId,
      p_user_id: input.userId,
      p_error: 'Nosana inference is not configured',
    })
    return
  }

  const model = input.model || cfg.defaultModel
  const messages = []
  if (input.systemPrompt?.trim()) {
    messages.push({ role: 'system', content: input.systemPrompt.trim() })
  }
  if (input.language) {
    messages.push({ role: 'system', content: `Respond in language: ${input.language}` })
  }
  messages.push({ role: 'user', content: input.prompt })

  const controller = new AbortController()
  const hardCapMs = 120000
  const timer = setTimeout(() => controller.abort(new Error('Inference exceeded the hard time cap (120s)')), hardCapMs)

  let buffer = ''
  let lastHeartbeat = 0
  let tokensUsed: number | null = null

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

    const res = await fetch(`${endpoint}/v1/chat/completions`, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${cfg.clusterKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model,
        messages,
        stream: true,
      }),
      signal: controller.signal,
    })

    if (!res.ok || !res.body) {
      const detail = await res.text().catch(() => '')
      await admin.rpc('fail_ai_job', {
        p_job_id: input.jobId,
        p_user_id: input.userId,
        p_error: `Nosana request failed (${res.status}): ${detail.slice(0, 200)}`,
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
          if (Date.now() - lastHeartbeat >= 3000) {
            await heartbeat()
          }
        }
      }
    }

    if (Date.now() - lastHeartbeat >= 3000) {
      await heartbeat()
    }

    await admin.rpc('complete_ai_job', {
      p_job_id: input.jobId,
      p_user_id: input.userId,
      p_tokens_used: tokensUsed,
      p_output_final: buffer,
    })
  } catch (err: any) {
    await admin.rpc('fail_ai_job', {
      p_job_id: input.jobId,
      p_user_id: input.userId,
      p_error: (err?.message || 'Inference failed').slice(0, 300),
    })
  } finally {
    clearTimeout(timer)
  }
}