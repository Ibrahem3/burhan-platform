import { getSupabaseClient } from '../../utils/supabase'

export default defineEventHandler(async (event) => {
  const slug = getRouterParam(event, 'slug')

  if (!slug) {
    throw createError({ statusCode: 400, statusMessage: 'Slug is required' })
  }

  const supabase = getSupabaseClient()

  const { data: org, error } = await supabase
    .from('organizations')
    .select(`
      id,
      name,
      org_slug,
      settings,
      created_at,
      branches (
        id,
        name,
        module_type,
        created_at
      )
    `)
    .eq('org_slug', slug)
    .single()

  if (error || !org) {
    throw createError({ statusCode: 404, statusMessage: 'Organization not found' })
  }

  return org
})
