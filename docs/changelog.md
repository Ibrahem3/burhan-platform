# Changelog

All notable changes to this project will be documented in this file.

## [2026-09-19] - UI Fix: Desktop FloatingSidebar Smooth Hover & Jitter Elimination

### Changed
- [`app/components/dashboard/FloatingSidebar.vue`](../app/components/dashboard/FloatingSidebar.vue):
  - Replaced pure CSS `:hover` hitbox oscillation with state-driven `isHovered` and safe `mouseenter`/`mouseleave` debounce timer (250ms buffer).
  - Pinned transform origins (`bottom right` for RTL, `bottom left` for LTR) to eliminate hit-testing boundary jumps.
  - Upgraded transition curves to high-performance fluid `cubic-bezier(0.16, 1, 0.3, 1)` preventing jitter and sluggish open/close.

### Rationale
- Fixes desktop UI annoyance where cursor crossing the spherical bubble boundary triggered rapid expand/collapse oscillation (hover jitter).

## [2026-09-19] - Project Licensing: GNU Affero General Public License v3.0 (AGPL-3.0)

### Changed
- [`LICENSE`](../LICENSE):
  - Provisioned official GNU Affero General Public License v3.0 text with Copyright 2026 Burhan Platform Contributors.
- [`README.md`](../README.md):
  - Updated license badge to official AGPL-3.0 shield.
  - Formally declared AGPL-3.0 terms in Section 4 with rationale: Anti-SaaS loophole closure, preservation of digital commons, and sovereign reciprocity.

### Rationale
- Enforces copyleft protection against proprietary cloud/SaaS freeloading, guaranteeing that any entity hosting or modifying Burhan as a network service must reciprocate by sharing source code under the same sovereign terms.

## [2026-09-19] - Editorial AI UI: Remove Legacy Single-Shot Bilingual Toggle & Clean Modals

### Changed
- [`app/components/dashboard/EntityAiAssistantModal.vue`](../app/components/dashboard/EntityAiAssistantModal.vue):
  - Removed obsolete "🌐 توليد ثنائي (عربي + إنجليزي)" toggle and tabs.
  - Aligned the UI with the decoupled architecture: primary generation targets the active editor language, while independent direct translation handles cross-language transformation.
  - Cleaned up unused legacy `@apply-both` event and dual-column preview code.
- [`app/pages/dashboard/entities/[id].vue`](../app/pages/dashboard/entities/[id].vue) & [`app/pages/dashboard/entities/new.vue`](../app/pages/dashboard/entities/new.vue):
  - Removed unused `applyBilingualContent` handler and `@apply-both` listeners.

### Rationale
- Prevents user confusion by removing legacy single-shot completion controls that previously led to model token starvation, enforcing the reliable two-stage editorial workflow.

## [2026-09-19] - Editorial AI: Principle 8 (Structural Completeness & Bounded Scope / Golden Closure Rule)

### Changed
- [`server/utils/editorial.ts`](../server/utils/editorial.ts):
  - Injected `Principle 8: Structural Completeness & Bounded Scope (The Golden Closure Rule)` into `BURHAN_EDITORIAL_SYSTEM_PROMPT`.
  - Mandated internal planning of document scope and length within available generation capacity.
  - Strictly forbade abrupt cut-offs, disproportionate section weighting, and unclosed HTML elements or incomplete thoughts.
- [`tests/editorial.test.mjs`](../tests/editorial.test.mjs):
  - Verified full test suite passes (30/30 tests pass).

### Rationale
- Guides reasoning models (e.g. Qwen 2.5/3) to naturally pace and complete long-form articles within their output budget without cutting off prematurely or exhausting capacity mid-section.

## [2026-09-19] - Editorial AI Fix: Target Language Destination Authority & Source Preservation

### Changed
- [`app/components/dashboard/EntityAiAssistantModal.vue`](../app/components/dashboard/EntityAiAssistantModal.vue):
  - Tracked `activeTargetLang` state during translation and generation operations.
  - Emitted `targetLang` with `@apply` event (`emit('apply', { content, mode, targetLang })`).
- [`app/pages/dashboard/entities/[id].vue`](../app/pages/dashboard/entities/[id].vue) & [`app/pages/dashboard/entities/new.vue`](../app/pages/dashboard/entities/new.vue):
  - Made `targetLang` the absolute source of truth for write destination in `applyAiContent`.
  - Disconnected `currentLang` from determining the storage target.
  - Translation from AR→EN writes strictly to `form.content_en` and leaves `form.content_ar` 100% untouched.
  - Translation from EN→AR writes strictly to `form.content_ar` and leaves `form.content_en` 100% untouched.
  - Switched the active editor tab view (`currentLang.value = destinationLang`) so the user immediately inspects the newly written translation.
- [`tests/editorial.test.mjs`](../tests/editorial.test.mjs):
  - Added Group 7 regression tests asserting `targetLang` authority, source document zero-mutation invariant, and `currentLang` isolation (30/30 pass).

### Rationale
- Fixes critical UX flaw where translating from Arabic to English while on the Arabic editor tab caused the translated English output to overwrite the Arabic source document instead of saving into the English editor field.


## [2026-09-19] - Editorial AI Phase 1: Decoupled Multi-Stage Backend & Strict Output Validation

### Changed
- [`server/utils/editorial.ts`](../server/utils/editorial.ts):
  - **Decoupled Operations Architecture:** Eliminated single-shot bilingual generation (`generationMode: both` in one completion). Replaced with two discrete operations: `Operation A: Primary Editorial Generation` and `Operation B: High-Fidelity Translation`.
  - **Strict Translation Contract:** Introduced `BURHAN_TRANSLATION_SYSTEM_PROMPT` ensuring exact source-faithful translation without new ideas, summaries, commentary, deletion, or delimiter leaks.
  - **Rigid Output Validation:** Added `validateEditorialOutput(raw, options)` enforcing rejection of empty output, short responses (<20 chars), raw delimiter leaks, conversational preambles/refusals, and truncated outputs on `finish_reason: "length"`.
  - **Provisional Token Budget:** Set `MAX_OUTPUT_TOKENS: 4096` based on empirical Nosana Qwen-3 vLLM profile (internal reasoning consumes ~1,500-2,500 tokens, content consumes ~1,000-1,500 tokens).
- [`server/utils/nosana.ts`](../server/utils/nosana.ts):
  - **Reasoning-Resilient Heartbeat:** Updated SSE streaming loop so liveness heartbeats (`heartbeat_ai_job`) fire every 3s continuously during the pure `delta.reasoning` phase, preventing database watchdog reapers from falsely marking jobs stale while the model thinks.
  - **Full Provider Chunk Parser:** Extended `parseSseEvent` to extract `delta.content`, `delta.reasoning`, `finish_reason`, `usage.total_tokens`, `usage.prompt_tokens`, and `usage.completion_tokens`.
  - **Server-Side Validation Gate:** Validates raw output with `validateEditorialOutput` before transitioning jobs to terminal state. Fails gracefully with `fail_ai_job` if validation fails, preventing false `completed` jobs with empty or truncated content.
  - **Observability Logging:** Added sanitized, structured operational logging (model, operation, finishReason, promptTokens, completionTokens, totalTokens, outputLength) without leaking secrets or sensitive text.
