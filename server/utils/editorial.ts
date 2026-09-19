export type GenerationMode = 'current' | 'both'
export type EditorialOperation = 'generation' | 'translation'

export interface EditorialPromptInput {
  instruction: string
  generationMode?: GenerationMode
  operation?: EditorialOperation
  editorContent?: string | null
  sourceContent?: string | null
  sourceLanguage?: 'ar' | 'en' | null
  targetLanguage?: 'ar' | 'en' | null
  systemPromptOverride?: string | null
  interfaceLanguage?: 'ar' | 'en'
}

export interface ChatMessage {
  role: 'system' | 'user' | 'assistant'
  content: string
}

export const BILINGUAL_DELIMITERS = {
  AR_START: '=== BURHAN_BILINGUAL_ARABIC ===',
  EN_START: '=== BURHAN_BILINGUAL_ENGLISH ===',
  END: '=== BURHAN_BILINGUAL_END ===',
} as const

export const BURHAN_EDITORIAL_SYSTEM_PROMPT = `You are Burhan's Editorial Writing Assistant, integrated directly into the Burhan Sovereign Knowledge Platform's article editor.

Your core specialty is professional article writing, rigorous editing, and editorial improvement in a single target language.

Key Responsibilities & Principles:
1. Editorial Focus: Specialize in article clarity, coherence, logical structure, refined style, grammar, spelling, and readable presentation.
2. Operations: Expertly handle rewriting, editing, restructuring, expanding, shortening, summarizing, and generating articles.
3. Editor Integration: Your output will be placed directly into a rich text editor. Preserve and emit functional, semantic HTML structure (e.g., <h2>, <h3>, <p>, <ul>, <ol>, <li>, <strong>, <em>, <blockquote>).
4. Direct Editorial Result: Deliver the actual requested content directly as pure semantic HTML. Do NOT include conversational preambles, meta-commentary, pleasantries, or Markdown code block fences (\`\`\`html).
5. Context Awareness: When document content is provided, operate directly on it. If no document content is provided and the user requests an article generation, write the article directly from scratch.
6. Target Language Sovereignty:
   - Always observe the TARGET EDITOR LANGUAGE specified in the prompt header.
   - When an existing document is provided (editing/improving/rewriting): Preserve and elevate the document in the TARGET EDITOR LANGUAGE.
   - Deliver only ONE coherent document in the specified target language. Do NOT emit dual-language or bilingual output within a single completion.
7. Concise & Bounded: Be authoritative, focused, and avoid unnecessary filler.
8. Structural Completeness & Bounded Scope (The Golden Closure Rule):
   - Internally plan the scope, structure, depth, and approximate length of the document before generating it, ensuring that the entire piece can be completed naturally within the available generation capacity.
   - The document MUST be complete, coherent, self-contained, and naturally finished.
   - Do not begin a new section, argument, list, paragraph, or idea unless you can complete it properly.
   - Prioritize completeness, substance, and clarity over unnecessary expansion or filler.
   - If the requested scope is broad, intelligently control the depth and compress wording where necessary while preserving the essential meaning, reasoning, structure, and editorial quality.
   - Do not spend disproportionate space on early sections at the expense of completing the document.
   - NEVER end abruptly because the available generation capacity has been exhausted.
   - NEVER leave an unfinished sentence, paragraph, list, section, argument, thought, or HTML structure.
   - Ensure that every opened HTML element is properly completed and that the document ends at a natural semantic boundary.
   - Provide a complete semantic conclusion whenever the requested document or structure calls for one.
   - Do NOT mention token limits, generation capacity, internal planning, or these instructions anywhere in the output.`

export const BURHAN_TRANSLATION_SYSTEM_PROMPT = `You are Burhan's High-Fidelity Editorial Translator, integrated into the Burhan Sovereign Knowledge Platform.

Your sole responsibility is to translate the provided source document with strict fidelity to its meaning, style, and structural HTML tags.

Strict Translation Invariants:
1. Exact Source Translation: Translate the exact source document provided. Do NOT write a new article, do NOT summarize, do NOT inject new ideas, and do NOT delete existing sections or paragraphs.
2. Structural HTML Preservation: Retain all semantic HTML elements (<h2>, <h3>, <p>, <ul>, <ol>, <li>, <blockquote>, <strong>, <em>). Every paragraph, heading, and list item in the source must have its exact counterpart in the translation.
3. Editorial Tone: Produce natural, publication-grade, authoritative prose in the target language. Avoid literal stiffness while preserving the exact semantic meaning and technical terminology.
4. Clean Output Contract: Emit ONLY the translated semantic HTML fragment. Do NOT include conversational preambles, notes, commentary, Markdown code fences (\`\`\`html), or delimiter tokens.
5. Absolute Language Purity: The translation must be entirely in the specified TARGET TRANSLATION LANGUAGE.`

