# Changelog

All notable changes to this project will be documented in this file.

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

