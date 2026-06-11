import { getSupabaseAdmin } from '../../utils/supabase'

export default defineEventHandler(async (event) => {
  try {
    const admin = getSupabaseAdmin()

    const [orgsResult, branchesResult, usersResult] = await Promise.all([
      admin.from('organizations').select('id, name, org_slug, created_at', { count: 'exact' }).order('created_at', { ascending: false }),
      admin.from('branches').select('id', { count: 'exact' }),
      admin.from('profiles').select('id', { count: 'exact' }),
    ])

    const orgs = orgsResult.data || []
    const totalOrgs = orgsResult.count || orgs.length
    const totalBranches = branchesResult.count || 0
    const totalUsers = usersResult.count || 0

    const orgsWithBranchCount = await Promise.all(
      orgs.map(async (org) => {
        const { count } = await admin
          .from('branches')
          .select('id', { count: 'exact', head: true })
          .eq('organization_id', org.id)

        return {
          id: org.id,
          name: org.name,
          org_slug: org.org_slug,
          created_at: org.created_at,
          branch_count: count || 0,
        }
      })
    )

    return {
      stats: {
        totalOrgs,
        totalBranches,
        totalUsers,
      },
      organizations: orgsWithBranchCount,
    }
  } catch (err: any) {
    console.error('[admin] Stats error:', err)
    throw createError({
      statusCode: 500,
      statusMessage: err.message || 'Internal server error',
    })
  }
})
