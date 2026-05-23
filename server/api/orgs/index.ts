import { getSupabaseClient } from '../../utils/supabase'

export default defineEventHandler(async (event) => {
  const supabase = getSupabaseClient()

  const { data: orgs, error } = await supabase
    .from('organizations')
    .select(`
      id,
      name,
      org_slug,
      settings,
      created_at
    `)
    .order('created_at', { ascending: false })

  if (error) {
    throw createError({ statusCode: 500, statusMessage: 'Failed to fetch organizations' })
  }

  if (!orgs || orgs.length === 0) {
    return []
  }

  const orgIds = orgs.map(o => o.id)

  const { data: countData } = await supabase
    .from('entities')
    .select('organization_id')
    .in('organization_id', orgIds)
    .eq('is_public_to_hub', true)

  const countMap: Record<string, number> = {}
  if (countData) {
    for (const row of countData) {
      countMap[row.organization_id] = (countMap[row.organization_id] || 0) + 1
    }
  }

  return orgs.map(org => ({
    ...org,
    content_count: countMap[org.id] || 0,
  }))
})
