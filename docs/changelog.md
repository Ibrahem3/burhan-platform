# Changelog

All notable changes to this project will be documented in this file.

## [2026-06-24] - Repository Cleanup & Documentation Audit

### Added
- [`.env.example`](file:///mnt/Data/burhan/.env.example): Created environment variables template file mapping necessary Supabase settings and Turnstile keys to prevent configuration friction for new developers.
- [`supabase/schema.sql`](file:///mnt/Data/burhan/supabase/schema.sql): Created a unified, up-to-date database schema script (concatenating migrations 00001–00009) to enable a seamless one-click SQL Editor setup for buyers.

### Changed
- [`README.md`](file:///mnt/Data/burhan/README.md): Documented the Digital Observatory feature, added Turnstile configurations, and included Migration `00009` in the migrations checklist.
- [`SUPABASE.md`](file:///mnt/Data/burhan/SUPABASE.md): Documented the database schemas for `observatory_analysts` and `observatory_threats` tables, Turnstile verification endpoints, custom triggers/helper functions (`is_observatory_manager`, `is_super_admin`), and updated setup instructions to use `supabase/schema.sql`.
- [`ARCHITECTURE.md`](file:///mnt/Data/burhan/ARCHITECTURE.md): Added architectural documentation for the Digital Intellectual Observatory module (role-level isolation, component routing, and spam protection integration).

### Removed
- `FloatingMenu.vue` (Root folder): Deleted the orphaned component containing references to undefined state stores (`useTenantStore`, `useFeaturesStore`), cleaning up the repository's root directories.
- `burhan_public_schema.sql` (Root folder): Deleted the obsolete, out-of-date PostgreSQL dump that caused permission conflicts on fresh Supabase instances.

### Rationale
Prepared the codebase for commercial SaaS distribution. By eliminating dead code, supplying a standard environment template, providing a unified database installation script, and filling documentation gaps for major modules, we ensure the codebase can be run out-of-the-box with zero configuration friction.

