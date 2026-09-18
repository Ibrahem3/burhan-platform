export type AiJobStatus = 'idle' | 'pending' | 'processing' | 'completed' | 'failed' | 'cancelled'

export interface AiGenerateOptions {
  prompt: string
  systemPrompt?: string | null
  language?: 'ar' | 'en'
  branchId?: string | null
}

export interface AiJobState {
  status: AiJobStatus
  jobId: string | null
  outputBuffer: string
  outputFinal: string | null
  error: string | null
  tokensUsed: number | null
}

export const useAiGenerate = () => {
  const supabase = useSupabaseClient()
  const { isReadOnly, features } = useSubscription()
  const { isSuperAdmin } = useUser()

  const state = ref<AiJobState>({
    status: 'idle',
    jobId: null,
    outputBuffer: '',
    outputFinal: null,
    error: null,
    tokensUsed: null,
  })

  let pollTimer: ReturnType<typeof setTimeout> | null = null
  let isCancelledByUser = false

  const clearTimer = () => {
    if (pollTimer) {
      clearTimeout(pollTimer)
      pollTimer = null
    }
  }

  const reset = () => {
    clearTimer()
    isCancelledByUser = false
    state.value = {
      status: 'idle',
      jobId: null,
      outputBuffer: '',
      outputFinal: null,
      error: null,
      tokensUsed: null,
    }
  }

  const pollJob = async (jobId: string, retryCount = 0): Promise<void> => {
    if (isCancelledByUser) return

    try {
      const { data: { session } } = await supabase.auth.getSession()
      const headers: Record<string, string> = {}
      if (session?.access_token) {
        headers['Authorization'] = `Bearer ${session.access_token}`
      }

      const res = await $fetch<{
        jobId: string
        status: string
        output: string | null
        streamBuffer: string | null
        error: string | null
        tokensUsed: number | null
      }>(`/api/ai/jobs/${jobId}`, {
        headers,
      })

      if (isCancelledByUser) return

      state.value.status = (res.status as AiJobStatus) || 'processing'
      state.value.outputBuffer = res.streamBuffer || ''
      state.value.outputFinal = res.output || null
      state.value.tokensUsed = res.tokensUsed ?? null

      if (res.status === 'completed') {
        clearTimer()
        return
      }

      if (res.status === 'failed') {
        clearTimer()
        state.value.error = res.error || 'فشلت عملية توليد الذكاء الاصطناعي'
        return
      }

      if (res.status === 'cancelled') {
        clearTimer()
        state.value.error = 'تم إلغاء المهمة'
        return
      }

      // Continue polling while pending or processing
      // Max 60 retries * 1.5s = 90 seconds (matches reap_stale_ai_job threshold)
      if (retryCount < 60) {
        pollTimer = setTimeout(() => {
          pollJob(jobId, retryCount + 1)
        }, 1500)
      } else {
        clearTimer()
        state.value.status = 'failed'
        state.value.error = 'انتهت مهلة انتظار المعالجة، يرجى المحاولة لاحقاً'
      }
    } catch (err: any) {
      if (isCancelledByUser) return
      console.error('[useAiGenerate] Poll error:', err)

      // Allow transient poll failures before failing closed
      if (retryCount < 60) {
        pollTimer = setTimeout(() => {
          pollJob(jobId, retryCount + 1)
        }, 2500)
      } else {
        clearTimer()
        state.value.status = 'failed'
        state.value.error = 'فقد الاتصال بخدمة متابعة حالة المهمة'
      }
    }
  }

  const generate = async (options: AiGenerateOptions): Promise<boolean> => {
    reset()

    // 1. Subscription & Read-Only UX guard
    if (isReadOnly.value && !isSuperAdmin.value) {
      state.value.status = 'failed'
      state.value.error = 'لا يمكن استخدام الذكاء الاصطناعي: الحساب في وضع القراءة فقط.'
      return false
    }

    if (features.value?.ai_generate === false && !isSuperAdmin.value) {
      state.value.status = 'failed'
      state.value.error = 'خاصية الذكاء الاصطناعي غير مفعلة في باقتك الحالية.'
      return false
    }

    const trimmedPrompt = options.prompt?.trim()
    if (!trimmedPrompt) {
      state.value.status = 'failed'
      state.value.error = 'يرجى إدخال تعليمات التوليد أولاً.'
      return false
    }

    // 2. Obtain session token
    const { data: { session } } = await supabase.auth.getSession()
    if (!session?.access_token) {
      state.value.status = 'failed'
      state.value.error = 'انتهت جلستك، يرجى إعادة تسجيل الدخول.'
      return false
    }

    state.value.status = 'pending'

    try {
      // 3. Dispatch generate request to frozen M1 backend endpoint
      const response = await $fetch<{
        jobId: string
        status: string
        periodMonth: string
      }>('/api/ai/generate', {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${session.access_token}`,
        },
        body: {
          prompt: trimmedPrompt,
          systemPrompt: options.systemPrompt || null,
          language: options.language || 'ar',
          branchId: options.branchId || null,
        },
      })

      state.value.jobId = response.jobId
      state.value.status = (response.status as AiJobStatus) || 'processing'

      // 4. Start polling for job completion
      await pollJob(response.jobId)
      return true
    } catch (err: any) {
      console.error('[useAiGenerate] Generation request error:', err)
      state.value.status = 'failed'

      const statusCode = err?.status || err?.statusCode || err?.response?.status
      const rawMessage = err?.data?.statusMessage || err?.message || ''

      if (statusCode === 429 || rawMessage.includes('quota exceeded') || rawMessage.includes('ai_quota_exceeded')) {
        state.value.error = 'لقد تجاوزت الحصة الشهرية المتاحة لتوليد الذكاء الاصطناعي.'
      } else if (statusCode === 402) {
        state.value.error = 'يتطلب اشتراكاً نشطاً لاستخدام التوليد بالذكاء الاصطناعي.'
      } else if (statusCode === 403) {
        state.value.error = 'الذكاء الاصطناعي غير متاح لخطة الاشتراك الحالية أو لا تملك الصلاحية.'
      } else if (statusCode === 503) {
        state.value.error = 'خدمة توليد الذكاء الاصطناعي معطلة حالياً للصيانة.'
      } else {
        state.value.error = 'فشل في إنشاء مهمة الذكاء الاصطناعي، يرجى المحاولة لاحقاً.'
      }
      return false
    }
  }

  const cancel = () => {
    isCancelledByUser = true
    clearTimer()
    state.value.status = 'cancelled'
    state.value.error = 'تم إلغاء العملية.'
  }

  const consume = async (jobId: string): Promise<boolean> => {
    try {
      const { data: { session } } = await supabase.auth.getSession()
      if (!session?.access_token) return false

      const res = await $fetch<{ consumed: boolean }>(`/api/ai/jobs/${jobId}/consume`, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${session.access_token}`,
        },
      })
      return res?.consumed === true
    } catch (err) {
      console.error('[useAiGenerate] Consume error:', err)
      return false
    }
  }

  onBeforeUnmount(() => {
    clearTimer()
  })

  return {
    state: readonly(state),
    generate,
    cancel,
    reset,
    consume,
  }
}