- [`server/api/ai/generate.post.ts`](../server/api/ai/generate.post.ts):
  - Extracted `operation` parameter (`generation` vs `translation`).
  - Passed operation to `runInference`. Legacy `generationMode: 'both'` requests gracefully map to single-stage primary document generation.
- [`tests/editorial.test.mjs`](../tests/editorial.test.mjs):
  - Updated and expanded to 27 unit tests verifying decoupled prompts, translation persona, output validator rules, parser behavior, and delimiter-free generation (27/27 pass).
- [`tests/nosana-parser.test.mjs`](../tests/nosana-parser.test.mjs):
  - Updated to verify reasoning-only chunks are captured without leaking into content (7/7 pass).

### Rationale
- Forensic analysis proved that single-shot bilingual generation causes fatal token exhaustion due to vLLM Qwen internal reasoning tokens consuming the completion budget. Decoupling primary generation and translation into discrete, validated stages eliminates truncation, guarantees structural fidelity, and ensures quota accounting matches delivered value.



## [2026-09-19] - Bilingual Editorial AI Generation & Direct Translation Pipeline

### Changed
- [`server/utils/editorial.ts`](../server/utils/editorial.ts):
  - Added `GenerationMode = 'current' | 'both'`.
  - Introduced `BILINGUAL_DELIMITERS` contract (`=== BURHAN_BILINGUAL_ARABIC ===`, `=== BURHAN_BILINGUAL_ENGLISH ===`, `=== BURHAN_BILINGUAL_END ===`) enforcing dual-version output generation in a single inference call.
  - Implemented `parseBilingualOutput(raw)` extracting clean, independent semantic HTML fragments for both languages with automatic markdown code-fence sanitization.
  - Defined `MAX_BILINGUAL_OUTPUT_TOKENS: 3500` to prevent truncation during dual output generation.
- [`server/utils/nosana.ts`](../server/utils/nosana.ts):
  - Extended `RunInferenceInput` to accept `generationMode`.
  - Dynamically configured `max_tokens` (3,500 for `both`, 2,048 for `current`) in Nosana `/v1/chat/completions` payload.
- [`server/api/ai/generate.post.ts`](../server/api/ai/generate.post.ts):
  - Extracted `generationMode` from request body.
  - Set `p_language: isBilingual ? 'both' : resolvedTargetLang` and allocated `p_tokens_estimated: isBilingual ? 1000 : 500` to guarantee atomicity and prevent concurrent quota overdraft.
- [`app/composables/useAiGenerate.ts`](../app/composables/useAiGenerate.ts):
  - Extended `AiGenerateOptions` and `AiJobState` with `outputBilingual: { ar, en } | null`.
  - Added automatic delimiter parsing during job completion polling.
- [`app/components/dashboard/EntityAiAssistantModal.vue`](../app/components/dashboard/EntityAiAssistantModal.vue):
  - Added UI Scope selector toggle: **اللغة الحالية** (`current`) vs **توليد ثنائي** (`both`).
  - Added direct quick translation actions (**ترجمة للإنجليزية** / **ترجمة للعربية**) with explicit overwrite confirmation protection when the target editor already contains content.
  - Added dual-pane output preview when bilingual results are returned.
  - Added `@apply-both` event emission providing `{ ar, en, mode }`.
- [`app/pages/dashboard/entities/[id].vue`](../app/pages/dashboard/entities/[id].vue) & [`app/pages/dashboard/entities/new.vue`](../app/pages/dashboard/entities/new.vue):
  - Added `applyBilingualContent({ ar, en, mode })` updating both `form.content_ar` and `form.content_en` concurrently while preserving Tiptap HTML formatting.
  - Bound `@apply-both="applyBilingualContent"` on `<EntityAiAssistantModal>`.
- [`tests/editorial.test.mjs`](../tests/editorial.test.mjs):
  - Added Group 6 test suite verifying bilingual prompt assembly, delimiter extraction, fence sanitization, and malformed output rejection (22/22 pass).

### Rationale
- Enables seamless bilingual article authoring in a single AI generation request, eliminating manual context re-entry across tabs, while preserving strict single-language behavior, robust quota accounting, and explicit overwrite safeguards.


## [2026-09-19] - Editorial AI Surgical Fix: HTML Semantic Insertion, Target Language Sovereignty & Bilingual Source Reference Flow

### Changed
- [`app/pages/dashboard/entities/[id].vue`](../app/pages/dashboard/entities/[id].vue) & [`app/pages/dashboard/entities/new.vue`](../app/pages/dashboard/entities/new.vue):
  - **Semantic HTML Preservation:** Replaced crude string splitting (`.split(/\n\s*\n/).map(p => '<p>...')`) in `applyAiContent` with `formatAiContentForEditor(raw)`. It detects semantic HTML block tags (`<h2>`, `<p>`, `<ul>`, etc.) and preserves them verbatim for direct Tiptap ingestion without creating invalid nested `<p><h2>` wrappers, while retaining fallback wrapping for plain-text models.
  - **Bilingual Source Wiring:** Passed `:source-content="currentLang === 'ar' ? form.content_en : form.content_ar"` and `:source-language="currentLang === 'ar' ? 'en' : 'ar'"` to `<EntityAiAssistantModal>`.
- [`app/components/dashboard/EntityAiAssistantModal.vue`](../app/components/dashboard/EntityAiAssistantModal.vue):
  - Added `sourceContent` and `sourceLanguage` props.
  - Added explicit regex-based translation detection (`isTranslationRequest`). Forwards `sourceContent` to `/api/ai/generate` ONLY when the user explicitly requests translation, saving tokens and eliminating prompt ambiguity during monolingual edits.
  - Added UI indicator badges clarifying the active Target Language, document connection state, and translation source availability.
- [`app/composables/useAiGenerate.ts`](../app/composables/useAiGenerate.ts):
  - Extended `AiGenerateOptions` to accept `sourceContent`, `sourceLanguage`, and `targetLanguage`, and forwarded them in the `POST /api/ai/generate` payload.
- [`server/api/ai/generate.post.ts`](../server/api/ai/generate.post.ts):
  - Extracted `sourceContent`, `sourceLanguage`, and `targetLanguage` from request body.
  - Validated source content against `EDITORIAL_LIMITS.MAX_EDITOR_CONTENT_CHARS` (50,000 chars) and overall context against `EDITORIAL_LIMITS.MAX_TOTAL_CONTEXT_CHARS` (55,000 chars).
  - Passed `resolvedTargetLang` to `create_ai_job` and all parameters to `runInference`.
- [`server/utils/editorial.ts`](../server/utils/editorial.ts) & [`server/utils/nosana.ts`](../server/utils/nosana.ts):
  - Injected `=== TARGET EDITOR LANGUAGE: [Arabic|English] ===` as a rigid contract header in the user prompt.
  - Added formatted `=== SOURCE REFERENCE DOCUMENT (language) ===` section when cross-language translation is requested.
  - Clarified persona instructions in `BURHAN_EDITORIAL_SYSTEM_PROMPT`: editing preserves document language; empty editor generates in target language; explicit translation adapts source into target language.
- [`tests/editorial.test.mjs`](../tests/editorial.test.mjs):
  - Added 18 unit tests covering prompt construction, source reference document formatting, HTML preservation in `formatAiContentForEditor`, persona anti-filler directives, and language sovereignty rules.

