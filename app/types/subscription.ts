export type SubscriptionStatus = 'active' | 'expired' | 'cancelled' | 'none'

export interface PlanInfo {
  slug: string
  name: Record<string, string> | string
}

export interface SubscriptionUsage {
  aiRequestsThisMonth: number
  branchesCount: number
}

export interface SubscriptionResponse {
  status: SubscriptionStatus
  isExpired: boolean
  plan: PlanInfo | null
  billingPeriod: string | null
  expiresAt: string | null
  features: Record<string, boolean>
  limits: Record<string, number>
  usage: SubscriptionUsage
}

export type AuthBootstrapStatus = 'idle' | 'loading' | 'authenticated' | 'unauthenticated' | 'unassigned' | 'error'
