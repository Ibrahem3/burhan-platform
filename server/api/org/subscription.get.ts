import { getSupabaseAdmin } from '../../utils/supabase'
import { resolveCaller } from '../../utils/auth'

export default defineEventHandler(async (event) => {
  const caller = await resolveCaller(event)
  const admin = getSupabaseAdmin() as any

  // Caller must belong to an organization
  const { data: profile, error: profileError } = await admin
    .from('profiles')
    .select('organization_id')
    .eq('id', caller.userId)
    .maybeSingle()

  if (profileError || !profile?.organization_id) {
    throw createError({ statusCode: 403, statusMessage: 'User does not belong to an organization' })
  }

  const orgId = profile.organization_id

  // Fetch subscription with plan
  const { data: sub, error: subError } = await admin
    .from('subscriptions')
    .select(`
      id,
      organization_id,
      plan_id,
      status,
      billing_period,
      starts_at,
      expires_at,
      plans (
        slug,
        name,
        features,
        limits,
        is_active
      )
    `)
    .eq('organization_id', orgId)
    .eq('status', 'active')
    .maybeSingle()

  if (subError) {
    console.error('[org/subscription] query error:', subError)
    throw createError({ statusCode: 500, statusMessage: 'Failed to retrieve subscription' })
  }

  const isExpired = Boolean(sub?.expires_at && new Date(sub.expires_at).getTime() <= Date.now())
  const effectiveStatus = !sub ? 'none' : isExpired ? 'expired' : sub.status

  // Current month string YYYY-MM for AI usage
  const currentPeriod = new Date().toISOString().slice(0, 7)

  // Aggregate current usage
  const [aiUsageRes, branchesRes] = await Promise.all([
    admin
      .from('ai_usage')
      .select('requests_used')
      .eq('organization_id', orgId)
      .eq('period_month', currentPeriod)
      .maybeSingle(),
    admin
      .from('branches')
      .select('id', { count: 'exact', head: true })
      .eq('organization_id', orgId),
  ])

  const aiRequestsThisMonth = aiUsageRes.data?.requests_used ?? 0
  const branchesCount = branchesRes.count ?? 0

  return {
    status: effectiveStatus,
    isExpired,
    plan: sub?.plans
      ? {
          slug: sub.plans.slug,
          name: sub.plans.name || {},
        }
      : null,
    billingPeriod: sub?.billing_period ?? null,
    expiresAt: sub?.expires_at ?? null,
    features: (sub?.plans?.features || {}) as Record<string, boolean>,
    limits: (sub?.plans?.limits || {}) as Record<string, number>,
    usage: {
      aiRequestsThisMonth,
      branchesCount,
    },
  }
})
