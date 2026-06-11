import { getSupabaseAdmin } from '../../utils/supabase'

export default defineEventHandler(async (event) => {
  try {
    const { email, roleType, accessToken } = await readBody(event)

    if (!email || !roleType) {
      throw createError({ statusCode: 400, statusMessage: 'Email and role type are required' })
    }

    if (!['observatory_manager', 'observatory_analyst'].includes(roleType)) {
      throw createError({ statusCode: 400, statusMessage: 'Invalid role type' })
    }

    const admin = getSupabaseAdmin()

    const { data: { user: caller }, error: callerError } = await admin.auth.getUser(accessToken)

    if (callerError || !caller) {
      throw createError({ statusCode: 401, statusMessage: 'Unauthorized' })
    }

    const [analystCheck, profileCheck] = await Promise.all([
      admin.from('observatory_analysts').select('role_type').eq('id', caller.id).maybeSingle(),
      admin.from('profiles').select('role').eq('id', caller.id).maybeSingle(),
    ])

    const isManager = analystCheck.data?.role_type === 'observatory_manager'
    const isSuperAdmin = profileCheck.data?.role === 'super_admin'

    if (!isManager && !isSuperAdmin) {
      throw createError({ statusCode: 403, statusMessage: 'Forbidden' })
    }

    const url = useRuntimeConfig().public.supabase?.url as string
    const serviceKey = useRuntimeConfig().supabase?.serviceKey as string

    const { users } = await $fetch<{ users: { id: string; email: string }[] }>(
      `${url}/auth/v1/admin/users`,
      {
        headers: {
          apikey: serviceKey,
          Authorization: `Bearer ${serviceKey}`,
        },
      }
    )

    if (!users?.length) {
      throw createError({ statusCode: 500, statusMessage: 'Failed to look up user' })
    }

    const targetUser = users.find(u => u.email === email.toLowerCase().trim())
    if (!targetUser) {
      throw createError({ statusCode: 404, statusMessage: 'No user found with this email' })
    }

    const existing = await admin
      .from('observatory_analysts')
      .select('id')
      .eq('id', targetUser.id)
      .maybeSingle()

    if (existing.data) {
      throw createError({ statusCode: 409, statusMessage: 'User is already an analyst' })
    }

    const { error: insertError } = await admin
      .from('observatory_analysts')
      .insert({ id: targetUser.id, role_type: roleType })

    if (insertError) {
      console.error('[observatory] Insert analyst error:', insertError)
      throw createError({ statusCode: 500, statusMessage: 'Failed to add analyst' })
    }

    return { success: true, userId: targetUser.id, email: targetUser.email, roleType }
  } catch (err: any) {
    console.error('[observatory] Add analyst error:', err)
    throw createError({
      statusCode: err.statusCode || 500,
      statusMessage: err.statusMessage || err.message || 'Internal server error',
    })
  }
})
