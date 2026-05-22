# Burhan Architecture — Single Source of Truth

> **Platform:** Multi-tenant Enterprise SaaS — Central Hub with Slug-Based Tenant Routing
> **Domain:** `burhan.ainux.online`
> **Stack:** Nuxt 4 + Tailwind CSS + Supabase (PostgreSQL) + Cloudflare Pages
> **Languages:** Arabic (primary) / English
> **Status:** Post-Demo — Full Dashboard, Entity CRUD, Editor, Floating Sidebar

---

## Table of Contents

1. [System Design Blueprint](#1-system-design-blueprint)
2. [Database & RLS Manifest](#2-database--rls-manifest)
3. [Nuxt 4 Directory Structure](#3-nuxt-4-directory-structure)
4. [Routing & Middleware Strategy](#4-routing--middleware-strategy)
5. [i18n & Multilingual Architecture](#5-i18n--multilingual-architecture)
6. [Video Fallback Engine](#6-video-fallback-engine)
7. [Premium Gating Layer](#7-premium-gating-layer)
8. [UI Design System — Ainux Signature](#8-ui-design-system--ainux-signature)
9. [Edge Deployment (Cloudflare)](#9-edge-deployment-cloudflare)
10. [Development Cheat Sheet](#10-development-cheat-sheet)
11. [Organization Dashboard](#11-organization-dashboard)
12. [Floating Sidebar — Interaction Model](#12-floating-sidebar--interaction-model)
13. [Entity CRUD — Full Lifecycle](#13-entity-crud--full-lifecycle)
14. [Rich Text Editor](#14-rich-text-editor)
15. [Caching & Locale Path Strategy](#15-caching--locale-path-strategy)
16. [i18n Audit — Rule Enforcement](#16-i18n-audit--rule-enforcement)
17. [Migration History](#17-migration-history)

---

## 1. System Design Blueprint

### 1.1 The 4-Tier Role Hierarchy

```
Super Admin            (super_admin)  — Manages the Hub, all orgs, all entities
  └── Org Owner        (owner)        — Owns a specific organization, full access
       └── Manager     (manager)      — Content manager for an entire organization
            └── Member (member)       — Basic authenticated user, read-only access
```

Managed via a PostgreSQL `user_role` ENUM:

```sql
CREATE TYPE user_role AS ENUM ('super_admin', 'owner', 'manager', 'member');
```

### 1.2 Tenant Data Isolation Model

```
burhan.ainux.online
  ├── /                          → Hub: global public entities feed
  ├── /:org_slug                 → Tenant: isolated org-specific view
  └── /:org_slug/branches/:id    → Tenant: isolated branch detail
```

- **Hub** queries only entities where `is_public_to_hub = true AND is_premium = false`
- **Tenant routes** are locked to their `org_slug` via global middleware (`org.global.ts`)
- **RLS** enforces row-level tenant isolation at the database level — every policy is scoped to `organization_id`

---

## 2. Database & RLS Manifest

### 2.1 Tables

| Table | Purpose | Key Fields |
|-------|---------|------------|
| `organizations` | Tenant/brand owner | `id UUID PK`, `org_slug TEXT UNIQUE`, `settings JSONB` |
| `branches` | Modular sub-sections | `id UUID PK`, `organization_id FK`, `name JSONB {ar,en}`, `module_type ENUM` |
| `profiles` | Extends auth.users | `id UUID PK FK→auth.users`, `organization_id FK`, `role user_role ENUM` |
| `entities` | Dynamic content engine | `id UUID PK`, `branch_id FK`, `organization_id FK`, `title JSONB {ar,en}`, `content JSONB {ar,en}`, `is_public_to_hub BOOLEAN`, video fields, premium fields |

### 2.2 Critical Entity Fields

#### Video Sources
```sql
video_id          TEXT,          -- ID from the video platform
primary_source    TEXT DEFAULT 'youtube',  -- 'youtube' | 'cloudflare_stream'
fallback_source   TEXT,          -- 'cloudflare_stream' | etc.
fallback_url      TEXT,          -- Generic fallback URL if sources fail
```

#### Premium / Academy
```sql
is_premium        BOOLEAN DEFAULT false,
price             DECIMAL(10,2),  -- NULL if free
```

#### Multi-Language JSONB Structure
```json
{
  "ar": "...",
  "en": "..."
}
```
Applied to: `branches.name`, `profiles.full_name`, `entities.title`, `entities.content`

### 2.3 Auto-Profile Trigger

On every `auth.users` INSERT, a trigger (`handle_new_user()`) auto-creates a corresponding `profiles` row with `role = 'member'`. No manual profile creation needed.

### 2.4 RLS Policy Map

| Table | Policy | Scope |
|-------|--------|-------|
| `organizations` | SELECT | Everyone (`true`) |
| `organizations` | INSERT/UPDATE/DELETE | `super_admin` only |
| `branches` | SELECT | Org members + `super_admin` |
| `branches` | INSERT/UPDATE | Owner, manager, `super_admin` |
| `branches` | DELETE | Owner, `super_admin` |
| `profiles` | SELECT | Own profile + org members + `super_admin` |
| `profiles` | UPDATE | Self + org owner + `super_admin` |
| **`entities`** | SELECT (Hub) | **`is_public_to_hub = true AND is_premium = false`** |
| **`entities`** | SELECT (Org) | Org members see org entities; basic members blocked from premium; owners/managers see all |
| **`entities`** | SELECT (Super) | `super_admin` sees everything |
| `entities` | INSERT | Owner, manager, `super_admin` |
| `entities` | UPDATE | Owner, **manager** (org-wide), `super_admin` |
| `entities` | DELETE | Owner, manager, `super_admin` |

#### Patched Manager Scope (Critical)

After code review, the `manager` role is **organization-wide**, not branch-specific. The `profiles` table has no `assigned_branch_id`. The UPDATE policy was simplified from:

```sql
-- OLD: misleading branch-level separation
EXISTS (... role = 'manager') OR EXISTS (... role = 'owner')

-- NEW: honest org-wide scope
EXISTS (... role IN ('owner', 'manager'))
```

#### Premium Leak Fix (Critical)

The original `entities_select_public_hub` policy was:
```sql
USING (is_public_to_hub = true)
```
This leaked premium content to unauthenticated users. Fixed to:
```sql
USING (is_public_to_hub = true AND is_premium = false)
```

The `entities_select_org_member` policy also nests a premium check: basic members see only `is_premium = false`, while owners/managers bypass the gate.

### 2.5 Indexes

```sql
idx_organizations_org_slug          ON organizations (org_slug)
idx_branches_organization_id        ON branches (organization_id)
idx_profiles_organization_id        ON profiles (organization_id)
idx_entities_branch_id              ON entities (branch_id)
idx_entities_organization_id        ON entities (organization_id)
idx_entities_public_to_hub          ON entities (is_public_to_hub) WHERE is_public_to_hub = true
idx_entities_premium                ON entities (is_premium)
```

---

## 3. Nuxt 4 Directory Structure

```
burhan/
├── app/                               ← srcDir (Nuxt 4 convention)
│   ├── app.vue                        ← Root: head, fonts, layout wrapper
│   ├── assets/css/main.css            ← Tailwind directives + glass/gradient utilities
│   ├── i18n.config.ts                 ← vue-i18n config (imports JSONs, replaces langDir)
│   ├── layouts/
│   │   ├── default.vue                ← Ainux navbar + footer + mobile menu
│   │   └── dashboard.vue              ← Sidebar layout with glassmorphic nav
│   ├── pages/
│   │   ├── index.vue                  ← Hub: hero + public entity feed
│   │   ├── login.vue                  ← Email/password sign-in form
│   │   ├── signup.vue                 ← 2-step: account → org creation
│   │   ├── dashboard/
│   │   │   ├── index.vue              ← Stats grid (videos, branches, revenue, subs)
│   │   │   ├── branches.vue           ← Branch CRUD (419 lines)
│   │   │   └── entities/
│   │   │       ├── index.vue          ← Entity list + inline modal CRUD (535 lines)
│   │   │       ├── [id].vue           ← Article edit page with RichTextEditor (343 lines)
│   │   │       └── new.vue            ← Article create page (315 lines)
│   │   └── [org_slug]/
│   │       ├── index.vue              ← Tenant: org header + branch filter + entity grid
│   │       └── branches/[branch_id].vue  ← Branch detail with featured video
│   ├── middleware/
│   │   ├── org.global.ts              ← Global: validates org_slug, 404 if missing, fallback to profile org
│   │   └── dashboard-auth.ts          ← Route guard: blocks member/unauthenticated from /dashboard
│   ├── components/
│   │   ├── hub/
│   │   │   ├── EntityCard.vue         ← Glass card with localized title/content
│   │   │   └── CategorySection.vue    ← Section with grid + loading/empty states
│   │   ├── tenant/
│   │   │   ├── OrgHeader.vue          ← Dynamic org name + logo + branch badges
│   │   │   ├── BranchNav.vue          ← Branch filter buttons with active state
│   │   │   └── VideoPlayer.vue        ← Multi-source fallback state machine
│   │   ├── premium/
│   │   │   └── PremiumGate.vue        ← Lock overlay with blurred preview
│   │   ├── dashboard/
│   │   │   ├── FloatingSidebar.vue     ← 60px→280px expandable, pin@dblclick (223 lines)
│   │   │   └── RichTextEditor.vue      ← Tiptap-based WYSIWYG with full toolbar (446 lines)
│   │   └── ui/
│   │       ├── Button.vue             ← 4 variants, 3 sizes, loading state
│   │       ├── GlassCard.vue          ← Glassmorphic container
│   │       ├── Avatar.vue             ← Image/fallback initials
│   │       └── Badge.vue              ← Variants: default, premium, success, warning, info
│   ├── composables/
│   │   ├── useOrg.ts                  ← Fetch + cache org by slug
│   │   ├── useEntities.ts             ← CRUD entities via Supabase
│   │   ├── useUser.ts                 ← Auth + profile + role helpers
│   │   └── useLocale.ts              ← i18n bridge + extractLocalized()
│   ├── i18n/
│   │   ├── ar.json                    ← Arabic UI (~200 keys)
│   │   └── en.json                    ← English UI (~200 keys)
│   └── types/database.ts              ← Full Supabase type definitions
├── server/
│   ├── utils/supabase.ts              ← Server client + admin factories
│   └── api/
│       ├── auth/register-tenant.post.ts  ← Service-role: creates org + branch + owner profile
│       ├── orgs/[slug].ts             ← GET org with branches
│       └── entities/public.ts         ← GET hub feed (public, non-premium)
├── supabase/migrations/
│   ├── 00001_initial_schema.sql
│   ├── 00002_fix_branches_rls.sql
│   └── 00003_fix_profiles_rls_recursion.sql
├── nuxt.config.ts
├── tailwind.config.ts
├── tsconfig.json
├── package.json
└── .env
```

### Key Path Resolution (srcDir)

```
nuxt.config.ts  →  tailwindcss.configPath: './tailwind.config.ts'
                 →  tailwindcss.cssPath:   './app/assets/css/main.css'
```

---

## 4. Routing & Middleware Strategy

### 4.1 Route Map

| Path | Page | Guard |
|------|------|-------|
| `/` | `app/pages/index.vue` | None (Hub) |
| `/login` | `app/pages/login.vue` | None |
| `/signup` | `app/pages/signup.vue` | None |
| `/dashboard` | `app/pages/dashboard/index.vue` | `dashboard-auth.ts` |
| `/dashboard/branches` | `app/pages/dashboard/branches.vue` | `dashboard-auth.ts` |
| `/dashboard/entities` | `app/pages/dashboard/entities/index.vue` | `dashboard-auth.ts` |
| `/dashboard/entities/new` | `app/pages/dashboard/entities/new.vue` | `dashboard-auth.ts` |
| `/dashboard/entities/:id` | `app/pages/dashboard/entities/[id].vue` | `dashboard-auth.ts` |
| `/:org_slug` | `app/pages/[org_slug]/index.vue` | `org.global.ts` |
| `/:org_slug/branches/:branch_id` | `app/pages/[org_slug]/branches/[branch_id].vue` | `org.global.ts` |

### 4.2 Global Middleware — `org.global.ts`

```
Route with :org_slug param
  → fetchOrg(slug) via $fetch('/api/orgs/:slug')
  → Error & path is dashboard/auth? → skip (return early)
  → Error & user has profile.org? → fallback: load org from profile
  → Error & no fallback? → throw fatal 404
  → Success? → useHead({ title: org.name, canonical link })
  → Continue rendering
```

The middleware:
- **Public route bypass:** `/login`, `/signup`, `/dashboard` are matched by `isPublicRoute()` and skipped immediately
- **Caches** the org in `useState('org')` so subsequent navigations to the same org skip the fetch
- **Is idempotent** — `useOrg().fetchOrg()` returns early if `lastSlug` matches
- **Fallback resolution:** If the URL slug fails (wrong org or missing), falls back to fetching the authenticated user's `organization_id` from `profiles` and loading that org instead
- **Is `fatal: true`** — ensures the error page renders cleanly with zero partial org state

### 4.3 Dashboard Auth Middleware — `dashboard-auth.ts`

```
/dashboard route
  → useSupabaseUser() exists?
    → NO → navigateTo('/login')
    → YES → fetch profile.role from DB
      → role === 'member' or null? → navigateTo('/')
      → role === 'owner'|'manager'|'super_admin'? → pass
```

Applied via `definePageMeta({ middleware: 'dashboard-auth' })` in `/dashboard/index.vue`. Protects all dashboard sub-routes from unauthorized access.

### 4.4 Auth Pages & Tenant Registration Flow

**Signup** (`/signup`): Two-step glassmorphic form:
1. **Account step:** Full name, email, password, confirm password
2. **Organization step:** Org name + URL-friendly slug (auto-generated from name)

On submit:
```
supabase.auth.signUp(email, password)
  → data.session exists? (email confirmation OFF)
    → YES → POST /api/auth/register-tenant with access_token
      → Server verifies JWT via admin.auth.getUser(accessToken)
      → Inserts organizations row (service role bypasses RLS)
      → Inserts default branch (module_type: 'content')
      → Updates profiles row: role='owner', organization_id=org.id
      → Returns { org, branch }
    → Client: navigateTo('/' + org.org_slug)
  → NO → Show "verify email" message
```

**Login** (`/login`): Single-step form with `auth.signInWithPassword()`. On success → `navigateTo('/')`.

**Server route `POST /api/auth/register-tenant`:**
- Accepts `{ accessToken, orgName, orgSlug }` in body
- Uses `getSupabaseAdmin()` (service role key) for all DB operations
- Verifies JWT via `admin.auth.getUser(accessToken)` — no cookie/session dependency
- Atomic waterfall: org → branch → profile. Each step validates `?.id` before proceeding
- Slug uniqueness enforced with 409 Conflict on duplicate
- Slug sanitized: lowercase, `/[^a-z0-9-]/g` stripped, min 2 chars

### 4.5 Canonical URLs

Set dynamically per tenant in the middleware:
```ts
useHead({
  link: [{ rel: 'canonical', href: `https://burhan.ainux.online/${org.org_slug}` }],
})
```

---

## 5. i18n & Multilingual Architecture

### 5.1 Configuration — `vueI18n` Approach (NOT `langDir`)

The i18n module switched from the legacy `langDir`/`lazy`/`file` approach to the `vueI18n` config file approach to eliminate persistent `../i18n/i18n/` double-path build artifacts.

**In `nuxt.config.ts`:**
```ts
i18n: {
  restructureDir: false,              // Stops module from resolving inside project-root/i18n/
  locales: [
    { code: 'ar', iso: 'ar-EG', dir: 'rtl' },   // No `file` key — messages are in vueI18n config
    { code: 'en', iso: 'en-US', dir: 'ltr' },
  ],
  defaultLocale: 'ar',
  strategy: 'prefix_except_default',
  vueI18n: './app/i18n.config.ts',    // Path to vue-i18n config (relative to project root)
}
```

**In `app/i18n.config.ts`:**
```ts
import ar from './i18n/ar.json'
import en from './i18n/en.json'
export default defineI18nConfig(() => ({
  legacy: false,
  locale: 'ar',
  messages: { ar, en },
}))
```

**Critical: `restructureDir: false`** — Without this, the module defaults to `restructureDir: "i18n"` and resolves `vueI18n` relative to `/project-root/i18n/` instead of the project root, making the file unfindable and producing the warning:
```
Vue I18n configuration file not found in /project-root/i18n. Skipping...
```

**Do NOT use `langDir` + `lazy` + `file`** — These were the root cause of the `../i18n/i18n/ar.json` double-path bug. The `.nuxt/i18n.options.mjs` virtual module baked the absolute `resolve(__dirname, 'app/i18n')` path, which the module then double-resolved relative to `.nuxt/` (resulting in `../i18n/i18n/`). Even after removing the absolute path and switching to `langDir: 'i18n/'`, the stale `.nuxt/` cache persisted the double-path. Full `rm -rf .nuxt` was required after every config change during debugging.

**Browser detection removed** — `detectBrowserLanguage` block was removed to simplify the configuration. Locale is set via URL prefix only (`prefix_except_default`).

**`bundle.optimizeTranslationDirective` deprecation** — The module emits a deprecation warning about this option. It was removed from config per the module's recommendation to stop using file-based lazy loading entirely.

### 5.2 JSONB Database Extraction — `extractLocalized()`

The critical function that bridges the database's `{ ar, en }` JSONB structure to the UI:

```ts
// app/composables/useLocale.ts
function extractLocalized<T = string>(
  jsonb: LocalizedJson<T> | null | undefined,
  fallback: T | null = null
): T | null {
  if (!jsonb) return fallback
  return jsonb[currentLocale.value] ?? jsonb.en ?? fallback ?? null
}
```

**Resolution chain:** `currentLocale → en → fallback → null`

**Usage pattern:**
```ts
const title = extractLocalized<string>(entity.title, 'Untitled')
// Returns entity.title.ar on Arabic site
// Returns entity.title.en on English site (or fallback)
// Returns 'Untitled' if both are null
```

### 5.3 Zero Hardcoded UI Rule

- **Every visual text** in `<template>` uses `$t('key')` — with 2 exceptions:
  1. Content-language placeholders (e.g., "عنوان المقال..." is always Arabic regardless of UI locale)
  2. Format examples (e.g., `placeholder="0.00"`)
- **Every DB-origin text** passes through `extractLocalized()` — no raw `.ar`/`.en` access
- Locale switching (`toggleLocale()`) updates `<html dir>`, `<html lang>`, and CSS direction class simultaneously
- See §16 for full audit of ~22 hardcoded strings that were converted to i18n

### 5.4 Locale-Aware Breadcrumb

The navbar breadcrumb arrow flips with locale:
```html
<path v-if="currentLocale === 'ar'" d="M9 5l7 7-7 7" />   <!-- points right -->
<path v-else d="M15 19l-7-7 7-7" />                         <!-- points left -->
```

---

## 6. Video Fallback Engine

### 6.1 Source Resolution

| Priority | Source | How |
|----------|--------|-----|
| 1° | YouTube | `https://www.youtube.com/embed/{videoId}?autoplay=1&rel=0&playsinline=1` |
| 2° | Cloudflare Stream | `https://iframe.videodelivery.net/{videoId}?autoplay=true` |
| 3° | Generic fallback | Direct `fallback_url` |

### 6.2 State Machine

```
                  ┌──────────────────────────────────────────────┐
                  │                                              │
                  ∨                                              │
  [no_video] ← onMounted → [loading] ── iframe load success ──→ [playing]
                              │                                    ↑
                              │ 10s timeout                        │
                              ∨                                    │
                          [primary_error]                      [retry]
                           /          \                            ↑
                    has_fallback      no_fallback                  │
                         │              │                          │
                         ∨              └──── stay on screen ──────┘
                   [loading_fallback]
                         │
                     10s timeout
                         ∨
                   [fallback_error] ← retry ───────────────┘
```

### 6.3 Trigger Chain

1. **Iframe `@error` event** — Browser fires this when the embed URL fails
2. **10-second timeout** (`FALLBACK_TIMEOUT_MS = 10000`) — Auto-triggers if no `@load` fires
3. **Manual switch** — User clicks "Switch to alternative source" button

### 6.4 UI States

| State | Overlay | Actions |
|-------|---------|---------|
| `loading` | Gold spinner + "Loading video..." | None |
| `playing` | No overlay (video visible) | None |
| `primary_error` | Warning icon + error message | Retry + Switch to fallback |
| `loading_fallback` | Gold spinner + "Loading from fallback..." | None |
| `fallback_error` | Error icon + "All sources exhausted" | Retry |
| `no_video` | Muted video icon + "No video" | None |

A `Badge variant="warning"` appears in the top-left when fallback mode is active.

---

## 7. Premium Gating Layer

### 7.1 Access Decision Tree

```
entity.is_premium?
  → NO  → Show content (always accessible)
  → YES →
    isOrgStaff? (owner/manager/super_admin)
      → YES → Show content (bypass gate)
      → NO  → Show locked overlay
```

### 7.2 Locked Overlay UX

```
┌──────────────────────────────────┐
│     [blurred content preview]     │  ← blur-sm opacity-30 (teaser)
│  ┌────────────────────────────┐   │
│  │        ⭐ Premium          │   │  ← Gold Badge
│  │        🔒                  │   │  ← Lock icon in gold circle
│  │  This content is exclusive │   │
│  │     to premium members     │   │
│  │                            │   │
│  │  Price: $29.99             │   │  ← Gold price tag (if set)
│  │                            │   │
│  │  ┌──────────────────────┐  │   │
│  │  │   Subscribe Now      │  │   │  ← Gold CTA Button
│  │  └──────────────────────┘  │   │
│  │       Learn more ˃        │   │  ← Muted link
│  └────────────────────────────┘   │
└──────────────────────────────────┘
```

### 7.3 CTA Routing

- **Unauthenticated user:** CTA links to `/signup`
- **Authenticated non-paying user:** CTA triggers purchase flow (placeholder for Stripe/Paddle integration)
- **Org staff (owner/manager/super_admin):** Content is automatically unlocked — no purchase needed

### 7.4 Dual-Layer Security

1. **Database (RLS):** The `entities_select_public_hub` policy excludes `is_premium = true`. The `entities_select_org_member` policy blocks basic members from premium rows.
2. **UI (Component):** `PremiumGate.vue` enforces a second layer. Even if RLS failed, the UI would still lock the content.

---

## 8. UI Design System — Ainux Signature

### 8.1 Color Palette

| Token | Hex | Usage |
|-------|-----|-------|
| `onyx` | `#0a0a0a` | Primary background |
| `onyx-50` | `#1a1a1a` | Elevated surfaces |
| `onyx-100` | `#2a2a2a` | Card borders |
| `gold` | `#d4af37` | Primary accent, CTAs |
| `gold-100` → `gold-900` | `#f9eac1` → `#48350d` | Gold spectrum |

### 8.2 Glassmorphism Utilities

```css
.glass         { @apply backdrop-blur-xl bg-white/5 border border-white/10 shadow-glass; }
.glass-hover   { @apply hover:bg-white/10 hover:border-gold/30 transition-all duration-300; }
.gradient-gold { @apply bg-gradient-to-r from-gold-400 to-gold-200 bg-clip-text text-transparent; }
.gold-border   { @apply border border-gold/30; }
```

### 8.3 Typography

| Script | Font Stack |
|--------|-----------|
| Latin | `Inter`, system-ui, sans-serif |
| Arabic | `Noto Naskh Arabic`, `Tajawal`, system-ui, sans-serif |

Font switching is automatic via `html[lang='ar'] body` in CSS.

### 8.4 Component Conventions

- All interactive elements use `transition-all duration-200/300`
- Glass cards use `rounded-2xl` with `p-4/6/8` variants
- Buttons: 4 variants (`primary` / `secondary` / `ghost` / `outline`), 3 sizes (`sm` / `md` / `lg`)
- Badges: 5 variants (`default` / `premium` / `success` / `warning` / `info`)
- Loading skeletons use `animate-pulse` with `bg-white/5` and `bg-white/10`

---

## 9. Edge Deployment (Cloudflare)

### 9.1 Configuration

```ts
// nuxt.config.ts
nitro: {
  preset: 'cloudflare-pages',
}
```

### 9.2 Route Rules

```ts
routeRules: {
  '/': { prerender: true },          // Hub static at build time
  '/**': { ssr: true },              // Dynamic tenant routes via SSR
}
```

### 9.3 Environment Variables

⚠️ **Supabase changed key naming convention in 2025-2026.** The old `SUPABASE_SERVICE_KEY` and `SUPABASE_KEY` are deprecated. Current names:

| Variable | Value Pattern | Source | Purpose |
|----------|--------------|--------|---------|
| `SUPABASE_URL` | `https://*.supabase.co` | Supabase dashboard > API | Project endpoint |
| `SUPABASE_KEY` | `sb_publishable_*` | Supabase dashboard > API > anon/public | Anon key (client-safe, starts with `sb_publishable_`) |
| `SUPABASE_SECRET_KEY` | `sb_secret_*` | Supabase dashboard > API > service_role | Service role key (server-only, starts with `sb_secret_`) |
| `NUXT_PUBLIC_SITE_URL` | `https://*` | Custom | Canonical base URL |
| `NUXT_PUBLIC_SITE_NAME` | `Burhan` | Custom | Site name for SEO |

**Runtime Config Mapping:** `@nuxtjs/supabase` stores config at nested paths, NOT flat:
- `SUPABASE_URL` → `runtimeConfig.public.supabase.url`
- `SUPABASE_KEY` → `runtimeConfig.public.supabase.key`
- `SUPABASE_SECRET_KEY` → NU does NOT auto-map to `runtimeConfig.supabase.serviceKey`

**Fix:** Pass explicitly in `nuxt.config.ts`:
```ts
supabase: {
  serviceKey: process.env.SUPABASE_SECRET_KEY,  // Maps project env var to module's expected key
  ...
}
```

**Do NOT rely on `serverSupabaseClient(event)` auto-import** — It throws `ReferenceError: serverSupabaseClient is not defined`. The auto-import declared in `.nuxt/types/supabase.d.ts` is unreliable. Instead, use the explicit factory in `server/utils/supabase.ts`:

```ts
import { createClient } from '@supabase/supabase-js'

export function getSupabaseClient() {
  const config = useRuntimeConfig()
  const url = config.public.supabase?.url as string     // ← nested, NOT config.public.supabaseUrl
  const key = config.public.supabase?.key as string      // ← nested, NOT config.public.supabaseKey
  return createClient(url, key)
}
```

**Env var fallback for service key:** `getSupabaseAdmin()` reads `config.supabase?.serviceKey`. If `SUPABASE_SERVICE_KEY` is not set at build time, the module's `runtimeConfig.supabase.serviceKey` is undefined. The fix is `serviceKey: process.env.SUPABASE_SECRET_KEY` in `nuxt.config.ts` (as shown above), which reads the actual env var at build time from `.env`.

#### `.env` Survival Guide

```bash
# CORRECT — these are the current Supabase key names (2025+)
SUPABASE_URL=https://mxygtztjsypemrhbtsoc.supabase.co
SUPABASE_KEY=sb_publishable_qHk092QZHmKbPfTbg2zoGg_8zTwf8-s
SUPABASE_SECRET_KEY=sb_secret_3mKMuB4QqHTzzqy1Utk_ww_wkKVmOKg

# DO NOT use — these are deprecated/renamed:
# SUPABASE_SERVICE_KEY=xxx  ← old name for secret key
# NUXT_PUBLIC_SUPABASE_URL=xxx  ← old Nuxt 3 convention
# NUXT_PUBLIC_SUPABASE_KEY=xxx  ← old Nuxt 3 convention
```

---

## 10. Development Cheat Sheet

### Commands

```bash
npm run dev          # Start dev server (http://localhost:3000)
npm run build        # Production build (Cloudflare Pages)
npm run generate     # Static generation
npm run preview      # Preview production build
npm run typecheck    # TypeScript check
npm run postinstall  # nuxt prepare (run after clone)
```

### File Creation Order (for future agents)

1. Nuxt config + Tailwind (scaffolding)
2. Supabase migration (database)
3. i18n JSONs (translations)
4. Server utils + API (backend)
5. Composables (logic layer)
6. Middleware (route guard)
7. UI primitives (atoms)
8. Feature components (molecules)
9. Pages (organisms)
10. Layout + app.vue (shell)

### Env Setup After Clone

```bash
cp .env.example .env
# Fill in SUPABASE_URL, SUPABASE_KEY, SUPABASE_SECRET_KEY
npm install
npm run dev
```

### Database Migration

```bash
# Push to Supabase (via CLI or Supabase dashboard)
# File: supabase/migrations/00001_initial_schema.sql
```

---

## 11. Organization Dashboard

### 11.1 Architecture

```
/dashboard ← dashboard.vue layout + dashboard-auth middleware
    ├── index.vue      → Overview: 4 stat cards (existing)
    ├── branches.vue   → Branch CRUD: list / create / edit / delete (419 lines)
    └── entities/
        ├── index.vue  → Entity list: search, filter, inline modal CRUD (535 lines)
        ├── new.vue    → Article creation: slug gen, RichTextEditor, cover upload (315 lines)
        └── [id].vue   → Article editing: same layout as new + cover image (343 lines)
```

**Layout** (`app/layouts/dashboard.vue`): Minimal shell that renders `<FloatingSidebar />` + main content slot. The content area dynamically adjusts margin based on pin state and locale:

```html
<div
  class="flex flex-col min-h-screen transition-all duration-300"
  :class="isPinned ? (locale === 'ar' ? 'lg:mr-[380px]' : 'lg:ml-[380px]') : ''"
>
```

### 11.2 Stats Grid (Overview Page)

4 glassmorphic stat cards in a responsive grid (`1→2→4 columns`):

| Stat | Mock Value | i18n Key |
|------|-----------|----------|
| Total Videos | `1,284` | `dashboard.total_videos` |
| Active Branches | `8` | `dashboard.active_branches` |
| Premium Revenue | `$12,450` | `dashboard.premium_revenue` |
| Total Subscribers | `342` | `dashboard.total_subscribers` |

Each card: gold icon container → change badge (green/red pill) → large value → stat label → description.

### 11.3 Branches CRUD (`branches.vue`)

- **List:** Table with columns (name, slug, module type, status, items count, actions)
- **Create/Edit:** Glass modal form with `name_ar` / `name_en`, slug auto-generation from English name, module type selector (`content` / `media` / `forum`), active toggle
- **Delete:** Confirm dialog with `window.confirm(t(...))`
- **Validation:** All fields required → `t('dashboard.validation.required_fields')`, org guard → `t('common.org_not_found')`
- **Data:** `supabase.from('branches')` scoped to `organization_id`

### 11.4 Navbar Integration

The `default.vue` layout shows `nav.dashboard` ("لوحة التحكم") linking to `/dashboard` when the user is authenticated. The old `/profile` link was removed because it clashed with the `[slug].ts` dynamic route.

---

## 12. Floating Sidebar — Interaction Model

### 12.1 States

| State | Width | Trigger |
|-------|-------|---------|
| Collapsed (idle) | `60px` | Default — shows only icon bubbles |
| Expanded (hover) | `280px` | `@mouseenter` on the bubble zone |
| Pinned (locked open) | `280px` | Double-click anywhere OR click pin icon |

### 12.2 Implementation — `FloatingSidebar.vue`

- Position: `fixed`, `z-50`, anchored to bottom of viewport (`bottom: 1rem`)
- Flips sides with locale: `locale === 'ar' ? 'right-4' : 'left-4'`
- Pinned state: `useState('sidebar-pinned')` — shared with dashboard layout for margin adjustment
- CSS transition: `width .4s cubic-bezier(.4,0,.2,1)` with `grid-template-rows` for content reveal
- Dark background: `rgba(10, 10, 10, 0.96)` with white/5 borders — no glass blur (performance)

### 12.3 Elements (top→bottom)

```
┌─────────────────────────────┐
│ Logo + Org Name    [pin 🔗] │  ← Header
├─────────────────────────────┤
│ 🏠 Overview                 │
│ 📂 Branches                 │  ← Navigation (NuxtLink)
│ 📄 Entities                 │
├─────────────────────────────┤
│ ← System Hub                │  ← Back to tenant site
├─────────────────────────────┤
│ 👤 user@email  [🌐] [🚪]   │  ← Footer: locale + logout
└─────────────────────────────┘
```

- **Logo:** 10×10 gold rounded box with 4-square grid icon
- **Navigation:** `NuxtLink` with `:to="localePath(...)"` — locale-aware
- **Active state:** `route.path === localePath(path)` — handles locale prefix matching
- **Locale toggle:** Globe icon button → `setLocale(locale.value === 'ar' ? 'en' : 'ar')`
- **Logout:** `supabase.auth.signOut()` → `navigateTo('/login')`
- **Pin icon:** 45° rotated pushpin SVG when pinned, shows gold color

### 12.4 Pin Interaction

```ts
function togglePin() {
  isPinned.value = !isPinned.value
}
```

Bound to:
- `@dblclick` on the sidebar container
- `@click` on the pin icon button in the header

The layout consumes `isPinned` to adjust content margin (`mr-[380px]` for Arabic / `ml-[380px]` for English).

---

## 13. Entity CRUD — Full Lifecycle

### 13.1 Data Model (per entity)

```ts
type Entity = {
  id: string
  organization_id: string
  branch_id: string
  title: { ar: string, en: string }       // JSONB
  content: { ar: string, en: string }      // JSONB (editor HTML)
  content_type: 'video' | 'article'
  video_id: string | null
  primary_source: string | null
  cover_url: string | null
  slug: string | null                      // URL-safe (articles only)
  is_premium: boolean
  price: number | null
  is_public_to_hub: boolean
  created_at: string
}
```

### 13.2 Entity List — `entities/index.vue`

- **Data:** `useFetch`-style fetch via `supabase.from('entities').select('*').eq('organization_id', id)`
- **List:** Glass cards with title (localized), branch badge, premium/free badge
- **Search:** Filter by `title.ar` or `title.en` (case-insensitive)
- **Filter:** Branch selector dropdown
- **Actions per entity:** Edit (opens inline modal) / Delete (confirm + remove)
- **Inline modal:** Create + edit in a single modal form — title (ar/en), content (ar/en), content type, video ID, premium toggle, hub visibility
- **Bulk actions:** "Article" button navigates to `new.vue` for full editor
- **Navigation uses `localePath()`:** `navigateTo(localePath('/dashboard/entities/new'))`
- **Error messages translated:** `t('dashboard.validation.title_branch_required')`, `t('common.org_not_found')`

### 13.3 New Article — `entities/new.vue`

- **Route:** `/dashboard/entities/new` (dashboard layout, dashboard-auth middleware)
- **Language tabs:** `currentLang` toggle (ar ↔ en) with `$t('locale.switch_to_*')`
- **Cover image:** Upload via `useSupabaseStorage().uploadFile()` with `compressImage()` utility
- **Slug:** Auto-generated from English title via `@click="generateSlug()"` — lowercased, spaces→hyphens, stripped special chars
- **Content editor:** `RichTextEditor` component — separate instance per language
- **Sub-fields per language:** Title input + RichTextEditor HTML content
- **Metadata:** Branch selector, premium toggle + price input, hub visibility toggle
- **Save:** `supabase.from('entities').insert(payload)` → `navigateTo(localePath('/dashboard/entities'))`
- **Validation:** Title (both), branch, slug required → `t('dashboard.validation.title_branch_slug_required')`

### 13.4 Edit Article — `entities/[id].vue`

- **Route:** `/dashboard/entities/:id` — same structure as `new.vue` plus cover image management
- **Load:** `useFetch()` with `useRoute().params.id` — 404 if not found
- **Cover:** `coverUrl` preview + `changeCover()` / `removeCover()` — uploads to Supabase storage
- **Save:** `supabase.from('entities').update(payload).eq('id', entityId)`
- **Cancel/Back:** `navigateTo(localePath('/dashboard/entities'))`

---

## 14. Rich Text Editor

### 14.1 Component — `RichTextEditor.vue`

A Tiptap-powered WYSIWYG editor (using `contenteditable` with manual execCommands — no Tiptap package dependency).

```
446 lines — Template: 105 | Script: 145 | Style: 196
```

### 14.2 Toolbar

| Button | Action | i18n Key |
|--------|--------|----------|
| ↩️ Undo | `document.execCommand('undo')` | `dashboard.editor.toolbar.undo` |
| ↪️ Redo | `document.execCommand('redo')` | `dashboard.editor.toolbar.redo` |
| H2 | `execCommand('formatBlock', 'h2')` | `dashboard.editor.toolbar.heading_2` |
| H3 | `execCommand('formatBlock', 'h3')` | `dashboard.editor.toolbar.heading_3` |
| **B** Bold | `execCommand('bold')` | `dashboard.editor.toolbar.bold` |
| *I* Italic | `execCommand('italic')` | `dashboard.editor.toolbar.italic` |
| <u>U</u> Underline | `execCommand('underline')` | `dashboard.editor.toolbar.underline` |
| ≡ Bullet List | `execCommand('insertUnorderedList')` | `dashboard.editor.toolbar.bullet_list` |
| 🔗 Link | Opens link modal (`prompt`-based) | `dashboard.editor.toolbar.insert_link` |
| ✕ Clear | `execCommand('removeFormat')` | `dashboard.editor.toolbar.remove_format` |

All toolbar `title` attributes use `$t()` — translated live with locale switch.

### 14.3 Features

- **History stack:** Custom `history[]` array with `historyIndex` pointer, max 50 states
- **Placeholder:** CSS pseudo-element shown when content is empty
- **Cover image:** Separate upload section (not inline) — uses Supabase storage
- **Link modal:** Simple `window.prompt()` for URL input
- **Image upload:** Emits `'image-upload'` event for parent to handle

### 14.4 Styling

- Printed content area uses `[contenteditable]` with custom prose styles
- Prose spacing: `space-y-4` between block elements, `leading-relaxed` for paragraphs
- Links styled gold: `text-gold hover:underline`
- Headings: H2 → `text-xl font-bold`, H3 → `text-lg font-bold`
- Lists: `list-disc list-inside`
- Background: `bg-black/20` with `rounded-2xl` and white/5 border

---

## 15. Caching & Locale Path Strategy

### 15.1 Page Caching — `<NuxtPage keepalive />`

In `app.vue`, `<NuxtPage />` was updated to `<NuxtPage keepalive />`. This keeps dashboard page components alive when navigating between them (e.g., entities list → entities/new → back), preventing redundant Supabase re-fetches on every route change.

- **Same-locale navigation:** Pages are cached — zero re-fetch
- **Cross-locale navigation:** Route changes (prefix added/removed), so cache is naturally bypassed

### 15.2 Locale-Aware Navigation — `useLocalePath()`

All dashboard navigation links must preserve the locale prefix to prevent "first click goes to Arabic" bug:

**Problem:** With `prefix_except_default` strategy, switching locale via `setLocale('en')` navigates to `/en/dashboard/...`. But hardcoded `<NuxtLink to="/dashboard/entities">` points to Arabic (no prefix), so the first nav click after switching to English goes back to Arabic.

**Solution:** Every `<NuxtLink>` and `navigateTo()` call in dashboard files uses `localePath()`:

```ts
const localePath = useLocalePath()

// Template
<NuxtLink :to="localePath('/dashboard/entities')" />

// Script
navigateTo(localePath('/dashboard/entities/new'))
```

**Files fixed (12 total occurrences):**
- `FloatingSidebar.vue` — all navigation links + Hub link
- `entities/index.vue` — `navigateTo` for new + edit routes
- `entities/[id].vue` — `NuxtLink` back + cancel button
- `entities/new.vue` — `NuxtLink` back + cancel button

### 15.3 Active Route Detection

The `isActive()` helper was also fixed to use `localePath()`:

```ts
// Before (broken with English locale):
const isActive = (path: string) => route.path === path

// After (works with any locale):
const isActive = (path: string) => route.path === localePath(path)
```

---

## 16. i18n Audit — Rule Enforcement

### 16.1 Key Inventory

| Section | Keys | Status |
|---------|------|--------|
| `nav` | 11 | ✅ Documented |
| `hub` | 12 | ✅ Documented |
| `brand` / `layout` / `footer` | 9 | ✅ Documented |
| `tenant` / `org_header` | 11 | ✅ Documented |
| `entities` | 17 | ✅ Documented |
| `video` | 12 | ✅ Documented |
| `premium` | 12 | ✅ Documented |
| `auth` | 34 | ✅ Documented |
| `dashboard` | 65+ | ✅ Documented |
| `dashboard.editor.*` | 4 sub-keys | ✅ Documented |
| `dashboard.editor.toolbar.*` | 10 keys | ✅ New |
| `dashboard.validation.*` | 4 keys | ✅ New |
| `locale` | 3 | ✅ Documented |
| `common` | 23 | ✅ Documented |
| `errors` | 7 | ✅ Documented |
| `empty` | 6 | ✅ Documented |
| `seo` | 8 | ✅ Documented |

### 16.2 Files Audited & Fixed

| File | Lines | Issues Fixed |
|------|-------|-------------|
| `FloatingSidebar.vue` | 223 | Hub label, Pin/Unpin titles, locale button title |
| `branches.vue` | 419 | "All fields are required" + "Organization not found" |
| `entities/index.vue` | 535 | 3 error strings, 2 content labels |
| `entities/[id].vue` | 343 | 2 error strings, language tab labels |
| `entities/new.vue` | 315 | 2 error strings, language tab labels |
| `RichTextEditor.vue` | 446 | 10 toolbar titles |
| **Total** | **2,281** | **~22 hardcoded strings → i18n** |

### 16.3 Zero Hardcoded UI Rule (Updated)

- All visible template text uses `$t('key')`
- All script error/success messages use `t('key')`
- Placeholders that depend on content language (not UI language) are exempt (e.g., "عنوان المقال..." is always Arabic regardless of UI locale)
- Format examples like `placeholder="0.00"` are exempt

---

## 17. Migration History

### `00001_initial_schema.sql`
Full initial schema: organizations, branches, entities, profiles tables with RLS policies, triggers, and indexes.

### `00002_fix_branches_rls.sql`
Fixed branches RLS to use `auth.uid()` pattern correctly. Added missing policies for owner/manager operations.

### `00003_fix_profiles_rls_recursion.sql`
Fixed infinite recursion in profiles RLS caused by self-referential policies. Used `auth.jwt()` claims instead of querying profiles within profiles policies.

### Supabase Schema Reference
- `user_role` ENUM: `super_admin`, `owner`, `manager`, `member`
- All tables use `UUID PK` with `created_at TIMESTAMPTZ DEFAULT now()`
- JSONB fields: `branches.name`, `entities.title`, `entities.content` — always `{ ar, en }`
- Storage bucket: `covers` for entity cover images (public-read, authenticated-write)
