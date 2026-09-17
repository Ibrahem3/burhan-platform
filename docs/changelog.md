# Changelog

All notable changes to this project will be documented in this file.

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

