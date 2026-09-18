import { test, describe, before, after } from 'node:test'
import assert from 'node:assert/strict'
import crypto from 'node:crypto'
import http from 'node:http'
import {
  setup, r, q, q1, asUser, asAnon, U, ORG_A, ORG_B
} from './ai/helpers.mjs'
import { encryptSecret, decryptSecret, getMasterKey } from '../server/utils/crypto.ts'
import {
  validateEndpointUrl,
  isPrivateOrBlockedIP,
  validateProviderEndpointPolicy,
  safeProviderFetch
} from '../server/utils/ssrf.ts'

const TEST_MASTER_KEY = '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef'

before(async () => {
  process.env.BYOK_ENCRYPTION_KEY = TEST_MASTER_KEY
  await setup()

  // Ensure 00018 migration is applied to test database
  const tableExists = await q1(`SELECT count(*) FROM pg_class WHERE relname = 'tenant_ai_credentials'`)
  if (tableExists !== '1') {
    const fs = await import('node:fs')
    const sql = fs.readFileSync(new URL('../supabase/migrations/00018_tenant_ai_credentials.sql', import.meta.url), 'utf-8')
    await r(sql)
  }
})

describe('1. Encryption Subsystem (AES-256-GCM)', () => {
  test('master key validation: accepts valid 64-hex key (32 bytes)', () => {
    const key = getMasterKey()
    assert.equal(key.length, 32)
  })

  test('master key validation: rejects missing, non-hex, or invalid length key', () => {
    const orig = process.env.BYOK_ENCRYPTION_KEY
    try {
      delete process.env.BYOK_ENCRYPTION_KEY
      assert.throws(() => getMasterKey(), /not configured/i)

      process.env.BYOK_ENCRYPTION_KEY = 'short_key'
      assert.throws(() => getMasterKey(), /exactly 64 hexadecimal characters/i)

      process.env.BYOK_ENCRYPTION_KEY = 'z'.repeat(64)
      assert.throws(() => getMasterKey(), /exactly 64 hexadecimal characters/i)
    } finally {
      process.env.BYOK_ENCRYPTION_KEY = orig
    }
  })

  test('encrypt and decrypt round-trip correctly', () => {
    const secret = 'sk-test-secret-key-1234567890-xyz'
    const encrypted = encryptSecret(secret)

    assert.ok(encrypted.ciphertext, 'ciphertext produced')
    assert.equal(encrypted.iv.length, 24, '12-byte IV in hex has length 24')
    assert.equal(encrypted.tag.length, 32, '16-byte tag in hex has length 32')
    assert.equal(encrypted.keyVersion, 1)

    const decrypted = decryptSecret(encrypted.ciphertext, encrypted.iv, encrypted.tag, encrypted.keyVersion)
    assert.equal(decrypted, secret, 'decrypted text matches original plaintext')
  })

  test('generates unique random IV for every encryption of identical plaintext', () => {
    const secret = 'identical-secret-payload'
    const enc1 = encryptSecret(secret)
    const enc2 = encryptSecret(secret)

    assert.notEqual(enc1.iv, enc2.iv, 'IV must be unique per encryption')
    assert.notEqual(enc1.ciphertext, enc2.ciphertext, 'Ciphertext must differ due to unique IV')
    assert.equal(decryptSecret(enc1.ciphertext, enc1.iv, enc1.tag), secret)
    assert.equal(decryptSecret(enc2.ciphertext, enc2.iv, enc2.tag), secret)
  })

  test('tampered ciphertext is rejected via auth tag verification', () => {
    const secret = 'super-secret-key'
    const enc = encryptSecret(secret)

    // Flip last byte of ciphertext
    const tampered = enc.ciphertext.slice(0, -2) + (enc.ciphertext.slice(-2) === 'aa' ? 'bb' : 'aa')
    assert.throws(
      () => decryptSecret(tampered, enc.iv, enc.tag),
      /authentication tag verification failed/i
    )
  })

  test('tampered auth tag is rejected', () => {
    const secret = 'super-secret-key'
    const enc = encryptSecret(secret)

    // Flip last byte of tag
    const tamperedTag = enc.tag.slice(0, -2) + (enc.tag.slice(-2) === '00' ? '11' : '00')
    assert.throws(
      () => decryptSecret(enc.ciphertext, enc.iv, tamperedTag),
      /authentication tag verification failed/i
    )
  })
})