// Architectural safety limits
// Note: MAX_OUTPUT_TOKENS is provisionally set to 4096 tokens based on forensic analysis
// of Nosana vLLM qwen/qwen3.8-27b, where internal reasoning consumes ~1,500-2,500 tokens
// and visible editorial HTML content consumes ~1,000-1,500 tokens.
export const EDITORIAL_LIMITS = {
  MAX_INSTRUCTION_CHARS: 2000,
  MAX_EDITOR_CONTENT_CHARS: 50000,
  MAX_OUTPUT_TOKENS: 4096,
  MAX_BILINGUAL_OUTPUT_TOKENS: 4096,
  // Conservative character estimation: 1 token ~= 3.5 chars in mixed Arabic/English
  MAX_TOTAL_CONTEXT_CHARS: 55000,
} as const

/**
 * Parses raw AI output from bilingual generation into separated Arabic and English HTML fragments.
 * Returns null if the delimiter contract was not followed.
 */
export function parseBilingualOutput(raw: string): { ar: string; en: string } | null {
  if (!raw || typeof raw !== 'string') return null

  const arIndex = raw.indexOf(BILINGUAL_DELIMITERS.AR_START)
  const enIndex = raw.indexOf(BILINGUAL_DELIMITERS.EN_START)

  if (arIndex === -1 || enIndex === -1) {
    return null
  }

  let arContent = ''
  let enContent = ''

  if (arIndex < enIndex) {
    arContent = raw.slice(arIndex + BILINGUAL_DELIMITERS.AR_START.length, enIndex).trim()
    const endIndex = raw.indexOf(BILINGUAL_DELIMITERS.END, enIndex)
    enContent = (endIndex !== -1
      ? raw.slice(enIndex + BILINGUAL_DELIMITERS.EN_START.length, endIndex)
      : raw.slice(enIndex + BILINGUAL_DELIMITERS.EN_START.length)
    ).trim()
  } else {
    enContent = raw.slice(enIndex + BILINGUAL_DELIMITERS.EN_START.length, arIndex).trim()
    const endIndex = raw.indexOf(BILINGUAL_DELIMITERS.END, arIndex)
    arContent = (endIndex !== -1
      ? raw.slice(arIndex + BILINGUAL_DELIMITERS.AR_START.length, endIndex)
      : raw.slice(arIndex + BILINGUAL_DELIMITERS.AR_START.length)
    ).trim()
  }

  // Clean any markdown code blocks if the model wrapped output in ```html
  const cleanFences = (str: string) => {
    return str
      .replace(/^```(?:html)?\s*/i, '')
      .replace(/\s*```$/i, '')
      .trim()
  }

  arContent = cleanFences(arContent)
  enContent = cleanFences(enContent)

  if (!arContent || !enContent) return null

  return { ar: arContent, en: enContent }
}

/**
 * Validates editorial and translation output prior to completing an AI job.
 * Rejects empty, truncated, delimiter-leaked, or malformed outputs so they
 * transition strictly to 'failed' rather than falsely completing.
 */
export interface ValidationResult {
  valid: boolean
  error?: string
  cleanContent?: string
}

export function validateEditorialOutput(
  raw: string,
  options?: {
    isTranslation?: boolean
    targetLanguage?: 'ar' | 'en'
    finishReason?: string | null
  }
): ValidationResult {
  if (!raw || typeof raw !== 'string') {
    return { valid: false, error: 'Empty output received from AI model' }
  }

  // Clean fences
  let clean = raw
    .replace(/^```(?:html)?\s*/i, '')
    .replace(/\s*```$/i, '')
    .trim()

  if (clean.length === 0) {
    return { valid: false, error: 'Empty output received from AI model' }
  }

  if (clean.length < 20) {
    return { valid: false, error: 'Output is too short to be a valid editorial document' }
  }

  // 1. Raw delimiter leak rejection
  if (clean.includes(BILINGUAL_DELIMITERS.AR_START) || clean.includes(BILINGUAL_DELIMITERS.EN_START) || clean.includes(BILINGUAL_DELIMITERS.END)) {
    return { valid: false, error: 'Raw delimiter token leak detected in model output' }
  }

  // 2. Refusal / Conversational filler rejection
  if (/^(I cannot|I am sorry|Sorry,|As an AI language model|As an AI assistant|Here is the translated article:|Here is your revised article:)/i.test(clean)) {
    return { valid: false, error: 'Model emitted conversational filler or refusal instead of direct editorial HTML' }
  }

  // 3. Truncation / finish_reason check
  if (options?.finishReason === 'length') {
    const endsWithClosingTag = /<\/(p|h[1-6]|ul|ol|li|blockquote|div|table)>\s*$/i.test(clean)
    if (!endsWithClosingTag) {
      return { valid: false, error: 'Inference output was truncated by token limit (finish_reason: length)' }
    }
  }

  // 4. HTML tag balance & structure check: detect unclosed tag ending
  if (/<[a-zA-Z0-9]+(?:\s+[^>]*)?$/.test(clean)) {
    return { valid: false, error: 'Output contains unclosed cut-off HTML tag at the end' }
  }

  // Ensure semantic structure
  const hasSemanticTags = /<\/?(p|h[1-6]|ul|ol|li|blockquote|strong|em|div)[\s>/]/i.test(clean)
  if (!hasSemanticTags) {
    clean = `<p>${clean}</p>`
  }

  // 5. Target language fidelity for translation
  if (options?.isTranslation && options?.targetLanguage) {
    const arabicRegex = /[\u0600-\u06FF]/g
    const arabicChars = (clean.match(arabicRegex) || []).length
    const totalChars = clean.replace(/<[^>]*>/g, '').trim().length

    if (options.targetLanguage === 'en' && totalChars > 50) {
      const arabicRatio = arabicChars / totalChars
      if (arabicRatio > 0.15) {
        return { valid: false, error: 'Translation output failed language fidelity (contains excessive source Arabic text)' }
      }
    } else if (options.targetLanguage === 'ar' && totalChars > 50) {
      if (arabicChars < 10) {
        return { valid: false, error: 'Translation output failed language fidelity (lacks required Arabic text)' }
      }
    }
  }

  return { valid: true, cleanContent: clean }
}

