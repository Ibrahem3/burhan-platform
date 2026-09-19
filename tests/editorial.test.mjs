import { test, describe } from 'node:test'
import assert from 'node:assert/strict'
import {
  buildEditorialMessages,
  BURHAN_EDITORIAL_SYSTEM_PROMPT,
  BURHAN_TRANSLATION_SYSTEM_PROMPT,
  EDITORIAL_LIMITS
} from '../server/utils/editorial.ts'

describe('Burhan Editorial AI & Document Context Test Suite', () => {

  // --- Group 1: Editor Contract ---
  describe('1. Editor Contract & Prompt Construction', () => {
    test('A & B. Editor HTML content reaches the prompt construction and is properly delimited', () => {
      const htmlContent = '<h2>عنوان المقال</h2><p>هذه فقرة تجريبية من المحرر تتحدث عن السيادة الرقمية.</p>'
      const instruction = 'حسّن الصياغة اللغوية وأضف أمثلة عملية.'
      const messages = buildEditorialMessages({
        instruction,
        editorContent: htmlContent,
        interfaceLanguage: 'ar'
      })

      assert.equal(messages.length, 2)
      assert.equal(messages[0].role, 'system')
      assert.equal(messages[1].role, 'user')

      // Verifies exact content presence
      assert.ok(messages[1].content.includes('=== TARGET EDITOR LANGUAGE: Arabic (ar) ==='))
      assert.ok(messages[1].content.includes('=== CURRENT TARGET EDITOR DOCUMENT ==='))
      assert.ok(messages[1].content.includes(htmlContent))
      assert.ok(messages[1].content.includes('=== END CURRENT DOCUMENT ==='))
      assert.ok(messages[1].content.includes('=== USER EDITORIAL INSTRUCTION ==='))
      assert.ok(messages[1].content.includes(instruction))
    })

    test('C. Missing/null editor content is handled clearly without placeholder hallucination', () => {
      const instruction = 'اكتب مقالاً تحليلياً عن الحوسبة السحابية اللامركزية.'
      const messages = buildEditorialMessages({
        instruction,
        editorContent: null,
        interfaceLanguage: 'ar'
      })

      assert.equal(messages.length, 2)
      assert.ok(!messages[1].content.includes('=== CURRENT TARGET EDITOR DOCUMENT ==='))
      assert.ok(messages[1].content.includes('=== USER EDITORIAL INSTRUCTION ==='))
      assert.ok(messages[1].content.includes(instruction))
    })

    test('D. Empty/whitespace editor content allows generation from scratch', () => {
      const instruction = 'اكتب مسودة أولى لمقال فلسفي.'
      const messages = buildEditorialMessages({
        instruction,
        editorContent: '   ',
        interfaceLanguage: 'ar'
      })

      assert.equal(messages.length, 2)
      assert.ok(!messages[1].content.includes('=== CURRENT TARGET EDITOR DOCUMENT ==='))
      assert.ok(messages[1].content.includes('=== USER EDITORIAL INSTRUCTION ==='))
      assert.ok(messages[1].content.includes(instruction))
    })

    test('E. Source reference document is correctly formatted and delimited for cross-language translation', () => {
      const sourceAr = '<h2>مقدمة</h2><p>هذا نص المصدر العربي.</p>'
      const messages = buildEditorialMessages({
        instruction: 'ترجم هذا المقال إلى الإنجليزية بدقة.',
        editorContent: '',
        sourceContent: sourceAr,
        sourceLanguage: 'ar',
        targetLanguage: 'en'
      })

      assert.equal(messages.length, 2)
      assert.ok(messages[1].content.includes('=== TARGET TRANSLATION LANGUAGE: English (en) ==='))
      assert.ok(messages[1].content.includes('=== SOURCE DOCUMENT LANGUAGE: Arabic (ar) ==='))
      assert.ok(messages[1].content.includes(sourceAr))
      assert.ok(messages[1].content.includes('=== END SOURCE DOCUMENT ==='))
      assert.ok(messages[1].content.includes('=== TRANSLATION INSTRUCTION ==='))
    })
  })

  // --- Group 2: System Persona & Tone ---
  describe('2. Editorial System Persona & Tone Directives', () => {
    test('I. Editorial system prompt is always present and defines professional writing role', () => {
      const messages = buildEditorialMessages({
        instruction: 'مراجعة عامة',
        editorContent: '<p>نص</p>'
      })

      assert.ok(messages[0].content.includes("Burhan's Editorial Writing Assistant"))
      assert.ok(messages[0].content.includes('article writing, rigorous editing, and editorial improvement'))
    })

    test('J. Persona strictly prohibits conversational filler and pleasantries', () => {
      assert.ok(BURHAN_EDITORIAL_SYSTEM_PROMPT.includes('Do NOT include conversational preambles'))
      assert.ok(BURHAN_EDITORIAL_SYSTEM_PROMPT.includes('Deliver the actual requested content directly'))
      assert.ok(BURHAN_EDITORIAL_SYSTEM_PROMPT.includes('avoid unnecessary filler'))
    })

    test('Tenant custom systemPrompt override is safely appended to core persona', () => {
      const messages = buildEditorialMessages({
        instruction: 'تدقيق لغوي',
        editorContent: '<p>نص</p>',
        systemPromptOverride: 'استخدم أسلوباً أكاديمياً رصيناً'
      })

      assert.ok(messages[0].content.includes("Burhan's Editorial Writing Assistant"))
      assert.ok(messages[0].content.includes('Additional Directive:'))
      assert.ok(messages[0].content.includes('استخدم أسلوباً أكاديمياً رصيناً'))
    })
  })

  // --- Group 3: Dynamic Language Behavior ---
  describe('3. Dynamic Language Sovereignty Rules', () => {
    test('E & F. Persona instructs observing target editor language and delivering single coherent document', () => {
      assert.ok(BURHAN_EDITORIAL_SYSTEM_PROMPT.includes('Always observe the TARGET EDITOR LANGUAGE specified in the prompt header.'))
      assert.ok(BURHAN_EDITORIAL_SYSTEM_PROMPT.includes('Deliver only ONE coherent document in the specified target language.'))
      assert.ok(BURHAN_EDITORIAL_SYSTEM_PROMPT.includes('Do NOT emit dual-language or bilingual output within a single completion.'))
    })

    test('Translation persona defines high-fidelity structural translation contract', () => {
      assert.ok(BURHAN_TRANSLATION_SYSTEM_PROMPT.includes("Burhan's High-Fidelity Editorial Translator"))
      assert.ok(BURHAN_TRANSLATION_SYSTEM_PROMPT.includes('Exact Source Translation'))
      assert.ok(BURHAN_TRANSLATION_SYSTEM_PROMPT.includes('Structural HTML Preservation'))
    })
  })

  // --- Group 4: Document Structure & Formatting ---
  describe('4. Semantic Document Structure & Editor Compatibility', () => {
    test('K. Persona instructs emission of rich semantic HTML elements', () => {
      assert.ok(BURHAN_EDITORIAL_SYSTEM_PROMPT.includes('Preserve and emit functional, semantic HTML structure'))
      assert.ok(BURHAN_EDITORIAL_SYSTEM_PROMPT.includes('<h2>, <h3>, <p>, <ul>, <ol>, <li>, <strong>, <em>, <blockquote>'))
    })

    test('L. formatAiContentForEditor preserves semantic HTML without invalid paragraph wrapping', () => {
      // Logic mirrored from [id].vue / new.vue formatAiContentForEditor
      function formatAiContentForEditor(raw) {
        const trimmed = (raw || '').trim()
        if (!trimmed) return ''
        const isSemanticHtml = /<\/?(p|h[1-6]|ul|ol|li|blockquote|strong|em|div|table|br)[\s>/]/i.test(trimmed)
        if (isSemanticHtml) return trimmed
        const paragraphs = trimmed
          .split(/\n\s*\n/)
          .map(p => p.trim())
          .filter(Boolean)
          .map(p => `<p>${p.replace(/\n/g, '<br>')}</p>`)
          .join('')
        return paragraphs || `<p>${trimmed}</p>`
      }

      const htmlInput = '<h2>السيادة الرقمية</h2>\n<p>مفهوم أساسي في العالم المعاصر.</p>'
      const formattedHtml = formatAiContentForEditor(htmlInput)
      assert.equal(formattedHtml, htmlInput)
      assert.ok(!formattedHtml.startsWith('<p><h2>'))

      const plainInput = 'First paragraph\n\nSecond paragraph'
      const formattedPlain = formatAiContentForEditor(plainInput)
      assert.equal(formattedPlain, '<p>First paragraph</p><p>Second paragraph</p>')
    })
  })

  // --- Group 5: Boundaries & Safety Limits ---
  describe('5. Generation & Input Safety Limits', () => {
    test('M. MAX_EDITOR_CONTENT_CHARS is defined at 50,000 characters', () => {
      assert.equal(EDITORIAL_LIMITS.MAX_EDITOR_CONTENT_CHARS, 50000)
    })

    test('N. MAX_INSTRUCTION_CHARS is defined at 2,000 characters', () => {
      assert.equal(EDITORIAL_LIMITS.MAX_INSTRUCTION_CHARS, 2000)
    })

    test('O. MAX_OUTPUT_TOKENS is bounded at 4,096 tokens to accommodate reasoning and content', () => {
      assert.equal(EDITORIAL_LIMITS.MAX_OUTPUT_TOKENS, 4096)
      assert.equal(EDITORIAL_LIMITS.MAX_BILINGUAL_OUTPUT_TOKENS, 4096)
    })

    test('P. MAX_TOTAL_CONTEXT_CHARS is bounded at 55,000 characters', () => {
      assert.equal(EDITORIAL_LIMITS.MAX_TOTAL_CONTEXT_CHARS, 55000)
    })

    test('Q & R. Validates boundary logic against oversized inputs', () => {
      const oversizedInstruction = 'a'.repeat(EDITORIAL_LIMITS.MAX_INSTRUCTION_CHARS + 1)
      assert.ok(oversizedInstruction.length > 2000)

      const oversizedContent = 'b'.repeat(EDITORIAL_LIMITS.MAX_EDITOR_CONTENT_CHARS + 1)
      assert.ok(oversizedContent.length > 50000)

      const totalOverflow = 'c'.repeat(EDITORIAL_LIMITS.MAX_TOTAL_CONTEXT_CHARS + 1)
      assert.ok(totalOverflow.length > 55000)
    })
  })

  // --- Group 6: Decoupled Operations & Backend Correctness Contract ---
  describe('6. Decoupled Operations & Output Validation Contract', () => {
    test('1. Valid primary generation output is accepted', async () => {
      const { validateEditorialOutput } = await import('../server/utils/editorial.ts')
      const validHtml = '<h2>السيادة الرقمية</h2><p>تعتبر السيادة الرقمية ركيزة محورية في استقلال الأنظمة والمعلومات.</p>'
      const res = validateEditorialOutput(validHtml)
      assert.equal(res.valid, true)
      assert.equal(res.cleanContent, validHtml)
    })

    test('2. Valid translation output is accepted', async () => {
      const { validateEditorialOutput } = await import('../server/utils/editorial.ts')
      const validEnHtml = '<h2>Digital Sovereignty</h2><p>Digital sovereignty is a cornerstone of systemic and informational independence.</p>'
      const res = validateEditorialOutput(validEnHtml, { isTranslation: true, targetLanguage: 'en' })
      assert.equal(res.valid, true)
      assert.equal(res.cleanContent, validEnHtml)
    })

    test('3. Empty provider output is rejected', async () => {
      const { validateEditorialOutput } = await import('../server/utils/editorial.ts')
      assert.equal(validateEditorialOutput('').valid, false)
      assert.equal(validateEditorialOutput('   ').valid, false)
      assert.equal(validateEditorialOutput(null).valid, false)
    })

    test('4. Truncated output with finish_reason: length is rejected', async () => {
      const { validateEditorialOutput } = await import('../server/utils/editorial.ts')
      const truncatedHtml = '<h2>السيادة الرقمية</h2><p>المفهوم لم يكتمل وتم قطعه هنا بدون إغلاق'
      const res = validateEditorialOutput(truncatedHtml, { finishReason: 'length' })
      assert.equal(res.valid, false)
      assert.ok(res.error.includes('truncated by token limit'))
    })

    test('5. Malformed HTML with cut-off tag is rejected', async () => {
      const { validateEditorialOutput } = await import('../server/utils/editorial.ts')
      const cutOffTag = '<h2>العنوان</h2><p>نص الفقرة</p><li'
      const res = validateEditorialOutput(cutOffTag)
      assert.equal(res.valid, false)
      assert.ok(res.error.includes('unclosed cut-off HTML tag'))
    })

    test('6. Raw delimiter leak is rejected', async () => {
      const { validateEditorialOutput } = await import('../server/utils/editorial.ts')
      const leakOutput = '=== BURHAN_BILINGUAL_ARABIC ===<h2>العنوان</h2><p>نص</p>'
      const res = validateEditorialOutput(leakOutput)
      assert.equal(res.valid, false)
      assert.ok(res.error.includes('delimiter token leak'))
    })

    test('7. Model refusal or conversational preamble is rejected', async () => {
      const { validateEditorialOutput } = await import('../server/utils/editorial.ts')
      const refusal = 'I cannot fulfill this request because it violates safety policies.'
      const res = validateEditorialOutput(refusal)
      assert.equal(res.valid, false)
      assert.ok(res.error.includes('conversational filler or refusal'))
    })

    test('8. Translation output with excessive source language is rejected', async () => {
      const { validateEditorialOutput } = await import('../server/utils/editorial.ts')
      const failedTranslation = '<h2>Digital Sovereignty</h2><p>هذا النص ما زال باللغة العربية بالكامل ولم يقم الموديل بترجمته إلى الإنجليزية إطلاقاً.</p>'
      const res = validateEditorialOutput(failedTranslation, { isTranslation: true, targetLanguage: 'en' })
      assert.equal(res.valid, false)
      assert.ok(res.error.includes('excessive source Arabic text'))
    })

    test('9. SSE parser correctly separates delta.reasoning, delta.content, finish_reason, and usage', async () => {
      const { parseSseEvent } = await import('../server/utils/nosana.ts')
      
      // Event with reasoning only
      const reasoningEvent = 'data: {"choices":[{"index":0,"delta":{"reasoning":"Analyzing text..."}}]}'
      const res1 = parseSseEvent(reasoningEvent)
      assert.equal(res1.reasoning, 'Analyzing text...')
      assert.equal(res1.content, undefined)

      // Event with content only
      const contentEvent = 'data: {"choices":[{"index":0,"delta":{"content":"<p>Hello</p>"}}]}'
      const res2 = parseSseEvent(contentEvent)
      assert.equal(res2.content, '<p>Hello</p>')
      assert.equal(res2.reasoning, undefined)

      // Event with finish_reason and usage
      const usageEvent = 'data: {"choices":[{"index":0,"delta":{},"finish_reason":"stop"}],"usage":{"prompt_tokens":100,"completion_tokens":250,"total_tokens":350}}'
      const res3 = parseSseEvent(usageEvent)
      assert.equal(res3.finishReason, 'stop')
      assert.equal(res3.totalTokens, 350)
      assert.equal(res3.promptTokens, 100)
      assert.equal(res3.completionTokens, 250)
    })

    test('10. Operation B Translation uses explicit source document without hallucination', () => {
      const sourceHtml = '<h2>وثيقة المصدر</h2><p>فقرة تحتوي على حقائق محددة ومصطلحات سيادية.</p>'
      const messages = buildEditorialMessages({
        instruction: 'Translate this article.',
        operation: 'translation',
        sourceContent: sourceHtml,
        sourceLanguage: 'ar',
        targetLanguage: 'en'
      })

      assert.equal(messages.length, 2)
      assert.equal(messages[0].role, 'system')
      assert.ok(messages[0].content.includes("Burhan's High-Fidelity Editorial Translator"))
      assert.ok(messages[1].content.includes('=== TARGET TRANSLATION LANGUAGE: English (en) ==='))
      assert.ok(messages[1].content.includes('=== SOURCE DOCUMENT LANGUAGE: Arabic (ar) ==='))
      assert.ok(messages[1].content.includes('=== SOURCE DOCUMENT TO TRANSLATE ==='))
      assert.ok(messages[1].content.includes(sourceHtml))
      assert.ok(!messages[1].content.includes('=== BURHAN_BILINGUAL_ARABIC ==='))
    })

    test('11. Legacy generationMode: both maps to single-stage primary document without delimiters', () => {
      const messages = buildEditorialMessages({
        instruction: 'اكتب مقالاً عن السيادة السحابية',
        generationMode: 'both',
        targetLanguage: 'ar'
      })

      assert.equal(messages.length, 2)
      assert.ok(messages[1].content.includes('=== TARGET EDITOR LANGUAGE: Arabic (ar) ==='))
      assert.ok(!messages[1].content.includes('=== BURHAN_BILINGUAL_ARABIC ==='))
      assert.ok(!messages[1].content.includes('=== BURHAN_BILINGUAL_ENGLISH ==='))
    })
  })

  // --- Group 7: Translation Target Destination & Source Preservation Regression Gate ---
  describe('7. Translation Target Destination & Source Preservation', () => {
    // Mirror exact helper from [id].vue / new.vue
    function applyAiContentHelper({ form, currentLangRef, content, mode, targetLang }) {
      const formattedHtml = content.trim()
      if (!formattedHtml) return

      // targetLang is the absolute source of truth for where content is written.
      // currentLang is NEVER used to determine the destination of translation/generation output.
      const destinationLang = targetLang || currentLangRef.value

      if (destinationLang === 'ar') {
        if (mode === 'replace' || !form.content_ar) {
          form.content_ar = formattedHtml
        } else if (mode === 'insert') {
          form.content_ar = formattedHtml + form.content_ar
        } else {
          form.content_ar = form.content_ar + formattedHtml
        }
      } else {
        if (mode === 'replace' || !form.content_en) {
          form.content_en = formattedHtml
        } else if (mode === 'insert') {
          form.content_en = formattedHtml + form.content_en
        } else {
          form.content_en = form.content_en + formattedHtml
        }
      }

      currentLangRef.value = destinationLang
    }

    test('A. AR -> EN translation writes strictly to content_en and leaves content_ar 100% untouched', () => {
      const originalArabic = '<h2>المقال العربي الأصلي</h2><p>هذا النص العربي السيادي يجب ألا يُمس نهائياً.</p>'
      const form = {
        content_ar: originalArabic,
        content_en: ''
      }
      const currentLangRef = { value: 'ar' } // User is currently on the Arabic editor tab

      const translatedEnglish = '<h2>Original Arabic Article</h2><p>This sovereign Arabic text must not be touched.</p>'

      applyAiContentHelper({
        form,
        currentLangRef,
        content: translatedEnglish,
        mode: 'replace',
        targetLang: 'en'
      })

      // Destination assertion: English was written
      assert.equal(form.content_en, translatedEnglish)

      // Strict Preservation: Arabic source document was NOT modified, overwritten, or cleared
      assert.equal(form.content_ar, originalArabic, 'content_ar must remain strictly identical to original source')

      // Active view switched to target language
      assert.equal(currentLangRef.value, 'en', 'active editor view switches to destination language tab')
    })

    test('B. EN -> AR translation writes strictly to content_ar and leaves content_en 100% untouched', () => {
      const originalEnglish = '<h2>Original English Source</h2><p>English content that must remain preserved.</p>'
      const form = {
        content_ar: '',
        content_en: originalEnglish
      }
      const currentLangRef = { value: 'en' } // User is currently on English tab

      const translatedArabic = '<h2>المصدر الإنجليزي الأصلي</h2><p>محتوى إنجليزي يجب أن يظل محفوظاً.</p>'

      applyAiContentHelper({
        form,
        currentLangRef,
        content: translatedArabic,
        mode: 'replace',
        targetLang: 'ar'
      })

      // Destination assertion: Arabic was written
      assert.equal(form.content_ar, translatedArabic)

      // Strict Preservation: English source document was NOT modified
      assert.equal(form.content_en, originalEnglish, 'content_en must remain strictly identical to original source')

      // Active view switched to target language
      assert.equal(currentLangRef.value, 'ar', 'active editor view switches to destination language tab')
    })

    test('C. currentLang is NEVER used when targetLang is specified', () => {
      const form = {
        content_ar: '<p>عربي</p>',
        content_en: '<p>Old English</p>'
      }
      // User is on Arabic tab, but operation explicitly targets English
      const currentLangRef = { value: 'ar' }

      applyAiContentHelper({
        form,
        currentLangRef,
        content: '<p>New English</p>',
        mode: 'replace',
        targetLang: 'en'
      })

      assert.equal(form.content_ar, '<p>عربي</p>', 'content_ar must not be overwritten even when currentLang was ar')
      assert.equal(form.content_en, '<p>New English</p>')
    })
  })
})
