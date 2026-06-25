# Changelog

All notable changes to this project will be documented in this file.

## [2026-06-25] - Digital Observatory Localization & TypeScript Polish

### Fixed
- [`tsconfig.json`](file:///mnt/Data/burhan/tsconfig.json): Removed redundant manual path/types overrides that conflicted with Nuxt 4 auto-generated TS configurations.
- [`server/utils/supabase.ts`](file:///mnt/Data/burhan/server/utils/supabase.ts): Corrected server database type import path using relative notation to align with Nuxt 4 server boundary resolution.
- [`app/pages/observatory/index.vue`](file:///mnt/Data/burhan/app/pages/observatory/index.vue): Resolved index-access strict typecheck errors by introducing optional chaining and fallback empty strings for visual spread labels.

### Changed
- [`app/pages/observatory/index.vue`](file:///mnt/Data/burhan/app/pages/observatory/index.vue): Localized all remaining hardcoded Arabic texts from templates, utilizing i18n keys for priority level selectors, threat tags, and visual spread slider.
- [`app/pages/observatory/dashboard.vue`](file:///mnt/Data/burhan/app/pages/observatory/dashboard.vue): Localized active analyst role badges, war room status titles, search filters, and tag translators (`tagSource`, `tagStatus`, `tagTarget`). Added TypeScript `any` cast to the Supabase client initialization to resolve external generic schema types.
- [`app/i18n/ar.json`](file:///mnt/Data/burhan/app/i18n/ar.json) & [`app/i18n/en.json`](file:///mnt/Data/burhan/app/i18n/en.json): Added missing observatory translation keys including `level_indicator` to support dynamic spread range slider indicator text.

### Rationale
- Eliminated hardcoded locale elements to support dual-language (Arabic/English) interface in the digital observatory modules, and stabilized TypeScript workspace compilation with correct dependency pathing.

## [2026-06-25] - README Rebrand & Observatory Turnstile Integration

### Fixed
- [`app/pages/observatory/index.vue`](file:///mnt/Data/burhan/app/pages/observatory/index.vue): Resolved a critical bug in the threat monitoring intake form. Injected the Cloudflare Turnstile API script and implemented token retrieval logic so that submissions correctly pass spam protection validation.

### Changed
- [`README.md`](file:///mnt/Data/burhan/README.md): Completely rewritten and rebranded as a decentralized, ethical, and sovereign media distribution engine (وقف تقني). Documented the manifesto against censorship (الاغتيال الرقمي), detailed database RLS policies, Cloudflare Turnstile integration, the custom Tiptap RTL layout, and introduced the community call for frontend UI/UX contributions.


### Rationale
Established the repository's identity as a sovereign technical asset rather than a generic boilerplate. Added explicit ethical constraints and clear calls-to-action for open-source UI contributors.

## [2026-06-24] - Repository Cleanup & Documentation Audit


### Added
- [`.env.example`](file:///mnt/Data/burhan/.env.example): Created environment variables template file mapping necessary Supabase settings and Turnstile keys to prevent configuration friction for new developers.
- [`supabase/schema.sql`](file:///mnt/Data/burhan/supabase/schema.sql): Created a unified, up-to-date database schema script (concatenating migrations 00001–00009) to enable a seamless one-click SQL Editor setup for buyers.

### Changed
- [`README.md`](file:///mnt/Data/burhan/README.md): Documented the Digital Observatory feature, added Turnstile configurations, included Migration `00009` in the migrations checklist, updated local development instructions to use `supabase/schema.sql`, and updated the project structure tree.
- [`SUPABASE.md`](file:///mnt/Data/burhan/SUPABASE.md): Documented the database schemas for `observatory_analysts` and `observatory_threats` tables, Turnstile verification endpoints, custom triggers/helper functions (`is_observatory_manager`, `is_super_admin`), and updated setup instructions to use `supabase/schema.sql`.
- [`ARCHITECTURE.md`](file:///mnt/Data/burhan/ARCHITECTURE.md): Added architectural documentation for the Digital Intellectual Observatory module (role-level isolation, component routing, and spam protection integration) and updated the database setup section to reference the new unified `supabase/schema.sql`.

### Removed
- `FloatingMenu.vue` (Root folder): Deleted the orphaned component containing references to undefined state stores (`useTenantStore`, `useFeaturesStore`), cleaning up the repository's root directories.
- `burhan_public_schema.sql` (Root folder): Deleted the obsolete, out-of-date PostgreSQL dump that caused permission conflicts on fresh Supabase instances.

### Rationale
Prepared the codebase for commercial SaaS distribution. By eliminating dead code, supplying a standard environment template, providing a unified database installation script, and filling documentation gaps for major modules, we ensure the codebase can be run out-of-the-box with zero configuration friction.

