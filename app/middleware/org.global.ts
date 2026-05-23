const PUBLIC_ROUTES = ['/login', '/signup', '/dashboard']

function isPublicRoute(path: string) {
  return PUBLIC_ROUTES.some(route => path.startsWith(route))
}

export default defineNuxtRouteMiddleware(async (to, _from) => {
  const orgSlug = to.params.org_slug as string | undefined

  if (isPublicRoute(to.path)) {
    return
  }

  if (!orgSlug) {
    return
  }

  const { fetchOrg, error } = useOrg()
  const { $i18n } = useNuxtApp()
  const currentLocale = to.path.startsWith('/en/') ? 'en' : 'ar'

  await fetchOrg(orgSlug)

  if (error.value) {
    const user = useSupabaseUser()

    if (user.value) {
      const supabase = useSupabaseClient()
      const { data: profile } = await supabase
        .from('profiles')
        .select('organization_id')
        .eq('id', user.value.id)
        .maybeSingle()

      if (profile?.organization_id) {
        const { data: fallbackOrg } = await supabase
          .from('organizations')
          .select('id, name, org_slug, settings')
          .eq('id', profile.organization_id)
          .maybeSingle()

        if (fallbackOrg) {
          useState('org').value = fallbackOrg
          const fallbackName = fallbackOrg.name as Record<string, string>
          useHead({
            title: fallbackName[currentLocale] || fallbackName.ar || fallbackName.en || '',
          })
          return
        }
      }
    }

    throw createError({
      statusCode: 404,
      statusMessage: $i18n.t('common.org_not_found'),
      fatal: true,
    })
  }

  const org = useState<any>('org').value
  if (org?.name) {
    useHead({
      link: [
        {
          rel: 'canonical',
          href: `https://burhan.ainux.online/${org.org_slug}`,
        },
      ],
    })
  }
})
