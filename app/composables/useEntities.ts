import type { Database } from '~/types/database'

type Entity = Database['public']['Tables']['entities']['Row'] & {
  organizations?: Pick<Database['public']['Tables']['organizations']['Row'], 'name' | 'org_slug' | 'settings'>
  branches?: Pick<Database['public']['Tables']['branches']['Row'], 'name' | 'module_type'>
}

export const useEntities = () => {
  const entities = useState<Entity[]>('entities', () => [])
  const loading = useState<boolean>('entities-loading', () => false)
  const error = useState<string | null>('entities-error', () => null)

  const fetchPublicEntities = async () => {
    loading.value = true
    error.value = null

    try {
      const data = await $fetch<Entity[]>('/api/entities/public')
      entities.value = data ?? []
    } catch (err) {
      error.value = 'Failed to fetch public entities'
      entities.value = []
    } finally {
      loading.value = false
    }
  }

  const fetchOrgEntities = async (orgId: string, branchId?: string) => {
    loading.value = true
    error.value = null

    const supabase = useSupabaseClient<Database>()

    try {
      let query = supabase
        .from('entities')
        .select('*')
        .eq('organization_id', orgId)
        .order('created_at', { ascending: false })

      if (branchId) {
        query = query.eq('branch_id', branchId)
      }

      const { data, error: queryError } = await query

      if (queryError) {
        error.value = queryError.message
        entities.value = []
      } else {
        entities.value = (data ?? []) as unknown as Entity[]
      }
    } catch (err) {
      error.value = 'Failed to fetch organization entities'
      entities.value = []
    } finally {
      loading.value = false
    }
  }

  return {
    entities: readonly(entities),
    loading: readonly(loading),
    error: readonly(error),
    fetchPublicEntities,
    fetchOrgEntities,
  }
}
