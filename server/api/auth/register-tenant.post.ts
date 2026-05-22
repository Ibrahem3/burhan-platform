import { getSupabaseAdmin } from '../../utils/supabase'

export default defineEventHandler(async (event) => {
  try {
    const admin = getSupabaseAdmin()
    const { accessToken, orgName, orgSlug } = await readBody(event)

    if (!accessToken || !orgName || !orgSlug) {
      throw createError({ statusCode: 400, statusMessage: 'Missing required fields' })
    }

    const { data: { user }, error: userError } = await admin.auth.getUser(accessToken)

    if (userError || !user) {
      throw createError({ statusCode: 401, statusMessage: 'Invalid session' })
    }

    const slug = (orgSlug as string).toLowerCase().replace(/[^a-z0-9-]/g, '')

    if (!slug || slug.length < 2) {
      throw createError({ statusCode: 400, statusMessage: 'Invalid organization slug' })
    }

    const { data: existingOrg } = await admin
      .from('organizations')
      .select('id')
      .eq('org_slug', slug)
      .maybeSingle()

    if (existingOrg) {
      throw createError({ statusCode: 409, statusMessage: 'Slug already taken' })
    }

    const { data: org, error: orgError } = await admin
      .from('organizations')
      .insert({
        name: { ar: orgName, en: orgName },
        org_slug: slug,
        settings: {},
      })
      .select('id, org_slug')
      .single()

    if (orgError || !org?.id) {
      throw createError({ statusCode: 500, statusMessage: 'Failed to create organization' })
    }

    const { data: branch, error: branchError } = await admin
      .from('branches')
      .insert({
        organization_id: org.id,
        name: { ar: 'الفرع الرئيسي', en: 'Main Branch' },
        module_type: 'content',
      })
      .select('id, organization_id')
      .single()

    if (branchError || !branch?.id) {
      throw createError({ statusCode: 500, statusMessage: 'Failed to create default branch' })
    }

    const { error: profileError } = await admin
      .from('profiles')
      .update({
        organization_id: org.id,
        role: 'owner',
      })
      .eq('id', user.id)

    if (profileError) {
      throw createError({ statusCode: 500, statusMessage: 'Failed to update profile' })
    }

    return { org, branch }
  } catch (err: any) {
    throw createError({
      statusCode: err.statusCode || 500,
      statusMessage: err.statusMessage || 'Internal server error',
    })
  }
})