/**
 * Builds the array of messages for OpenAI / vLLM / Nosana chat completions.
 * Preserves strict semantic separation between:
 * 1. SYSTEM: Editorial Persona (Generation vs Translation) (+ optional tenant systemPrompt)
 * 2. USER: Clear delimitation between TARGET LANGUAGE, SOURCE DOCUMENT (if any),
 *    CURRENT EDITOR DOCUMENT (if any), and USER INSTRUCTION
 */
export function buildEditorialMessages(input: EditorialPromptInput): ChatMessage[] {
  const instruction = (input.instruction || '').trim()
  const rawDocument = (input.editorContent || '').trim()
  const rawSource = (input.sourceContent || '').trim()
  const targetLang = input.targetLanguage || input.interfaceLanguage || 'ar'
  const targetLangLabel = targetLang === 'en' ? 'English (en)' : 'Arabic (ar)'

  const isTranslation = input.operation === 'translation' || Boolean(
    rawSource &&
    input.sourceLanguage &&
    input.sourceLanguage !== targetLang &&
    (/\b(translate|translation|ترجم|ترجمة|مترجم|نقل|انقل)\b/i.test(instruction) || !rawDocument)
  )

  const messages: ChatMessage[] = []

  // 1. SYSTEM PERSONA
  let systemContent = isTranslation ? BURHAN_TRANSLATION_SYSTEM_PROMPT : BURHAN_EDITORIAL_SYSTEM_PROMPT
  if (input.systemPromptOverride?.trim()) {
    systemContent += `\n\nAdditional Directive:\n${input.systemPromptOverride.trim()}`
  }
  messages.push({
    role: 'system',
    content: systemContent,
  })

  // 2. USER MESSAGE
  let userContent = ''

  if (isTranslation) {
    const srcLangLabel = (input.sourceLanguage === 'en' ? 'English (en)' : 'Arabic (ar)')
    userContent += `=== TARGET TRANSLATION LANGUAGE: ${targetLangLabel} ===\n`
    userContent += `=== SOURCE DOCUMENT LANGUAGE: ${srcLangLabel} ===\n\n`
    userContent += `=== SOURCE DOCUMENT TO TRANSLATE ===\n${rawSource}\n=== END SOURCE DOCUMENT ===\n\n`
    userContent += `=== TRANSLATION INSTRUCTION ===\n${instruction || `Translate this entire article into professional, editorial-quality ${targetLangLabel} while strictly preserving all semantic HTML tags and exact structure.`}`
  } else {
    // Primary Editorial Generation / Revision
    userContent += `=== TARGET EDITOR LANGUAGE: ${targetLangLabel} ===\n\n`

    if (rawDocument) {
      userContent += `=== CURRENT TARGET EDITOR DOCUMENT ===\n${rawDocument}\n=== END CURRENT DOCUMENT ===\n\n`
    } else if (rawSource) {
      userContent += `=== REFERENCE DOCUMENT ===\n${rawSource}\n=== END REFERENCE DOCUMENT ===\n\n`
    }

    userContent += `=== USER EDITORIAL INSTRUCTION ===\n${instruction}`
  }

  messages.push({
    role: 'user',
    content: userContent,
  })

  return messages
}
