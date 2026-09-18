import type { Database } from '~/types/database'
import type { AuthBootstrapStatus } from '~/types/subscription'

type Organization = Database['public']['Tables']['organizations']['Row']

export const useTenantBootstrap = () => {
  const currentOrg = useState<Organization | null>('current_org', () => null)
  const bootstrapStatus = useState<AuthBootstrapStatus>('bootstrap_status', () => 'idle')
  const bootstrapError = useState<string | null>('bootstrap_error', () => null)

  const { user, profile, fetchProfile, signOut } = useUser()
  const { fetchSubscription, clearSubscription } = useSubscription()
  const supabase = useSupabaseClient<Database>()

  const bootstrap = async (force = false): Promise<boolean> => {
    if (!user.value) {
      bootstrapStatus.value = 'unauthenticated'
      currentOrg.value = null
      clearSubscription()
      return false
    }

    if (!force && bootstrapStatus.value === 'authenticated' && currentOrg.value) {
      return true
    }

    bootstrapStatus.value = 'loading'
    bootstrapError.value = null

    try {
      // 1. Ensure profile is loaded
      await fetchProfile()

      // If user profile is not found or has no organization_id
      if (!profile.value?.organization_id) {
        bootstrapStatus.value = 'unassigned'
        currentOrg.value = null
        clearSubscription()
        return false
      }

      // 2. Fetch organization record
      const orgId = profile.value.organization_id
      const { data: orgData, error: orgErr } = await supabase
        .from('organizations')
        .select('*')
        .eq('id', orgId)
        .maybeSingle()

      if (orgErr || !orgData) {
        console.error('[useTenantBootstrap] Organization query failed:', orgErr)
        bootstrapStatus.value = 'error'
        bootstrapError.value = 'Failed to load organization'
        currentOrg.value = null
        clearSubscription()
        return false
      }

      currentOrg.value = orgData

      // 3. Load subscription state for the tenant
      await fetchSubscription(force)

      bootstrapStatus.value = 'authenticated'
      return true
    } catch (err: any) {
      console.error('[useTenantBootstrap] Bootstrap error:', err)
      bootstrapStatus.value = 'error'
      bootstrapError.value = err?.message || 'Bootstrap initialization failed'
      return false
    }
  }

  const resetBootstrap = () => {
    currentOrg.value = null
    bootstrapStatus.value = 'idle'
    bootstrapError.value = null
    clearSubscription()
  }

  return {
    currentOrg: readonly(currentOrg),
    bootstrapStatus: readonly(bootstrapStatus),
    bootstrapError: readonly(bootstrapError),
    bootstrap,
    resetBootstrap,
    signOut,
  }
}
