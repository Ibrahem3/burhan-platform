import type { Database } from '~/types/database'

type Organization = Database['public']['Tables']['organizations']['Row'] & {
  branches: Database['public']['Tables']['branches']['Row'][]
}

export const useOrg = () => {
  const org = useState<Organization | null>('org', () => null)
  const loading = useState<boolean>('org-loading', () => false)
  const error = useState<string | null>('org-error', () => null)
  const lastSlug = useState<string | null>('org-last-slug', () => null)

  async function fetchOrg(slug: string) {
    if (lastSlug.value === slug && org.value) {
      return org.value
    }

    loading.value = true
    error.value = null

    try {
      const data = await $fetch<Organization>(`/api/orgs/${encodeURIComponent(slug)}`)
      org.value = data
      lastSlug.value = slug
      return data
    } catch (err) {
      error.value = 'org_not_found'
      org.value = null
      lastSlug.value = null
      return null
    } finally {
      loading.value = false
    }
  }

  function clearOrg() {
    org.value = null
    error.value = null
    lastSlug.value = null
  }

  const branches = computed(() => org.value?.branches ?? [])

  const orgName = computed(() => org.value?.name ?? '')

  const orgSlug = computed(() => org.value?.org_slug ?? '')

  return {
    org: readonly(org),
    loading: readonly(loading),
    error: readonly(error),
    branches,
    orgName,
    orgSlug,
    fetchOrg,
    clearOrg,
  }
}
