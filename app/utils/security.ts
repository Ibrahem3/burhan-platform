/**
 * Checks whether a given string is a safe external HTTP or HTTPS URL.
 * Rejects javascript:, data:, vbscript:, file:, or malformed schemes.
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
 * Returns a safe external URL, or '#' if the URL is unsafe, empty, or uses an invalid scheme (e.g. javascript:).
 */
export function sanitizeExternalUrl(url?: string | null): string {
  if (!url || typeof url !== 'string') return '#'
  const trimmed = url.trim()
  if (isSafeExternalUrl(trimmed)) {
    return trimmed
  }
  return '#'
}
