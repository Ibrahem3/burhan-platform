import { getSupabaseAdmin } from '../../utils/supabase'

export default defineEventHandler(async (event) => {
  try {
    const { title, sourceUrl, turnstileToken, userId } = await readBody(event)

    if (!title || !sourceUrl) {
      throw createError({ statusCode: 400, statusMessage: 'Title and source URL are required' })
    }

    const config = useRuntimeConfig()
    const turnstileSecret = config.turnstile?.secretKey as string

    if (turnstileSecret) {
      const formData = new FormData()
      formData.append('secret', turnstileSecret)
      formData.append('response', turnstileToken || '')

      const result = await $fetch<{ success: boolean }>('https://challenges.cloudflare.com/turnstile/v0/siteverify', {
        method: 'POST',
        body: formData,
      })

      if (!result.success) {
        console.error('[observatory] Turnstile verification failed')
        throw createError({ statusCode: 400, statusMessage: 'Security verification failed' })
      }
    }

    const admin = getSupabaseAdmin()

    const { data: recent } = await admin
      .from('observatory_threats')
      .select('id')
      .eq('source_url', sourceUrl)
      .gte('created_at', new Date(Date.now() - 3_600_000).toISOString())
      .maybeSingle()

    if (recent) {
      throw createError({ statusCode: 429, statusMessage: 'This URL was reported recently' })
    }

    const { data: threat, error } = await admin
      .from('observatory_threats')
      .insert({
        title,
        source_url: sourceUrl,
        reported_by: userId || null,
      })
      .select('id, title, status, platform, created_at')
      .single()

    if (error || !threat) {
      console.error('[observatory] Insert error:', error)
      throw createError({ statusCode: 500, statusMessage: 'Failed to submit report' })
    }

    return { success: true, threat }
  } catch (err: any) {
    console.error('[observatory] Report error:', err)
    throw createError({
      statusCode: err.statusCode || 500,
      statusMessage: err.statusMessage || err.message || 'Internal server error',
    })
  }
})