describe('2. SSRF Hardening for Custom Endpoints', () => {
  test('isPrivateOrBlockedIP accurately identifies all dangerous ranges', () => {
    // Loopbacks
    assert.equal(isPrivateOrBlockedIP('127.0.0.1'), true)
    assert.equal(isPrivateOrBlockedIP('127.0.1.5'), true)
    assert.equal(isPrivateOrBlockedIP('::1'), true)
    assert.equal(isPrivateOrBlockedIP('::ffff:127.0.0.1'), true)

    // RFC1918 Private
    assert.equal(isPrivateOrBlockedIP('10.0.0.1'), true)
    assert.equal(isPrivateOrBlockedIP('172.16.0.1'), true)
    assert.equal(isPrivateOrBlockedIP('172.31.255.255'), true)
    assert.equal(isPrivateOrBlockedIP('192.168.1.1'), true)

    // Link-local & Cloud Metadata
    assert.equal(isPrivateOrBlockedIP('169.254.169.254'), true, 'AWS/GCP/Azure metadata blocked')
    assert.equal(isPrivateOrBlockedIP('169.254.1.1'), true)
    assert.equal(isPrivateOrBlockedIP('fe80::1'), true)

    // Multicast & Broadcast
    assert.equal(isPrivateOrBlockedIP('224.0.0.1'), true)
    assert.equal(isPrivateOrBlockedIP('255.255.255.255'), true)
    assert.equal(isPrivateOrBlockedIP('0.0.0.0'), true)

    // Public routable IPs (Allowed)
    assert.equal(isPrivateOrBlockedIP('8.8.8.8'), false, 'Google DNS is public')
    assert.equal(isPrivateOrBlockedIP('1.1.1.1'), false, 'Cloudflare DNS is public')
  })

  test('validateEndpointUrl blocks dangerous hostnames and private IPs', async () => {
    // Blocked hostnames
    await assert.rejects(() => validateEndpointUrl('http://localhost:8080'), /blocked internal hostname/i)
    await assert.rejects(() => validateEndpointUrl('https://app.localhost/v1'), /blocked internal hostname/i)
    await assert.rejects(() => validateEndpointUrl('https://metadata.google.internal'), /blocked internal hostname/i)

    // Blocked direct IP literals
    await assert.rejects(() => validateEndpointUrl('http://127.0.0.1:11434'), /restricted private/i)
    await assert.rejects(() => validateEndpointUrl('http://10.0.1.5:8000'), /restricted private/i)
    await assert.rejects(() => validateEndpointUrl('http://169.254.169.254/latest'), /restricted private/i)

    // Blocked embedded credentials
    await assert.rejects(() => validateEndpointUrl('https://user:password@api.openai.com'), /embedded user credentials/i)

    // Blocked protocols
    await assert.rejects(() => validateEndpointUrl('file:///etc/passwd'), /unsupported protocol/i)
    await assert.rejects(() => validateEndpointUrl('gopher://127.0.0.1'), /unsupported protocol/i)
  })

  test('validateEndpointUrl normalizes and permits valid public endpoints', async () => {
    const res = await validateEndpointUrl('https://api.openai.com/v1/')
    assert.equal(res.normalizedUrl, 'https://api.openai.com/v1')
    assert.equal(res.host, 'api.openai.com')
    assert.equal(res.port, 443)
    assert.ok(res.resolvedIps.length > 0)
  })
})

