export default defineNuxtRouteMiddleware(async (_to, _from) => {
  const user = useSupabaseUser()

  if (!user.value) {
    return navigateTo('/login')
  }

  const supabase = useSupabaseClient()

  const { data: profile } = await supabase
    .from('profiles')
    .select('role')
    .eq('id', user.value.id)
    .maybeSingle()

  if (!profile || profile.role !== 'super_admin') {
    return navigateTo('/')
  }
})
