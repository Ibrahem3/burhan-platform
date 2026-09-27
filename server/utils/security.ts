import { createError } from 'h3'

/**
 * Server-side URL safety validation.
 * Verifies that a given string is a valid HTTP or HTTPS URL.
 */
export function isSafeExternalUrl(url?: string | null): boolean {
  if (!url || typeof url !== 'string') return false
  const trimmed = url.trim()
  if (!trimmed) return false
  try {
    const parsed = new URL(trimmed)
    return parsed.protocol === 'http:' || parsed.protocol === 'https:'
  } catch {
    return false
  }
}

/**
 * Validates external URL or throws 400 Bad Request.
 */
export function assertSafeExternalUrl(url?: string | null, fieldName = 'URL'): string {
  if (!url || typeof url !== 'string' || !url.trim()) {
    throw createError({ statusCode: 400, statusMessage: `${fieldName} is required` })
  }
  const trimmed = url.trim()
  let parsed: URL
  try {
    parsed = new URL(trimmed)
  } catch {
    throw createError({ statusCode: 400, statusMessage: `Invalid ${fieldName}` })
  }

  if (parsed.protocol !== 'http:' && parsed.protocol !== 'https:') {
    throw createError({ statusCode: 400, statusMessage: `${fieldName} must use http or https protocol` })
  }

  return trimmed
}