describe('3. Database Security & Client Revocation', () => {
  test('tenant_ai_credentials table has RLS enabled', async () => {
    const rls = await q1(`SELECT relrowsecurity FROM pg_class WHERE relname = 'tenant_ai_credentials'`)
    assert.equal(rls, 't', 'RLS is enabled on tenant_ai_credentials')
  })

  test('direct client PostgREST access is unconditionally revoked for anon and authenticated', async () => {
    // Authenticated user cannot query tenant_ai_credentials directly
    const authRes = await asUser(U.USER_A, 'SELECT * FROM tenant_ai_credentials;').catch(e => e)
    assert.ok(authRes instanceof Error, 'authenticated user must be rejected with permission denied')
    assert.match(authRes.message, /permission denied/i)

    // Anonymous user cannot query tenant_ai_credentials directly
    const anonRes = await asAnon('SELECT * FROM tenant_ai_credentials;').catch(e => e)
    assert.ok(anonRes instanceof Error, 'anon must be rejected with permission denied')
    assert.match(anonRes.message, /permission denied/i)
  })

  test('enforces UNIQUE(organization_id, provider) per organization', async () => {
    // Cleanup any existing test credential
    await r(`DELETE FROM tenant_ai_credentials WHERE organization_id = '${ORG_A}';`)

    const enc1 = encryptSecret('sk-first-key')
    const res1 = await r(`
      INSERT INTO tenant_ai_credentials (organization_id, provider, encrypted_key, key_iv, key_tag, key_suffix)
      VALUES ('${ORG_A}', 'openai', '${enc1.ciphertext}', '${enc1.iv}', '${enc1.tag}', 'key1');
    `)
    assert.equal(res1.ok, true, 'first insert succeeds')

    // Second insert for same (organization_id, provider) must fail unique constraint
    const enc2 = encryptSecret('sk-second-key')
    const res2 = await r(`
      INSERT INTO tenant_ai_credentials (organization_id, provider, encrypted_key, key_iv, key_tag, key_suffix)
      VALUES ('${ORG_A}', 'openai', '${enc2.ciphertext}', '${enc2.iv}', '${enc2.tag}', 'key2');
    `)
    assert.equal(res2.ok, false, 'second insert for same provider rejected by unique constraint')

    // Cleanup
    await r(`DELETE FROM tenant_ai_credentials WHERE organization_id = '${ORG_A}';`)
  })
})

describe('4. Plaintext Lifetime & Exposure Invariants', () => {
  test('no plaintext keys stored in database', async () => {
    const rawApiKey = 'sk-super-secret-key-998877'
    const enc = encryptSecret(rawApiKey)

    await r(`
      INSERT INTO tenant_ai_credentials (organization_id, provider, encrypted_key, key_iv, key_tag, key_suffix)
      VALUES ('${ORG_A}', 'nosana', '${enc.ciphertext}', '${enc.iv}', '${enc.tag}', '8877');
    `)

    // Verify stored row
    const row = await q(`SELECT encrypted_key, key_suffix FROM tenant_ai_credentials WHERE organization_id = '${ORG_A}' AND provider = 'nosana'`)
    assert.equal(row.length, 1)
    assert.equal(row[0][0], enc.ciphertext, 'ciphertext stored')
    assert.equal(row[0][1], '8877', 'only suffix stored')

    // Grep entire table for raw plaintext
    const leaked = await q1(`SELECT count(*) FROM tenant_ai_credentials WHERE encrypted_key LIKE '%${rawApiKey}%'`)
    assert.equal(leaked, '0', 'plaintext key never exists in database')

    // Cleanup
    await r(`DELETE FROM tenant_ai_credentials WHERE organization_id = '${ORG_A}';`)
  })

  test('ai_jobs table does not contain provider secrets', async () => {
    const cols = await q(`SELECT column_name FROM information_schema.columns WHERE table_name = 'ai_jobs'`)
    const colNames = cols.map(c => c[0])

    assert.ok(!colNames.includes('api_key'), 'ai_jobs has no api_key column')
    assert.ok(!colNames.includes('cluster_key'), 'ai_jobs has no cluster_key column')
    assert.ok(!colNames.includes('token'), 'ai_jobs has no token column')
  })
})

