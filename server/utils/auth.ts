import { getSupabaseAdmin } from './supabase'

export interface Caller {
  userId: string
}

/**
 * Extract the caller's access token. Accepted (in order):
 *  1. `Authorization: Bearer <token>` header
 *  2. `accessToken` in the request body (existing app convention)
 */
export function readAccessToken(event: any, body?: { accessToken?: string } | null): string | undefined {
  const header = getHeader(event, 'authorization')
  if (header?.startsWith('Bearer ')) return header.slice(7)
  return body?.accessToken
}

/**
 * Server-side authentication for the AI endpoints. Resolves the token with
 * Supabase admin auth and returns the verified user id. Throws 401 otherwise.
 */
export async function resolveCaller(event: any, body?: { accessToken?: string } | null): Promise<Caller> {
  const token = readAccessToken(event, body)
  if (!token) {
    throw createError({ statusCode: 401, statusMessage: 'Missing access token' })
  }

  const admin = getSupabaseAdmin()
  const { data, error } = await admin.auth.getUser(token)

  if (error || !data?.user) {
    throw createError({ statusCode: 401, statusMessage: 'Invalid session' })
  }

  return { userId: data.user.id }
}