### Rationale
- Solves the 3 identified architectural failure points: prevents Tiptap HTML degradation upon AI insertion, guarantees language adherence to the active editor tab, and enables cross-lingual translation between Arabic and English tabs without leaking opposite content into monolingual edits.


## [2026-09-19] - Editorial AI Persona, Document Context Integration & Generation Safety Boundaries

### Changed
- [`server/utils/editorial.ts`](../server/utils/editorial.ts):
  - Created dedicated server-side editorial module containing `BURHAN_EDITORIAL_SYSTEM_PROMPT` establishing Burhan's professional writing assistant persona (article writing, editing, restructuring, clarity, style, grammar, semantic HTML formatting, zero conversational preambles).
  - Implemented dynamic language sovereignty logic (Arabic article + Arabic instruction -> Arabic, English article + English instruction -> English, cross-language preserving document language unless translation explicitly demanded, no universal forced fallback).
  - Built `buildEditorialMessages` ensuring strict semantic separation between SYSTEM persona, USER instruction, and CURRENT EDITOR DOCUMENT delimiters.
  - Defined explicit architectural safety limits: `MAX_INSTRUCTION_CHARS: 2000`, `MAX_EDITOR_CONTENT_CHARS: 50000`, `MAX_OUTPUT_TOKENS: 2048`, `MAX_TOTAL_CONTEXT_CHARS: 55000`.
- [`server/utils/nosana.ts`](../server/utils/nosana.ts):
  - Integrated `buildEditorialMessages` to construct provider chat messages dynamically.
  - Added `editorContent?: string | null` to `RunInferenceInput`.
  - Enforced `max_tokens: EDITORIAL_LIMITS.MAX_OUTPUT_TOKENS` (2048) in fetch payload sent to provider `/v1/chat/completions`, eliminating unbounded generation.
- [`server/api/ai/generate.post.ts`](../server/api/ai/generate.post.ts):
  - Extracted `editorContent` from request body and passed to `runInference`.
  - Implemented strict server-side validation rejecting oversized prompts (> 2,000 chars), oversized editor content (> 50,000 chars), and total context overflow (> 55,000 chars) with descriptive HTTP 400 Bad Request errors.
- [`app/composables/useAiGenerate.ts`](../app/composables/useAiGenerate.ts):
  - Added `editorContent?: string | null` to `AiGenerateOptions` and forwarded it in the POST `/api/ai/generate` body.
- [`app/components/dashboard/EntityAiAssistantModal.vue`](../app/components/dashboard/EntityAiAssistantModal.vue):
  - Added `editorContent` prop with default `null`, passing it directly to `useAiGenerate`.
  - Added visual document connection status pill indicating whether the active editor document is connected (editing/review mode) or empty (generation from scratch mode).
- [`app/pages/dashboard/entities/[id].vue`](../app/pages/dashboard/entities/[id].vue) & [`app/pages/dashboard/entities/new.vue`](../app/pages/dashboard/entities/new.vue):
  - Bound `:editor-content="currentLang === 'ar' ? form.content_ar : form.content_en"` to `<EntityAiAssistantModal>`, closing the missing link from Tiptap editor state to server inference.
- [`tests/editorial.test.mjs`](../tests/editorial.test.mjs):
  - Added 17 unit tests verifying editor contract, prompt construction, empty document behavior, persona anti-filler directives, dynamic language rules, semantic HTML formatting, and boundary limits.

### Rationale
- Fixes the disconnect where active editor content was omitted from AI generation requests, establishes a rigorous server-side editorial persona producing rich semantic HTML directly into Tiptap, dynamically honors language sovereignty, and enforces strict server-side safety boundaries on input length and output tokens.


## [2026-09-19] - Nosana vLLM SSE Compatibility & Usage Accounting Alignment

### Changed
- [`server/utils/nosana.ts`](../server/utils/nosana.ts):
  - **SSE Content Extraction:** Updated `parseSseEvent` to parse OpenAI/vLLM nested stream chunks matching `choices[0].delta.content`, safely ignoring `delta.reasoning` chunks to prevent reasoning contamination into user output. Maintained fallback for legacy flat stream payloads.
  - **Token Usage Extraction:** Added extraction of `usage.total_tokens` from final stream chunks and piped `tokensUsed` into `complete_ai_job` terminal RPC, replacing estimated placeholder debits with real provider usage.
  - **ESM Module Resolution:** Fixed relative imports to explicitly include file extensions for clean Node.js ESM execution.
- [`tests/nosana-parser.test.mjs`](../tests/nosana-parser.test.mjs):
  - Added comprehensive test suite covering content extraction, reasoning avoidance, `[DONE]` handling, token extraction, absent usage fallback, and resilience against malformed chunks.

### Rationale
- Aligns Burhan AI inference engine with Nosana's real OpenAI/vLLM-compatible streaming response schema while strictly honoring the locked M1 contract and maintaining immutable terminal reconciliation.


## [2026-09-18] - Sovereign Research Demo Organizations & Official Seed Baseline

### Changed
- [`supabase/seed.sql`](../supabase/seed.sql):
  - Codified the official reproducible seed data baseline for Burhan Platform with zero-delete migration safety.
  - Configured 3 sovereign Web3 / DeAI research organizations (`burhan-lab`, `nosana-deai`, `open-archives`) with bilingual Arabic/English names and descriptions.
  - Linked each organization with active subscriptions, primary branches, curriculum series tracks, and verifiable published articles.
  - Ensured all demo entities have `is_public_to_hub: true`, `is_premium: false`, and `content_type: 'article'`, populating dynamic active content counters on public cards.
- [`.gitignore`](../.gitignore):
  - Ignored `supabase/.temp/` CLI cache directory.

### Rationale
- Elevates Burhan Platform from crude development test placeholders to an authoritative, verifiable sovereign knowledge showcase while strictly preserving all existing database UUIDs, foreign keys, and user profile relationships without schema or code modifications.



## [2026-09-18] - Sovereign Course Detail Page Overhaul & Start Learning CTA Fix

### Changed
- [`app/pages/[org_slug]/series/[id].vue`](../app/pages/[org_slug]/series/[id].vue):
  - **Start Learning CTA Fix:** Fixed the "Start Learning Now 🚀" button which was previously an inert anchor link (`href="#lesson-xxx"`) appending hashes without scrolling or starting the lecture. Re-engineered the button to directly route the user into the first lesson (`/${orgSlugParam}/content/${lessons[0].id}`).
  - **Syllabus Smooth Scroll:** Added a dedicated secondary action (`Browse Syllabus`) invoking smooth-scroll (`scrollToCurriculum`) directly to `#curriculum-section` without mutating router URLs or hash fragments.
  - **Sovereign Series Navbar:** Modernized the top header with breadcrumb navigation (Hub → Tenant Profile → Active Series Title capsule), back-to-org button, and bilingual locale switcher.
  - **Academic Course Showcase:** Upgraded cover presentation with 16:10 / 4:3 aspect ratio, geometric blueprint fallback with emblem, dual branch/series floating badges, and curated curriculum verification indicator.
  - **Curriculum & Lesson Modules:** Re-engineered each lecture item into an interactive sovereign card featuring mono gold numeral badges, start indicator for first lecture, rich media format badges (video/audio/article), publication dates, and dynamic play buttons.
  - **Sovereign 4-Column Foundation Footer:** Upgraded footer to full 4-column foundation layout with ecosystem integration (GitHub open-source repository, Ainux Client-Side Tools) and centered sub-footer attribution.