describe('5. Quota & Integration Semantics', () => {
  test('monthly_ai_requests remains strictly enforced on job admission', async () => {
    // Check that create_ai_job accepts p_request_limit and fails with ai_quota_exceeded when limit reached
    const uid = crypto.randomUUID()
    await r(`INSERT INTO auth.users (id) VALUES ('${uid}') ON CONFLICT DO NOTHING;`)
    await r(`INSERT INTO profiles (id, organization_id, role) VALUES ('${uid}', '${ORG_A}', 'member') ON CONFLICT (id) DO UPDATE SET organization_id = '${ORG_A}', role = 'member';`)

    // Reserve with 0 limit -> must exceed
    const res = await r(`SELECT public.create_ai_job('${uid}'::uuid, '${ORG_A}'::uuid, NULL, 'test prompt', NULL, 'ar', 'default', 500, 0, 100000);`)
    assert.equal(res.ok, false)
    assert.match(res.err, /ai_quota_exceeded/i)

    // Cleanup
    await r(`DELETE FROM auth.users WHERE id = '${uid}';`)
  })
})

describe('6. SSRF Runtime Hardening: Redirects & DNS Rebinding Elimination', () => {
  let testServer
  let serverPort
  let secretHit = false

  before(async () => {
    testServer = http.createServer((req, res) => {
      if (req.url === '/redirect-to-private') {
        res.writeHead(302, { Location: 'http://10.0.0.1/admin' })
        res.end()
      } else if (req.url === '/redirect-to-localhost') {
        res.writeHead(302, { Location: `http://127.0.0.1:${serverPort}/secret` })
        res.end()
      } else if (req.url === '/redirect-to-metadata') {
        res.writeHead(302, { Location: 'http://169.254.169.254/latest/meta-data/' })
        res.end()
      } else if (req.url === '/redirect-301') {
        res.writeHead(301, { Location: 'http://169.254.169.254/' })
        res.end()
      } else if (req.url === '/redirect-307') {
        res.writeHead(307, { Location: 'http://127.0.0.1/admin' })
        res.end()
      } else if (req.url === '/redirect-308') {
        res.writeHead(308, { Location: 'http://10.200.1.1/' })
        res.end()
      } else if (req.url === '/secret') {
        secretHit = true
        res.writeHead(200, { 'Content-Type': 'text/plain' })
        res.end('INTERNAL_SECRET_REACHED')
      } else if (req.url === '/valid-sse') {
        res.writeHead(200, { 'Content-Type': 'text/event-stream' })
        res.write('data: {"content": "hello"}\n\n')
        res.write('data: [DONE]\n\n')
        res.end()
      } else {
        res.writeHead(404)
        res.end()
      }
    })

    await new Promise((resolve) => {
      testServer.listen(0, '127.0.0.1', () => {
        serverPort = testServer.address().port
        resolve()
      })
    })
  })

  after(async () => {
    if (testServer) {
      await new Promise((resolve) => testServer.close(resolve))
    }
  })

  test('public -> private redirect is strictly blocked (302 Location: 10.0.0.1)', async () => {
    await assert.rejects(
      () => safeProviderFetch(`http://127.0.0.1:${serverPort}/redirect-to-private`),
      /unsupported redirect \(302\)/i
    )
  })

  test('public -> localhost redirect is strictly blocked without contacting secret endpoint', async () => {
    secretHit = false
    await assert.rejects(
      () => safeProviderFetch(`http://127.0.0.1:${serverPort}/redirect-to-localhost`),
      /unsupported redirect \(302\)/i
    )
    assert.equal(secretHit, false, 'Internal /secret endpoint was never reached')
  })

  test('public -> metadata redirect is strictly blocked (302 Location: 169.254.169.254)', async () => {
    await assert.rejects(
      () => safeProviderFetch(`http://127.0.0.1:${serverPort}/redirect-to-metadata`),
      /unsupported redirect \(302\)/i
    )
  })

  test('all other HTTP redirect statuses (301, 307, 308) are strictly blocked', async () => {
    await assert.rejects(
      () => safeProviderFetch(`http://127.0.0.1:${serverPort}/redirect-301`),
      /unsupported redirect \(301\)/i
    )
    await assert.rejects(
      () => safeProviderFetch(`http://127.0.0.1:${serverPort}/redirect-307`),
      /unsupported redirect \(307\)/i
    )
    await assert.rejects(
      () => safeProviderFetch(`http://127.0.0.1:${serverPort}/redirect-308`),
      /unsupported redirect \(308\)/i
    )
  })

  test('valid 200 response passes through safeProviderFetch successfully', async () => {
    const res = await safeProviderFetch(`http://127.0.0.1:${serverPort}/valid-sse`)
    assert.equal(res.status, 200)
    const text = await res.text()
    assert.match(text, /hello/)
  })

  test('Provider Policy: OpenAI is strictly locked to https://api.openai.com', async () => {
    // Default endpoint
    const p1 = await validateProviderEndpointPolicy('openai')
    assert.equal(p1.allowed, true)
    assert.equal(p1.endpoint, 'https://api.openai.com')

    // Matching base_url
    const p2 = await validateProviderEndpointPolicy('openai', 'https://api.openai.com/')
    assert.equal(p2.allowed, true)
    assert.equal(p2.endpoint, 'https://api.openai.com')

    // Custom base_url attempted -> REJECTED (closes DNS rebinding window)
    const p3 = await validateProviderEndpointPolicy('openai', 'https://attacker-controlled-host.com')
    assert.equal(p3.allowed, false)
    assert.match(p3.error, /Custom base_url is not permitted for OpenAI/i)
  })

  test('Provider Policy: OpenRouter is strictly locked to approved OpenRouter endpoints', async () => {
    // Default endpoint
    const p1 = await validateProviderEndpointPolicy('openrouter')
    assert.equal(p1.allowed, true)
    assert.equal(p1.endpoint, 'https://openrouter.ai/api')

    // Approved base_url
    const p2 = await validateProviderEndpointPolicy('openrouter', 'https://openrouter.ai/api')
    assert.equal(p2.allowed, true)

    // Custom base_url attempted -> REJECTED
    const p3 = await validateProviderEndpointPolicy('openrouter', 'https://malicious-rebinding.com')
    assert.equal(p3.allowed, false)
    assert.match(p3.error, /Custom base_url is not permitted for OpenRouter/i)
  })

  test('Provider Policy: Nosana rejects custom base_url', async () => {
    const p1 = await validateProviderEndpointPolicy('nosana')
    assert.equal(p1.allowed, true)

    const p2 = await validateProviderEndpointPolicy('nosana', 'https://custom-nosana.com')
    assert.equal(p2.allowed, false)
    assert.match(p2.error, /Custom base_url is not permitted for Nosana/i)
  })

  test('Provider Policy: Custom provider is disabled by default in V1', async () => {
    const orig = process.env.BYOK_ALLOW_CUSTOM_ENDPOINTS
    try {
      delete process.env.BYOK_ALLOW_CUSTOM_ENDPOINTS
      const res = await validateProviderEndpointPolicy('custom', 'https://custom-inference.org')
      assert.equal(res.allowed, false)
      assert.equal(res.statusCode, 403)
      assert.match(res.error, /Custom AI provider endpoints are disabled by platform policy in V1/i)
    } finally {
      process.env.BYOK_ALLOW_CUSTOM_ENDPOINTS = orig
    }
  })

  test('Provider Policy: Custom provider deployment allowlist enforces host check', async () => {
    const origAllow = process.env.BYOK_ALLOW_CUSTOM_ENDPOINTS
    const origHosts = process.env.BYOK_ALLOWED_CUSTOM_HOSTS
    try {
      process.env.BYOK_ALLOW_CUSTOM_ENDPOINTS = 'true'
      process.env.BYOK_ALLOWED_CUSTOM_HOSTS = 'partner.example.com,inference.enterprise.internal'

      // Host not in allowlist -> REJECTED
      const resRejected = await validateProviderEndpointPolicy('custom', 'https://unapproved-host.com/v1')
      assert.equal(resRejected.allowed, false)
      assert.equal(resRejected.statusCode, 403)
      assert.match(resRejected.error, /not in the deployment-approved custom endpoint allowlist/i)
    } finally {
      process.env.BYOK_ALLOW_CUSTOM_ENDPOINTS = origAllow
      process.env.BYOK_ALLOWED_CUSTOM_HOSTS = origHosts
    }
  })

  test('Provider Policy: Rejects unknown providers', async () => {
    const res = await validateProviderEndpointPolicy('unknown_provider')
    assert.equal(res.allowed, false)
    assert.match(res.error, /Invalid provider/i)
  })
})

