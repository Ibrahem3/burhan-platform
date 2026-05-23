import type { Database } from '~/types/database'

type Profile = Database['public']['Tables']['profiles']['Row']

export const useUser = () => {
  const supabase = useSupabaseClient<Database>()
  const user = useSupabaseUser()
  const profile = useState<Profile | null>('profile', () => null)

  const fetchProfile = async () => {
    if (!user.value) {
      profile.value = null
      return
    }

    const { data } = await supabase
      .from('profiles')
      .select('*')
      .eq('id', user.value.id)
      .maybeSingle()

    if (data) {
      profile.value = data
    } else {
      profile.value = null
    }
  }

  const isAuthenticated = computed(() => !!user.value)
  const isSuperAdmin = computed(() => profile.value?.role === 'super_admin')
  const isOwner = computed(() => profile.value?.role === 'owner')
  const isManager = computed(() => profile.value?.role === 'manager')
  const isOrgStaff = computed(() => ['owner', 'manager', 'super_admin'].includes(profile.value?.role ?? ''))

  const signOut = async () => {
    await supabase.auth.signOut()
    profile.value = null
    navigateTo('/')
  }

  watch(user, fetchProfile, { immediate: true })

  return {
    user,
    profile: readonly(profile),
    isAuthenticated,
    isSuperAdmin,
    isOwner,
    isManager,
    isOrgStaff,
    fetchProfile,
    signOut,
  }
}