### Rationale
- Resolves broken navigation UX on the course landing page by immediately launching students into active study, while transforming the page layout into an authoritative institutional syllabus aligned with the Onyx & Gold sovereign ecosystem.



## [2026-09-18] - Redesign Tenant Course & Series Cards into Sovereign Academic Showcase

### Changed
- [`app/pages/[org_slug]/index.vue`](../app/pages/[org_slug]/index.vue):
  - Upgraded series and course card components to modern sovereign presentation cards:
    - **Aesthetic Glass Cards:** Converted flat cards into deep rounded (`rounded-3xl`) glass containers with high-contrast borders and an ambient top gold glow line on hover (`h-1 bg-gradient-to-r from-transparent via-gold to-transparent`).
    - **Academic Cover Presentation:** Added high-definition 16:10 aspect ratio cover images with smooth zoom hover transitions, paired with a geometric academic blueprint fallback pattern when no cover image is uploaded.
    - **Dual Floating Badges & Live Tag:** Overlaid branch origin badge (`🏛️ Branch`), verified premium track badge (`✦ Series`), and an in-cover live status pill (`سلسلة علمية معتمدة` / `Curated Track`).
    - **Interactive Action Bar:** Re-engineered the card footer CTA button into a sleek glass pill with an animated directional hover arrow (`←` / `→`) and smooth gold transition.

### Rationale
- Elevates the visual impact and institutional authority of tenant courses and series tracks, making curricular offerings engaging, trustworthy, and visually aligned with the Onyx & Gold sovereign ecosystem.


## [2026-09-18] - Centered Sub-Footer Typography & Isolated Ainux Brand Link

### Changed
- [`app/pages/index.vue`](../app/pages/index.vue), [`app/layouts/default.vue`](../app/layouts/default.vue), [`app/pages/[org_slug]/index.vue`](../app/pages/[org_slug]/index.vue):
  - Centered all bottom sub-footer text, copyright lines, and sovereignty taglines (`items-center justify-center text-center`) replacing the asymmetrical start/end alignment.
  - Isolated the external anchor hyperlink strictly to `ainux.online` / `آينوكس` rather than wrapping the preceding "Powered by" text.

### Rationale
- Improves typographic harmony and visual symmetry on desktop and mobile viewports, ensuring brand links are clean, intuitive, and properly scoped.

## [2026-09-18] - Ainux Ecosystem Integration, GitHub Open Source Link & Powered by Ainux

### Changed
- [`app/pages/index.vue`](../app/pages/index.vue):
  - **Hub Hero:** Added direct GitHub Open Source repository button (`https://github.com/Ibrahem3/burhan-platform`) alongside the primary CTAs.
  - **Ainux Tools Interactive Banner:** Integrated interactive ecosystem card highlighting Ainux Client-Side Tools (`https://tools.ainux.online/` - 57 zero-server browser utilities for PDF editing, background removal, and media tools).
  - **Floating Command Dock:** Embedded quick shortcuts for Ainux Tools and GitHub.
  - **4-Column Foundation Footer:** Added Ainux Tools and GitHub links in the Connect column, and added `Powered by ainux.online` (آينوكس) in the sub-footer bar.
- [`app/layouts/default.vue`](../app/layouts/default.vue):
  - Added Ainux Tools and GitHub repository links in the footer Connect column.
  - Added `Powered by ainux.online` (آينوكس) attribution in the sub-footer bar.
- [`app/pages/[org_slug]/index.vue`](../app/pages/[org_slug]/index.vue):
  - Added Ainux Tools and GitHub repository links in the tenant footer Connect column.
  - Added `Powered by ainux.online` (آينوكس) attribution in the sub-footer bar.

### Rationale
- Strengthens brand authority, transparency, and ecosystem synergy across the platform by showcasing open-source governance on GitHub, connecting users to the privacy-first Ainux Tools suite, and anchoring platform architecture under `ainux.online`.

## [2026-09-18] - Sovereign Tenant Institutional Profile, Navbar & 4-Column Footer Overhaul

### Changed
- [`app/pages/[org_slug]/index.vue`](../app/pages/[org_slug]/index.vue): Re-engineered the public organization tenant portal into an institutional sovereign showcase:
  - **Sovereign Tenant Top Navbar:** Added persistent glassmorphic navbar with Hub quick back link, tenant avatar lockup, active live section counters (`Series`, `Latest`, `About`), language toggle pill, and direct auth/dashboard actions.
  - **Cinematic Profile Hero:** Added panoramic geometric cover banner with mesh lighting, overlapping gold-ring sovereign avatar, verified institutional badge, live tenant metrics ribbon (`Series`, `Materials`, `Branches`, `100% Sovereign Isolation`), and elevated dual CTAs.
  - **Sovereign 4-Column Foundation Footer:** Replaced legacy 2-row MVP footer with a 4-column institutional layout customized for tenant portals, highlighting Burhan Cloud node operational health, organization sections, platform governance links, and localized language switcher.
  - **Preserved Core Functionality:** Retained smooth section scrolling, dynamic multi-lingual title/tagline fallbacks, responsive command dock, and real-time database queries.

### Rationale
- Transforms the tenant public landing page from a plain text hero into a high-credibility institutional knowledge portal, creating an authoritative identity for each organization while reinforcing the sovereign Onyx & Gold design system.

## [2026-09-18] - Default Layout Navbar & Sovereign Foundation Footer Modernization

### Changed
- [`app/layouts/default.vue`](../app/layouts/default.vue): Re-architected global default layout used by public pages (`/signup`, `/login`, `/about`, `/terms`, `/privacy`, `/observatory`):
  - **Sovereign Enterprise Navbar:** Replaced unbalanced flex ordering with a modern 3-point lockup (Brand Identity with v2.0 capsule + Central Navigation pills + End Actions with localized switcher and gold CTA).
  - **Tenant Awareness:** Clean inline tenant badge and logo preview for tenant routes within the default layout context.
  - **4-Column Foundation Footer:** Upgraded basic 2-column footer into the full sovereign foundation footer containing brand mission, live operational health indicator (`All Systems Operational`), platform navigation, governance/legal charters, and inline locale switcher pill.
  - **Mobile Experience:** Added backdrop-blurred glassmorphic drawer menu with quick auth buttons and active navigation indicators.

### Rationale
- Unifies the design language across all secondary public pages and auth flows with the main hub's Onyx & Gold sovereign aesthetic, eliminating visual fragmentation and improving responsive readability.

## [2026-09-18] - Sovereign Dual-Panel Onboarding & Signup UX Overhaul

### Changed
- [`app/pages/signup.vue`](../app/pages/signup.vue): Redesigned onboarding flow into a dual-panel sovereign enterprise experience:
  - **Left Showcase Panel (`lg:col-span-5`):** Added institutional value proposition pillar highlighting Burhan Cloud v2.0, sovereign multi-tenancy, atomic provisioning, zero-knowledge encrypted AI, and security indicators.
  - **Right Form Container (`lg:col-span-7`):** Elevated glassmorphic card with interactive 3-step progress ribbon (`Account -> Org -> Verify OTP`), icon-enhanced inputs, password show/hide toggles, real-time live subdomain URL preview, and stylized 6-digit OTP entry field.
  - **Preserved Core Logic:** Kept 100% of the registration security boundaries, password memory-wiping logic, tenant slug sanitization, Supabase OTP verification, resend cooldown timer (60s), and provisioning retry mechanisms intact.

