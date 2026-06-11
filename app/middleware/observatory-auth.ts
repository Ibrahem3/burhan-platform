import type { Database } from '~/types/database'

export default defineNuxtRouteMiddleware(async (_to, _from) => {
  const user = useSupabaseUser()

  if (!user.value) {
    return navigateTo('/login')
  }

  const supabase = useSupabaseClient<Database>()

  const [analystResult, profileResult] = await Promise.all([
    supabase
      .from('observatory_analysts')
      .select('role_type')
      .eq('id', user.value.id)
      .maybeSingle(),
    supabase
      .from('profiles')
      .select('role')
      .eq('id', user.value.id)
      .maybeSingle(),
  ])

  const isSuperAdmin = profileResult.data?.role === 'super_admin'
  const hasObservatoryRole = !!analystResult.data

  if (!isSuperAdmin && !hasObservatoryRole) {
    return navigateTo('/')
  }
})
