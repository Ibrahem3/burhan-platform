import type { SubscriptionResponse, SubscriptionStatus } from '~/types/subscription'

export const useSubscription = () => {
  const subscription = useState<SubscriptionResponse | null>('subscription_state', () => null)
  const loading = useState<boolean>('subscription_loading', () => false)
  const error = useState<string | null>('subscription_error', () => null)
  const lastFetchedAt = useState<number | null>('subscription_last_fetched', () => null)

  const { profile } = useUser()
  const supabase = useSupabaseClient()

  const orgId = computed(() => profile.value?.organization_id)

  const fetchSubscription = async (force = false) => {
    // Need an organization context to fetch subscription
    if (!orgId.value) {
      subscription.value = null
      error.value = null
      return null
    }

    // Cache deduplication: if already fetched for this org and not forced, return cached
    const now = Date.now()
    if (!force && subscription.value && lastFetchedAt.value && (now - lastFetchedAt.value < 60000)) {
      return subscription.value
    }

    // Avoid redundant concurrent in-flight requests
    if (loading.value) {
      return subscription.value
    }

    loading.value = true
    error.value = null

    try {
      const { data: { session } } = await supabase.auth.getSession()
      const headers: Record<string, string> = {}
      if (session?.access_token) {
        headers['Authorization'] = `Bearer ${session.access_token}`
      }

      const res = await $fetch<SubscriptionResponse>('/api/org/subscription', {
        headers,
      })

      subscription.value = res
      lastFetchedAt.value = Date.now()
      return res
    } catch (err: any) {
      console.error('[useSubscription] Failed to load subscription state:', err)
      const msg = err?.data?.statusMessage || err?.message || 'Failed to fetch subscription'
      error.value = msg
      return null
    } finally {
      loading.value = false
    }
  }

  const clearSubscription = () => {
    subscription.value = null
    loading.value = false
    error.value = null
    lastFetchedAt.value = null
  }

  const status = computed<SubscriptionStatus>(() => subscription.value?.status ?? 'none')
  const isExpired = computed<boolean>(() => Boolean(subscription.value?.isExpired || subscription.value?.status === 'expired'))
  const isActive = computed<boolean>(() => subscription.value?.status === 'active' && !isExpired.value)
  const isCancelled = computed<boolean>(() => subscription.value?.status === 'cancelled')
  const isReadOnly = computed<boolean>(() => isExpired.value || isCancelled.value || status.value === 'none')

  const plan = computed(() => subscription.value?.plan ?? null)
  const features = computed(() => subscription.value?.features ?? {})
  const limits = computed(() => subscription.value?.limits ?? {})
  const usage = computed(() => subscription.value?.usage ?? { aiRequestsThisMonth: 0, branchesCount: 0 })

  const maxBranches = computed(() => limits.value.max_branches ?? 1)
  const branchesUsed = computed(() => usage.value.branchesCount ?? 0)
  const canCreateBranch = computed(() => {
    if (isReadOnly.value) return false
    if (maxBranches.value === -1) return true
    return branchesUsed.value < maxBranches.value
  })

  return {
    subscription: readonly(subscription),
    loading: readonly(loading),
    error: readonly(error),
    status,
    isActive,
    isExpired,
    isCancelled,
    isReadOnly,
    plan,
    features,
    limits,
    usage,
    canCreateBranch,
    fetchSubscription,
    clearSubscription,
  }
}
