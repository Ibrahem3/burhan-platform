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

  await fetchOrg(orgSlug)

  if (error.value) {
    const user = useSupabaseUser()

    if (user.value) {
      const supabase = useSupabaseClient()
      const { data: profile } = await supabase
        .from('profiles')
        .select('organization_id')
        .eq('id', user.value.id)
        .single()

      if (profile?.organization_id) {
        const { data: fallbackOrg } = await supabase
          .from('organizations')
          .select('id, name, org_slug, settings')
          .eq('id', profile.organization_id)
          .single()

        if (fallbackOrg) {
          useState('org').value = fallbackOrg
          useHead({
            title: (fallbackOrg.name as any)?.ar || fallbackOrg.name,
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
      title: org.name,
      link: [
        {
          rel: 'canonical',
          href: `https://burhan.ainux.online/${org.org_slug}`,
        },
      ],
    })
  }
})