### Rationale
- Elevates the tenant onboarding experience from an isolated single-column modal to a high-conversion institutional dual-panel workspace, visually aligning with the Onyx & Gold design system while maintaining zero-debt security and auth invariants.

## [2026-09-18] - Cinematic Hub Hero & Sovereign Foundation Footer Overhaul

### Changed
- [`app/pages/index.vue`](../app/pages/index.vue): Overhauled Main Hub header and footer architecture:
  - **Cinematic Hero:** Added ambient mesh aura, radial-masked tech grid pattern, v2.0 announcement capsule, dual elevated CTAs, and a 4-pillar live metrics ribbon (`Tenants`, `Published Entries`, `100% Isolation`, `DeAI`).
  - **Pre-Footer Enterprise Strip:** Added high-impact glass banner inviting knowledge organizations to launch their sovereign platform.
  - **4-Column Foundation Footer:** Implemented institutional 4-column glass layout with live system operational status indicator, direct platform & governance links, inline language selector, and 2026 copyright ribbon.

## [2026-09-18] - Sovereign Organization Cards Redesign

### Changed
- [`app/pages/index.vue`](../app/pages/index.vue): Re-engineered organization grid cards into a Sovereign Institutional Profile Showcase:
  - Added dynamic geometric banner headers with gold mesh gradients and pulsing active materials badges.
  - Implemented overlapping glassmorphic avatars with gold-ring accents and smooth hover elevation.
  - Displayed localized taglines/bios from organization settings with dual-language support.
  - Added institutional verification badges and direct call-to-action links.

## [2026-09-18] - Modern Floating Command Dock & Mobile UX Polish

### Changed
- [`app/pages/index.vue`](../app/pages/index.vue): Replaced legacy vertical speed dial FAB with a modern, glassmorphic Floating Command Dock:
  - Added categorized floating island panel containing user status, quick navigation, auth/dashboard controls, and language toggle.
  - Implemented responsive mobile sizing (`h-10`, `w-72`) while maintaining full desktop proportions (`h-13`, `w-80`).
  - Added ambient pulsating gold indicator and smooth cubic-bezier `panel-pop` scale/fade animations.
  - Fixed missing i18n key (`layout.hub` -> `hub.title`).
- [`app/pages/[org_slug]/index.vue`](../app/pages/[org_slug]/index.vue): Replicated modern command dock for tenant public pages:
  - Integrated tenant branding header with dynamic org avatar/initials, name, and tagline.
  - Added direct smooth-scrolling section shortcuts (`hero`, `series`, `latest`, `about`) with live item counts.

### Rationale
- Enhances user experience across mobile and desktop by transitioning from scattered Android-style speed dial buttons to an integrated, unified Glassmorphism Command Panel matching Burhan's premium Onyx & Gold design system.

## [2026-09-18] - Documentation Overhaul & Strategic Architectural Alignment

### Changed
- [`README.md`](../README.md): Comprehensive update reflecting modern production architecture:
  - Expanded Architectural Features to document DeAI M1 inference, Atomic Tenant Provisioning, Multi-Tenant Subscriptions, and BYOK.
  - Aligned project tree to reflect migrations 00001 through 00019, Nitro server routes (`/api/ai/`, `/api/org/`), and composables (`useAiGenerate`, `useSubscription`).
  - Documented modern environment variables (`NUXT_NOSANA_*`, `BYOK_ENCRYPTION_KEY`).
- [`SUPABASE.md`](../SUPABASE.md): Synchronized database documentation with canonical `schema.sql`:
  - Added table manifests for `plans`, `subscriptions`, `ai_jobs`, `ai_usage`, and `tenant_ai_credentials`.
  - Added trigger documentation for `check_branch_limit()` and `enforce_profile_security()`.
  - Added RPC reference for `public.provision_tenant()` and the DeAI lifecycle RPCs.
- [`ARCHITECTURE.md`](../ARCHITECTURE.md): Completed architectural single-source-of-truth:
  - Expanded Section 17 (Migration History) to fully chronicle migrations 00008 through 00019.
  - Added Section 22: Decentralized AI (DeAI) Architecture & Job Lifecycle.
  - Added Section 23: Multi-Tenant Subscriptions & Entitlements Engine.
  - Added Section 24: BYOK & Cryptographic Subsystem.
  - Added Section 25: Atomic Tenant Provisioning Engine & Auth OTP Gate.

### Rationale
- Completely eliminates documentation debt, aligning all external documentation (`README.md`), backend references (`SUPABASE.md`), and system blueprints (`ARCHITECTURE.md`) with the current code, test suites, and canonical database schema.



## [2026-09-18] - Resilient Localization Utility & Frontend Signup OTP Flow

### Changed
- [`app/utils/localized.ts`](../app/utils/localized.ts): Hardened `localizedValue` helper against arbitrary string inputs:
  - Directly returns plain strings (`"burhan"`, `"أكاديمية البرهان"`) without attempting `JSON.parse`.
  - Reliably resolves language keys (`locale`, `ar`, `en`) from JavaScript objects and PostgreSQL JSONB rows.
  - Safely attempts JSON parsing on bracketed JSON strings (`{...}`) inside a `try/catch` block, never throwing on syntax errors.
  - Prevents fatal frontend crashes on tenant view (`/[org_slug]`) and dashboard views.
- [`app/pages/signup.vue`](../app/pages/signup.vue): Implemented 3-step signup state machine (`account` -> `org` -> `verify`):
  - Added secure 6-digit email OTP verification via Supabase `auth.verifyOtp({ type: 'signup' })`.
  - Added 60-second cooldown timer for `resend` with complete lifecycle cleanup (`onUnmounted`).
  - Added zero-leak security boundary: immediately wipes passwords and OTP code from memory before and after state transitions.
  - Added dedicated idempotent provisioning retry handling if `register-tenant` encounters network/500 errors after OTP consumption.
  - Updated post-provisioning destination to route newly provisioned tenant owners directly to `/dashboard` instead of the public tenant page.
- [`app/i18n/ar.json`](../app/i18n/ar.json) & [`app/i18n/en.json`](../app/i18n/en.json): Added full bilingual localization for OTP screens, resend cooldowns, and structured machine-readable error messages.

### Rationale
- Completely resolves the runtime `SyntaxError: Unexpected token 'b'` preventing new organizations from rendering, while completing the client-side email verification security flow against the Migration 00019 transactional backend.



## [2026-09-18] - Migration 00019: Atomic Tenant Provisioning Engine

