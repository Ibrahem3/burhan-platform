import { getSupabaseAdmin } from './supabase'

export interface ActiveSubscription {
  id: string
  organizationId: string
  planId: string
  planSlug: string
  planName: Record<string, string>
  status: 'active' | 'expired' | 'cancelled'
  billingPeriod: 'monthly' | 'yearly'
  startsAt: string
  expiresAt: string | null
  features: Record<string, boolean>
  limits: Record<string, number>
}

/**
 * Fetch the single active subscription and its plan for an organization.
 * Returns null if no active subscription exists or if it has expired.
 */
export async function getActiveSubscription(orgId: string): Promise<ActiveSubscription | null> {
  const admin = getSupabaseAdmin() as any

  const { data: sub, error } = await admin
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

  if (error || !sub || !sub.plans) {
    return null
  }

  // Expiration check: expires_at = null is perpetual (community)
  if (sub.expires_at && new Date(sub.expires_at).getTime() <= Date.now()) {
    return null
  }

  return {
    id: sub.id,
    organizationId: sub.organization_id,
    planId: sub.plan_id,
    planSlug: sub.plans.slug,
    planName: sub.plans.name || {},
    status: sub.status,
    billingPeriod: sub.billing_period,
    startsAt: sub.starts_at,
    expiresAt: sub.expires_at,
    features: (sub.plans.features || {}) as Record<string, boolean>,
    limits: (sub.plans.limits || {}) as Record<string, number>,
  }
}

/**
 * Check whether an organization's active plan enables a specific feature flag.
 */
export async function hasFeature(orgId: string, feature: string): Promise<boolean> {
  const sub = await getActiveSubscription(orgId)
  if (!sub) return false
  return sub.features[feature] === true
}

/**
 * Get a specific numeric limit for an organization.
 * Returns canonical -1 for unlimited, finite number >= 0, or 0 if inactive/missing.
 */
export async function getLimit(orgId: string, limit: string): Promise<number> {
  const sub = await getActiveSubscription(orgId)
  if (!sub) return 0
  const val = sub.limits[limit]
  return typeof val === 'number' ? val : 0
}
