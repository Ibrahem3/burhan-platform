import { getSupabaseClient } from '../../utils/supabase'

export default defineEventHandler(async (event) => {
  const supabase = getSupabaseClient()

  const { data: entities, error } = await supabase
    .from('entities')
    .select(`
      id,
      title,
      content,
      is_public_to_hub,
      is_premium,
      price,
      video_id,
      primary_source,
      fallback_source,
      fallback_url,
      created_at,
      branch_id,
      organization_id,
      organizations (
        name,
        org_slug,
        settings
      )
    `)
    .eq('is_public_to_hub', true)
    .eq('is_premium', false)
    .order('created_at', { ascending: false })
    .limit(50)

  if (error) {
    throw createError({ statusCode: 500, statusMessage: 'Failed to fetch public entities' })
  }

  return entities ?? []
})