### Added
- [`supabase/migrations/00019_tenant_provisioning_engine.sql`](../supabase/migrations/00019_tenant_provisioning_engine.sql): Implemented transactional RPC `public.provision_tenant(p_user_id, p_org_name, p_org_slug)`:
  - Single atomic transaction unit covering organization creation, perpetual community subscription, main branch creation, and profile ownership upgrade.
  - Fail-closed automatic rollback on any failure with zero orphaned organizations or subscriptions.
  - Concurrency locking using `SELECT ... FOR UPDATE` on the canonical user profile row to prevent duplicate tenant creation.
  - DB-authoritative slug collision handling directly catching PostgreSQL `unique_violation` on `organizations.org_slug` and emitting domain error `slug_already_taken`.
  - Four-pillar idempotency verification: safely returns existing organization and main branch (`is_existing: true`) on matching slug retries, rejecting multi-tenant attempts with `user_already_has_tenant`, and raising `tenant_state_corrupted` on incomplete states.
  - Hardened execution privileges: strictly revoked from `PUBLIC`, `anon`, and `authenticated`; granted exclusively to `service_role`.

### Changed
- [`supabase/schema.sql`](../supabase/schema.sql): Appended Migration 00019 to maintain canonical synchronized database schema.
- [`server/api/auth/register-tenant.post.ts`](../server/api/auth/register-tenant.post.ts): Replaced legacy multi-step non-atomic PostgREST calls with a single atomic RPC invocation:
  - Added email confirmation gate verifying `confirmed_at` / `email_confirmed_at` on Supabase Auth user before invoking provisioning.
  - Mapped DB domain errors to standard, machine-readable HTTP codes: `400 invalid_payload`, `401 invalid_session`, `403 email_not_confirmed`, `409 slug_already_taken`, `409 user_already_has_tenant`, `500 tenant_state_corrupted`, `500 provisioning_failed`.
  - Returned HTTP 201 for freshly provisioned tenants and HTTP 200 for idempotent retries.

### Rationale
- Completely eliminates partial failure states, orphaned tenant rows, and race conditions during user registration, establishing an authoritative transactional backend foundation that guarantees safe retries for the upcoming email verification and signup flows.


## [2026-09-18] - Frontend Quota & Read-Only Integration

### Changed
- [`app/pages/dashboard/branches.vue`](../app/pages/dashboard/branches.vue): Integrated `useSubscription` quota and read-only checks:
  - Consumed `canCreateBranch`, `isReadOnly`, and `limits` directly from subscription contract.
  - Preserved unlimited `-1` branch semantics displaying `∞` badge.
  - Added action-level protection on `openCreateModal`, `openEditModal`, `submitBranch`, and `toggleBranchStatus`.
  - Added explicit database error handling matching `branch_limit_exceeded` error message and details from PostgreSQL Migration 00016.
- [`app/pages/dashboard/entities/new.vue`](../app/pages/dashboard/entities/new.vue): Integrated `isReadOnly` state from `useSubscription`:
  - Enforced guard at function entry in `save()` action for non-super_admin users.
  - Disabled desktop and mobile save buttons with contextual visual feedback when read-only.
  - Preserved `RichTextEditor`, Tiptap editor state, and Supabase storage upload pipelines completely untouched.
- [`app/pages/dashboard/entities/[id].vue`](../app/pages/dashboard/entities/[id].vue): Integrated `isReadOnly` state from `useSubscription`:
  - Enforced guard at function entry in `save()` action for non-super_admin users.
  - Disabled desktop and mobile save/update buttons with contextual visual feedback when read-only.
  - Preserved `RichTextEditor`, Tiptap editor state, and Supabase storage upload pipelines completely untouched.
- [`app/pages/dashboard/entities/index.vue`](../app/pages/dashboard/entities/index.vue): Applied mutation guards across entity list management:
  - Guarded `openCreateModal`, `navigateToNew`, `openEditModal`, and `submitEntity` against read-only state.
  - Disabled "New Entity" triggers, header buttons, and inline quick-edit card actions when subscription is expired/cancelled.
  - Preserved filtering, search, pagination, and multi-tenant scoping.

### Rationale
- Completes Step 1 of frontend integration by enforcing backend quota limits and read-only subscription restrictions at the UI and interaction layers, respecting frozen backend contracts while preserving existing editing engines and UX workflows without regressions.


## [2026-09-17] - Frontend Foundation: Auth, Tenant Bootstrap, Subscription State & App Shell

### Added
- [`app/types/subscription.ts`](../app/types/subscription.ts): TypeScript interface contracts for subscription states (`active`, `expired`, `cancelled`, `none`), plan metadata, quotas, limits, usage, and bootstrap lifecycle states.
- [`app/composables/useSubscription.ts`](../app/composables/useSubscription.ts): Reactive composable managing tenant subscription state from `GET /api/org/subscription`. Features in-flight deduplication, caching, read-only state computation, and branch creation permission checking without inventing new entitlement semantics.
- [`app/composables/useTenantBootstrap.ts`](../app/composables/useTenantBootstrap.ts): Coordinated bootstrap composable managing the lifecycle `Auth -> User Profile -> Organization Record -> Subscription Hydration -> Authenticated Content Shell`.
- [`app/components/dashboard/SubscriptionBanner.vue`](../app/components/dashboard/SubscriptionBanner.vue): Non-intrusive dashboard alert banner displaying read-only status when subscription is expired, cancelled, or missing, guaranteeing user understanding that data is safe and operations are read-only.

### Changed
- [`app/layouts/dashboard.vue`](../app/layouts/dashboard.vue): Integrated `useTenantBootstrap` with dedicated loading spinner, graceful recoverable error display with retry/logout actions, and subscription banner injection above application slots.
- [`app/components/dashboard/FloatingSidebar.vue`](../app/components/dashboard/FloatingSidebar.vue): Integrated shared tenant organization state and dynamic plan/read-only badge display next to organization title, eliminating redundant Supabase client queries.
- [`app/pages/dashboard/index.vue`](../app/pages/dashboard/index.vue): Bound active branch count and plan quota limits dynamically to the overview dashboard metric cards.

### Rationale
- Establishes a rock-solid, zero-debt frontend foundation respecting the frozen backend contracts. Ensures that organization context and subscription state hydrate deterministically before rendering dashboard content, with clear separation between UX presentation and authoritative backend enforcement.

## [2026-09-17] - Tenant AI Credentials & BYOK Subsystem (Migration 00018)

### Added
- [`supabase/migrations/00018_tenant_ai_credentials.sql`](../supabase/migrations/00018_tenant_ai_credentials.sql): Dedicated encrypted storage for tenant-owned AI provider credentials (BYOK). Features:
  - Table `tenant_ai_credentials` storing AES-256-GCM ciphertext, unique 12-byte IV, 16-byte auth tag, key version, and masked suffix.
  - Hardened PostgREST access: unconditionally revoked from `PUBLIC`, `anon`, and `authenticated`. Managed strictly through service-role by Nitro server endpoints.
  - Per-tenant uniqueness constraint `UNIQUE(organization_id, provider)`.
