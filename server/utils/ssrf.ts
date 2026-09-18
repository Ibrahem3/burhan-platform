import dns from 'node:dns'
import net from 'node:net'
import { URL } from 'node:url'

/**
 * Check whether an IPv4 or IPv6 address belongs to a private, loopback,
 * link-local, multicast, cloud-metadata, or reserved non-routable range.
 */
export function isPrivateOrBlockedIP(ip: string): boolean {
  // Normalize IPv4-mapped IPv6 addresses (e.g., "::ffff:127.0.0.1")
  if (ip.startsWith('::ffff:')) {
    const ipv4 = ip.slice(7)
    if (net.isIPv4(ipv4)) {
      return isPrivateOrBlockedIP(ipv4)
    }
  }

  if (net.isIPv4(ip)) {
    const parts = ip.split('.').map((p) => Number.parseInt(p, 10))
    if (parts.length !== 4 || parts.some(isNaN)) return true

    const [a, b, c, d] = parts

    // 0.0.0.0/8 (Current network / default route)
    if (a === 0) return true

    // 127.0.0.0/8 (Loopback)
    if (a === 127) return true

    // 10.0.0.0/8 (RFC1918 private)
    if (a === 10) return true

    // 172.16.0.0/12 (RFC1918 private: 172.16.0.0 - 172.31.255.255)
    if (a === 172 && b >= 16 && b <= 31) return true

    // 192.168.0.0/16 (RFC1918 private)
    if (a === 192 && b === 168) return true

    // 169.254.0.0/16 (Link-local, including 169.254.169.254 cloud metadata)
    if (a === 169 && b === 254) return true

    // 100.64.0.0/10 (Carrier-grade NAT)
    if (a === 100 && b >= 64 && b <= 127) return true

    // 224.0.0.0/4 (Multicast)
    if (a >= 224 && a <= 239) return true

    // 240.0.0.0/4 (Reserved / Future use)
    if (a >= 240) return true

    // 255.255.255.255 (Broadcast)
    if (a === 255 && b === 255 && c === 255 && d === 255) return true

    return false
  }

  if (net.isIPv6(ip)) {
    const lower = ip.toLowerCase()

    // ::1 (Loopback)
    if (lower === '::1' || lower === '0:0:0:0:0:0:0:1') return true

    // :: (Unspecified)
    if (lower === '::' || lower === '0:0:0:0:0:0:0:0') return true

    // fe80::/10 (Link-local)
    if (lower.startsWith('fe8') || lower.startsWith('fe9') || lower.startsWith('fea') || lower.startsWith('feb')) return true

    // fc00::/7 (Unique Local Address - ULA private)
    if (lower.startsWith('fc') || lower.startsWith('fd')) return true

    // ff00::/8 (Multicast)
    if (lower.startsWith('ff')) return true

    return false
  }

  // Not a valid IP string
  return true
}

export interface ValidatedEndpoint {
  normalizedUrl: string
  host: string
  port: number
  resolvedIps: string[]
}

const BLOCKED_HOST_PATTERNS = [
  /^localhost$/i,
  /\.localhost$/i,
  /\.internal$/i,
  /\.local$/i,
  /^metadata\.google\.internal$/i,
  /^instance-data$/i,
]

/**
 * Validate and normalize a candidate endpoint URL against SSRF threats.
 * Fails closed on malformed URLs, embedded userinfo, private/loopback IPs,
 * or hosts that resolve to blocked ranges.
 */
