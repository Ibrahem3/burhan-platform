export default defineNuxtRouteMiddleware(async (to, from) => {
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

  if (!profile || profile.role === 'member') {
    return navigateTo('/')
  }
})