- [`server/utils/crypto.ts`](../server/utils/crypto.ts): Node.js `node:crypto` AES-256-GCM encryption/decryption module. Fails closed on missing or malformed `BYOK_ENCRYPTION_KEY` (must be exact 64 hex characters). Generates unique cryptographically random IV per encryption.
- [`server/utils/ssrf.ts`](../server/utils/ssrf.ts): Comprehensive Server-Side Request Forgery (SSRF) defense module. Features:
  - Provider endpoint policy (`validateProviderEndpointPolicy`) enforcing deployment allowlist: OpenAI locked to `https://api.openai.com`, OpenRouter locked to `https://openrouter.ai/api`, Nosana locked to platform cluster, and `custom` endpoints disabled by default in V1 (enabled only via `BYOK_ALLOW_CUSTOM_ENDPOINTS=true` and explicit `BYOK_ALLOWED_CUSTOM_HOSTS` allowlist).
  - Multi-address DNS resolution and IP literal filtering blocking IPv4/IPv6 loopback, RFC1918 private, link-local, multicast, cloud metadata (`169.254.169.254`), non-HTTP/HTTPS schemes, and embedded user credentials.
  - Safe HTTP runtime wrapper `safeProviderFetch` enforcing `redirect: 'manual'` and fail-closed handling on all 3xx redirects to eliminate redirect-based SSRF bypasses.
- [`server/api/org/ai-credentials.get.ts`](../server/api/org/ai-credentials.get.ts): Owner-authorized endpoint returning masked credential metadata (`key_suffix`, `provider`, `is_active`, `base_url`, `custom_model`). Plaintext and ciphertext are never emitted.
- [`server/api/org/ai-credentials.post.ts`](../server/api/org/ai-credentials.post.ts): Owner-authorized endpoint enforcing provider endpoint policy, SSRF validation, and AES-256-GCM encryption before database upsert.
- [`server/api/org/ai-credentials.delete.ts`](../server/api/org/ai-credentials.delete.ts): Owner-authorized endpoint deleting tenant credentials.

### Changed
- [`server/utils/nosana.ts`](../server/utils/nosana.ts): Extended inference runner with dynamic provider resolution and SSRF runtime defense:
  - Validates provider endpoint policy at runtime before dispatching inference requests.
  - Dispatches inference requests using `safeProviderFetch` with `redirect: 'manual'`, strictly terminating execution if a provider issues any 3xx redirect.
  - Decrypts tenant BYOK transiently in server memory during HTTP request window (plain-text lifetime invariant), with automatic fallback to platform Nosana provider when no BYOK is active. Sanitizes all upstream provider error messages to prevent credential or redirect reflection.
- [`server/api/ai/generate.post.ts`](../server/api/ai/generate.post.ts): Added BYOK detection at admission boundary: applies canonical M1 unlimited token adapter (`2147483647`) for tenant-paid tokens while strictly maintaining `monthly_ai_requests` quota to protect platform infrastructure against abuse.
- [`supabase/schema.sql`](../supabase/schema.sql): Appended Migration 00018 to maintain canonical synchronized database schema.
- [`tests/byok.test.mjs`](../tests/byok.test.mjs): Added test suites covering AES-256-GCM cryptography, SSRF IP range filtering, RLS revocation, plaintext non-persistence, quota reservation, and runtime SSRF hardening (302/301/307/308 redirect blocking to metadata/localhost/private destinations, and provider endpoint policy enforcement).

### Rationale
- Empowers organizations with digital sovereignty and direct provider billing through Bring Your Own Key (BYOK) while preserving M1 AI backend locks, zero secret leakage to database/client/logs, and completely closing SSRF attack vectors (DNS rebinding and HTTP redirects) at both registration and runtime boundaries.

## [2026-09-17] - Membership Security & Destination Subscription Gate (Migration 00017)

### Added
- [`supabase/migrations/00017_enforce_membership_security.sql`](../supabase/migrations/00017_enforce_membership_security.sql): Hardened profile update security against self-assignment and privilege escalation via dual-layer defense:
  - Tightened RLS policy `profiles_update_own` with non-recursive `WITH CHECK` locking `organization_id` and `role` to existing committed values for non-super_admin users.
  - Tightened RLS policy `profiles_update_org_staff` with `WITH CHECK` preventing cross-tenant reassignment or granting `super_admin`.
  - Created `public.enforce_profile_security()` trigger function and attached `BEFORE UPDATE ON public.profiles`. Enforces destination subscription validation (`public.is_org_subscription_active`), immutability of `organization_id` and `role` for self-edits, owner role scoping, and hardened privilege restrictions (`REVOKE ALL FROM PUBLIC, authenticated, service_role, anon`).
- [`tests/subscription.test.mjs`](../tests/subscription.test.mjs): Added test suite covering self-assignment block, cross-tenant reassignment block, self-escalation block, legitimate full_name edit, owner staff role management, and super_admin destination subscription gate.

### Changed
- [`supabase/schema.sql`](../supabase/schema.sql): Appended Migration 00017 to synchronize unified database schema.

### Rationale
- Closed confirmed PostgREST vulnerability where authenticated callers could directly modify `organization_id` or `role`, while strictly preserving legitimate user profile self-edits, owner staff management, super_admin cross-org authority, and tenant bootstrap lifecycle.

## [2026-09-17] - Atomic Branch Limit Enforcement (Migration 00016)

### Added
- [`supabase/migrations/00016_enforce_branch_limit.sql`](../supabase/migrations/00016_enforce_branch_limit.sql): Atomic quota enforcement function `public.check_branch_limit` and `BEFORE INSERT` trigger `trg_enforce_branch_limit` on `public.branches`. Enforces `plans.limits ->> 'max_branches'` with parent organization row-level locking (`FOR NO KEY UPDATE`), fail-closed validation, canonical `-1` unlimited bypass, strict numeric regex parsing, and hardened execution privileges (`REVOKE ALL FROM PUBLIC/authenticated/service_role/anon`).

### Changed
- [`server/api/auth/register-tenant.post.ts`](../server/api/auth/register-tenant.post.ts): Reordered tenant bootstrap lifecycle operations (`Organization` -> `Community Subscription` -> `Main Branch` -> `Owner Profile`) to satisfy Migration 00016 trigger dependency without granting bypass privileges or hardcoding exemptions for the `main` branch.
- [`supabase/schema.sql`](../supabase/schema.sql): Appended Migration 00016 to synchronize unified database schema.
- [`tests/ai/seed.sql`](../tests/ai/seed.sql), [`tests/ai/helpers.mjs`](../tests/ai/helpers.mjs), [`tests/subscription.test.mjs`](../tests/subscription.test.mjs): Reordered test seeding fixtures to guarantee active subscription creation before initial branch insertion.

### Rationale
- Eliminated multi-tenant race condition and over-allocation risks on branch creation while preserving direct client PostgREST insertion semantics, data sovereignty, and clean separation of concerns.

## [2026-09-17] - Subscription Foundation & Backend Integration (Migration 00015)

### Added
- [`supabase/migrations/00015_subscription_foundation.sql`](../supabase/migrations/00015_subscription_foundation.sql): Core commercial tables `plans` and `subscriptions`, helper function `is_org_subscription_active`, RLS mutation validity gates (`entities`, `branches`, `series`, `storage.objects`), and default seeded plans (`community` with canonical `-1` unlimited, and `pro`).
- [`server/utils/entitlements.ts`](../server/utils/entitlements.ts): Internal server entitlement utilities (`getActiveSubscription`, `hasFeature`, `getLimit`).
- [`server/api/org/subscription.get.ts`](../server/api/org/subscription.get.ts): Authenticated organization read endpoint returning subscription status, expiration, plan metadata, features, limits, and current AI/branch usage.
- [`tests/subscription.test.mjs`](../tests/subscription.test.mjs): Regression test suite for subscription database foundation, RLS mutation gating, and M1 adapter.