export async function validateEndpointUrl(
  urlString: string,
  options: { allowHttp?: boolean } = {}
): Promise<ValidatedEndpoint> {
  if (typeof urlString !== 'string' || !urlString.trim()) {
    throw new Error('Endpoint URL cannot be empty')
  }

  let parsed: URL
  try {
    parsed = new URL(urlString.trim())
  } catch {
    throw new Error('Invalid endpoint URL structure')
  }

  // Enforce protocol: https by default; http only when explicitly permitted
  if (parsed.protocol !== 'https:' && parsed.protocol !== 'http:') {
    throw new Error(`Unsupported protocol: ${parsed.protocol} (only https: is permitted)`)
  }

  if (parsed.protocol === 'http:' && !options.allowHttp && process.env.NODE_ENV === 'production') {
    throw new Error('Insecure HTTP endpoints are not permitted in production')
  }

  // Block embedded user credentials (e.g. https://user:pass@host)
  if (parsed.username || parsed.password) {
    throw new Error('Endpoint URL must not contain embedded user credentials')
  }

  const hostname = parsed.hostname.trim()
  if (!hostname) {
    throw new Error('Endpoint URL missing hostname')
  }

  // Check against static blocked patterns
  for (const pattern of BLOCKED_HOST_PATTERNS) {
    if (pattern.test(hostname)) {
      throw new Error(`Host '${hostname}' is not permitted (blocked internal hostname)`)
    }
  }

  // Direct IP literal validation
  if (net.isIP(hostname)) {
    if (isPrivateOrBlockedIP(hostname)) {
      throw new Error(`Endpoint IP '${hostname}' belongs to a restricted private or non-routable range`)
    }
    const port = parsed.port ? Number.parseInt(parsed.port, 10) : (parsed.protocol === 'https:' ? 443 : 80)
    return {
      normalizedUrl: parsed.origin + parsed.pathname.replace(/\/+$/, ''),
      host: hostname,
      port,
      resolvedIps: [hostname],
    }
  }

  // Resolve hostname via DNS to prevent DNS rebinding / host spoofing
  let records: dns.LookupAddress[]
  try {
    records = await dns.promises.lookup(hostname, { all: true })
  } catch (err: any) {
    throw new Error(`Failed to resolve host '${hostname}': ${err?.message || 'DNS lookup failed'}`)
  }

  if (!records || records.length === 0) {
    throw new Error(`Host '${hostname}' could not be resolved to any network address`)
  }

  const resolvedIps = records.map((r) => r.address)

  // Every resolved IP must be routable and public
  for (const record of records) {
    if (isPrivateOrBlockedIP(record.address)) {
      throw new Error(
        `Host '${hostname}' resolved to blocked or private address '${record.address}'`
      )
    }
  }

  const port = parsed.port ? Number.parseInt(parsed.port, 10) : (parsed.protocol === 'https:' ? 443 : 80)

  return {
    normalizedUrl: parsed.origin + parsed.pathname.replace(/\/+$/, ''),
    host: hostname,
    port,
    resolvedIps,
  }
}

export const APPROVED_PROVIDERS = ['openai', 'nosana', 'openrouter', 'custom'] as const
export type ApprovedProvider = typeof APPROVED_PROVIDERS[number]

export const APPROVED_PROVIDER_ENDPOINTS = {
  openai: ['https://api.openai.com'],
  openrouter: ['https://openrouter.ai/api', 'https://openrouter.ai'],
} as const

export interface ProviderEndpointPolicyResult {
  allowed: boolean
  endpoint: string
  normalizedBaseUrl?: string | null
  error?: string
  statusCode?: number
}

/**
 * Validates candidate AI provider endpoint against strict platform policy.
 * - OpenAI: strictly locked to https://api.openai.com (custom base_url rejected)
 * - OpenRouter: strictly locked to https://openrouter.ai/api or https://openrouter.ai
 * - Nosana: strictly uses platform cluster configuration (custom base_url rejected)
 * - Custom: disabled by default in V1. Enabled only if BYOK_ALLOW_CUSTOM_ENDPOINTS=true
 *   and constrained to BYOK_ALLOWED_CUSTOM_HOSTS allowlist + full SSRF validation.
 */
