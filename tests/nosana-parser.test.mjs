import { test, describe } from 'node:test'
import assert from 'node:assert/strict'
import { parseSseEvent } from '../server/utils/nosana.ts'

describe('Nosana / vLLM SSE Parser Unit Tests', () => {
  test('a. choices[0].delta.content extraction', () => {
    const sseEvent = 'data: {"id":"chatcmpl-1","choices":[{"index":0,"delta":{"role":"assistant","content":"مرحباً بك في برهان"},"finish_reason":null}]}'
    const result = parseSseEvent(sseEvent)
    assert.ok(result)
    assert.equal(result.content, 'مرحباً بك في برهان')
    assert.equal(result.totalTokens, undefined)
  })

  test('b. reasoning-only chunks being captured safely without producing content output', () => {
    const sseEvent = 'data: {"id":"chatcmpl-1","choices":[{"index":0,"delta":{"role":"assistant","reasoning":"Thinking about sovereign architecture..."},"finish_reason":null}]}'
    const result = parseSseEvent(sseEvent)
    assert.ok(result)
    assert.equal(result.content, undefined, 'reasoning-only chunks must not produce content output')
    assert.equal(result.reasoning, 'Thinking about sovereign architecture...')
  })

  test('c. [DONE] recognition', () => {
    assert.equal(parseSseEvent('data: [DONE]'), null)
    assert.equal(parseSseEvent('data:   [DONE]  '), null)
  })

  test('d. usage.total_tokens extraction', () => {
    const sseEvent = 'data: {"id":"chatcmpl-1","choices":[{"index":0,"delta":{},"finish_reason":"length"}],"usage":{"prompt_tokens":62,"completion_tokens":20,"total_tokens":82}}'
    const result = parseSseEvent(sseEvent)
    assert.ok(result)
    assert.equal(result.content, undefined)
    assert.equal(result.totalTokens, 82)
  })

  test('e. fallback when usage is absent', () => {
    const sseEvent = 'data: {"id":"chatcmpl-1","choices":[{"index":0,"delta":{"content":"كلمة"},"finish_reason":null}]}'
    const result = parseSseEvent(sseEvent)
    assert.ok(result)
    assert.equal(result.content, 'كلمة')
    assert.equal(result.totalTokens, undefined)
  })

  test('f. safely handles malformed chunks, empty choices, missing delta', () => {
    assert.equal(parseSseEvent(''), null)
    assert.equal(parseSseEvent('event: ping'), null)
    assert.equal(parseSseEvent('data: not-valid-json'), null)
    assert.equal(parseSseEvent('data: {"choices":[]}'), null)
    assert.equal(parseSseEvent('data: {"choices":[{"index":0}]}'), null)
    assert.equal(parseSseEvent('data: {"choices":[{"index":0,"delta":{}}]}'), null)
  })

  test('g. backwards compatibility for flat mock streams', () => {
    const sseEvent = 'data: {"content":"flat content fallback"}'
    const result = parseSseEvent(sseEvent)
    assert.ok(result)
    assert.equal(result.content, 'flat content fallback')
  })
})