### Changed
- [`server/api/auth/register-tenant.post.ts`](../server/api/auth/register-tenant.post.ts): Added perpetual `community` subscription bootstrap upon organization creation with safe failure handling.
- [`server/api/ai/generate.post.ts`](../server/api/ai/generate.post.ts): Integrated active subscription and `ai_generate` feature gate; mapped canonical `-1` unlimited limits to `2147483647` at the M1 adapter boundary.
- [`supabase/schema.sql`](../supabase/schema.sql): Appended Migration 00015 to synchronize unified database schema.

### Rationale
- Established a unified, server-authoritative commercial subscription foundation supporting both self-hosted forks (via perpetual community plan) and commercial SaaS deployment, while strictly preserving M1 AI locked architecture and organization data sovereignty upon expiration.

## [2026-06-26] - Security Cleanup

### Fixed
- [`ARCHITECTURE.md`](../ARCHITECTURE.md): Replaced exposed Supabase API credentials (URL, publishable key, and secret key) in the documentation examples with generic placeholders to remediate security leaks.

### Rationale
- Prevent credential exposure and secure the repository from automated secret scanning alerts.

## [2026-06-25] - Repository Freeze Notice

### Changed
- [`README.md`](../README.md): Updated the Strategic Notice to a more visionary and founder-focused wording, explaining the transition to a Technical Waqf (نشر بذور النور في الأرض) and encouraging community UI/UX improvements, independent self-hosting, and educational usage.

### Rationale
- Provide a more positive and mission-driven context for open-sourcing the enterprise architecture, aligning with the platform's ethical and sovereign goals.

## [2026-06-25] - About Page & Organization Card Redesign (Premium Makeover)

### Fixed
- [`app/pages/index.vue`](../app/pages/index.vue): Resolved template compilation warning by introducing safe type check `!organizations || organizations.length === 0` to prevent runtime/compile errors.

### Changed
- [`app/pages/about.vue`](../app/pages/about.vue): Redesigned the page completely. Implemented glassmorphism split cards for Mission and Vision, and an interactive grid of core values with unique SVG icons. Created a dynamic string helper `getValueParts` to split localizations at colon, enabling clean visual separation of titles and descriptions.
- [`app/pages/index.vue`](../app/pages/index.vue): Upgraded the inline Organization Cards in the grid with a premium glassmorphism base, hover bounding border glows, custom monospace badges for organization slugs, count icons, and sliding navigation arrows.

### Rationale
- Elevated the visual aesthetics of the landing about page and organization directory card to present the platform as a state-of-the-art وقف تقني, leveraging modern grid systems, glassmorphism design tokens, and smooth hover interactions.

## [2026-06-25] - Digital Observatory Localization & TypeScript Polish

### Fixed
- [`tsconfig.json`](../tsconfig.json): Removed redundant manual path/types overrides that conflicted with Nuxt 4 auto-generated TS configurations.
- [`server/utils/supabase.ts`](../server/utils/supabase.ts): Corrected server database type import path using relative notation to align with Nuxt 4 server boundary resolution.
- [`app/pages/observatory/index.vue`](../app/pages/observatory/index.vue): Resolved index-access strict typecheck errors by introducing optional chaining and fallback empty strings for visual spread labels. Added safety check for `turnstileSiteKey` existence and wrapped token retrieval in a `try-catch` block to prevent Turnstile runtime errors when unconfigured.
- [`app/i18n/ar.json`](../app/i18n/ar.json) & [`app/i18n/en.json`](../app/i18n/en.json): Escaped literal `@` symbol in `form_url_placeholder` using `{'@'}` to avoid vue-i18n compiler failures.

### Changed
- [`app/pages/observatory/index.vue`](../app/pages/observatory/index.vue): Localized all remaining hardcoded Arabic texts from templates, utilizing i18n keys for priority level selectors, threat tags, and visual spread slider.
- [`app/pages/observatory/dashboard.vue`](../app/pages/observatory/dashboard.vue): Localized active analyst role badges, war room status titles, search filters, and tag translators (`tagSource`, `tagStatus`, `tagTarget`). Added TypeScript `any` cast to the Supabase client initialization to resolve external generic schema types.
- [`app/i18n/ar.json`](../app/i18n/ar.json) & [`app/i18n/en.json`](../app/i18n/en.json): Added missing observatory translation keys including `level_indicator` to support dynamic spread range slider indicator text.

### Rationale
- Eliminated hardcoded locale elements to support dual-language (Arabic/English) interface in the digital observatory modules, and stabilized TypeScript workspace compilation with correct dependency pathing.

## [2026-06-25] - README Rebrand & Observatory Turnstile Integration

### Fixed
- [`app/pages/observatory/index.vue`](../app/pages/observatory/index.vue): Resolved a critical bug in the threat monitoring intake form. Injected the Cloudflare Turnstile API script and implemented token retrieval logic so that submissions correctly pass spam protection validation.

### Changed
- [`README.md`](../README.md): Completely rewritten and rebranded as a decentralized, ethical, and sovereign media distribution engine (وقف تقني). Documented the manifesto against censorship (الاغتيال الرقمي), detailed database RLS policies, Cloudflare Turnstile integration, the custom Tiptap RTL layout, and introduced the community call for frontend UI/UX contributions.


### Rationale
Established the repository's identity as a sovereign technical asset rather than a generic boilerplate. Added explicit ethical constraints and clear calls-to-action for open-source UI contributors.

## [2026-06-24] - Repository Cleanup & Documentation Audit


### Added
- [`.env.example`](../.env.example): Created environment variables template file mapping necessary Supabase settings and Turnstile keys to prevent configuration friction for new developers.
- [`supabase/schema.sql`](../supabase/schema.sql): Created a unified, up-to-date database schema script (concatenating migrations 00001–00009) to enable a seamless one-click SQL Editor setup for buyers.

### Changed
- [`README.md`](../README.md): Documented the Digital Observatory feature, added Turnstile configurations, included Migration `00009` in the migrations checklist, updated local development instructions to use `supabase/schema.sql`, and updated the project structure tree.
- [`SUPABASE.md`](../SUPABASE.md): Documented the database schemas for `observatory_analysts` and `observatory_threats` tables, Turnstile verification endpoints, custom triggers/helper functions (`is_observatory_manager`, `is_super_admin`), and updated setup instructions to use `supabase/schema.sql`.
- [`ARCHITECTURE.md`](../ARCHITECTURE.md): Added architectural documentation for the Digital Intellectual Observatory module (role-level isolation, component routing, and spam protection integration) and updated the database setup section to reference the new unified `supabase/schema.sql`.

### Removed
- `FloatingMenu.vue` (Root folder): Deleted the orphaned component containing references to undefined state stores (`useTenantStore`, `useFeaturesStore`), cleaning up the repository's root directories.
- `burhan_public_schema.sql` (Root folder): Deleted the obsolete, out-of-date PostgreSQL dump that caused permission conflicts on fresh Supabase instances.

### Rationale
Prepared the codebase for commercial SaaS distribution. By eliminating dead code, supplying a standard environment template, providing a unified database installation script, and filling documentation gaps for major modules, we ensure the codebase can be run out-of-the-box with zero configuration friction.