export async function validateProviderEndpointPolicy(
  provider: string,
  candidateBaseUrl?: string | null,
  options: { allowHttp?: boolean } = {}
): Promise<ProviderEndpointPolicyResult> {
  if (!APPROVED_PROVIDERS.includes(provider as any)) {
    return {
      allowed: false,
      endpoint: '',
      error: `Invalid provider: '${provider}'. Approved providers are: ${APPROVED_PROVIDERS.join(', ')}`,
      statusCode: 400,
    }
  }

  const trimmedUrl = typeof candidateBaseUrl === 'string' ? candidateBaseUrl.trim() : ''

  if (provider === 'openai') {
    const defaultEndpoint = 'https://api.openai.com'
    if (trimmedUrl) {
      const normalized = trimmedUrl.replace(/\/+$/, '')
      if (normalized !== defaultEndpoint) {
        return {
          allowed: false,
          endpoint: '',
          error: `Custom base_url is not permitted for OpenAI in V1. Fixed endpoint is: ${defaultEndpoint}`,
          statusCode: 400,
        }
      }
    }
    return {
      allowed: true,
      endpoint: defaultEndpoint,
      normalizedBaseUrl: null,
    }
  }

  if (provider === 'openrouter') {
    const defaultEndpoint = 'https://openrouter.ai/api'
    if (trimmedUrl) {
      const normalized = trimmedUrl.replace(/\/+$/, '')
      const allowed = APPROVED_PROVIDER_ENDPOINTS.openrouter.map((u) => u.replace(/\/+$/, ''))
      if (!allowed.includes(normalized)) {
        return {
          allowed: false,
          endpoint: '',
          error: `Custom base_url is not permitted for OpenRouter in V1. Approved endpoint is: ${defaultEndpoint}`,
          statusCode: 400,
        }
      }
      return {
        allowed: true,
        endpoint: normalized,
        normalizedBaseUrl: normalized,
      }
    }
    return {
      allowed: true,
      endpoint: defaultEndpoint,
      normalizedBaseUrl: null,
    }
  }

  if (provider === 'nosana') {
    if (trimmedUrl) {
      return {
        allowed: false,
        endpoint: '',
        error: 'Custom base_url is not permitted for Nosana provider (uses platform cluster configuration)',
        statusCode: 400,
      }
    }
    return {
      allowed: true,
      endpoint: '', // Resolved from platform config at runtime
      normalizedBaseUrl: null,
    }
  }

  if (provider === 'custom') {
    // Check deployment authorization
    const allowCustom = process.env.BYOK_ALLOW_CUSTOM_ENDPOINTS === 'true'
    if (!allowCustom) {
      return {
        allowed: false,
        endpoint: '',
        error: 'Custom AI provider endpoints are disabled by platform policy in V1. Use approved providers (openai, nosana, openrouter).',
        statusCode: 403,
      }
    }

    if (!trimmedUrl) {
      return {
        allowed: false,
        endpoint: '',
        error: 'Missing base_url for custom provider',
        statusCode: 400,
      }
    }

    // Check deployment host allowlist if configured
    const allowedHostsRaw = process.env.BYOK_ALLOWED_CUSTOM_HOSTS || ''
    const allowedHosts = allowedHostsRaw
      .split(',')
      .map((h) => h.trim().toLowerCase())
      .filter(Boolean)

    let parsed: URL
    try {
      parsed = new URL(trimmedUrl)
    } catch {
      return {
        allowed: false,
        endpoint: '',
        error: 'Invalid custom endpoint URL structure',
        statusCode: 400,
      }
    }

    if (allowedHosts.length > 0) {
      const hostname = parsed.hostname.toLowerCase()
      if (!allowedHosts.includes(hostname)) {
        return {
          allowed: false,
          endpoint: '',
          error: `Host '${hostname}' is not in the deployment-approved custom endpoint allowlist`,
          statusCode: 403,
        }
      }
    }

    // SSRF validation against private/loopback/metadata/unroutable IPs
    try {
      const validated = await validateEndpointUrl(trimmedUrl, options)
      return {
        allowed: true,
        endpoint: validated.normalizedUrl,
        normalizedBaseUrl: validated.normalizedUrl,
      }
    } catch (err: any) {
      return {
        allowed: false,
        endpoint: '',
        error: err?.message || 'SSRF validation failed for custom endpoint',
        statusCode: 400,
      }
    }
  }

  return {
    allowed: false,
    endpoint: '',
    error: 'Unhandled provider policy',
    statusCode: 400,
  }
}

/**
 * Secure HTTP fetch wrapper for AI inference requests.
 * Enforces:
 *  1. redirect: 'manual' (strictly prevents automatic redirect following)
 *  2. Immediate fail-closed error if an upstream provider returns 3xx redirect status
 *  3. Sanitized error messages without leaking redirect Location header
 */
export async function safeProviderFetch(
  url: string,
  init: RequestInit = {}
): Promise<Response> {
  const response = await fetch(url, {
    ...init,
    redirect: 'manual',
  })

  if (response.status >= 300 && response.status < 400) {
    throw new Error(
      `AI provider returned an unsupported redirect (${response.status}); automatic redirects are disabled for security`
    )
  }

  return response
}

