# Supabase Backend — Complete Reference

## Table of Contents

1. [Enums](#1-enums)
2. [Tables](#2-tables)
3. [Triggers](#3-triggers)
4. [Helper Functions](#4-helper-functions)
5. [Row Level Security (RLS)](#5-row-level-security-rls)
6. [Storage](#6-storage)
7. [API Endpoints](#7-api-endpoints)
8. [Setup Instructions](#8-setup-instructions)

---

## 1. Enums

```sql
module_type — ENUM: 'content' | 'forum' | 'media'
user_role   — ENUM: 'super_admin' | 'owner' | 'manager' | 'member'
```

### Role Hierarchy

| Role | Permissions |
|---|---|
| `super_admin` | Bypasses all RLS. Full cross-org CRUD. |
| `owner` | Full org management (billing, delete, all content). |
| `manager` | Content management (insert/update entities, branches, series). Cannot delete org or branches. |
| `member` | Read-only access to org non-premium content. Default on signup. |

---

## 2. Tables

### 2a. `organizations` — Tenant / Brand Owner

```sql
CREATE TABLE organizations (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name        TEXT NOT NULL,
  org_slug    TEXT UNIQUE NOT NULL,
  settings    JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

INDEX: idx_organizations_org_slug ON (org_slug)
```

**`settings` JSON structure:**
```json
{
  "colors": { "primary": "#...", "secondary": "#..." },
  "logos": { "light": "url", "dark": "url" },
  "branding": { ... }
}
```

### 2b. `branches` — Modular Sub-Sections

```sql
CREATE TABLE branches (
  id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  organization_id   UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  name              JSONB NOT NULL DEFAULT '{"ar": "", "en": ""}'::jsonb,
  slug              TEXT NOT NULL,           -- URL-safe, unique per org
  module_type       module_type NOT NULL DEFAULT 'content',
  is_active         BOOLEAN NOT NULL DEFAULT true,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);

INDEXES:
  idx_branches_organization_id ON (organization_id)
  idx_branches_org_slug        ON (organization_id, slug) UNIQUE
  idx_branches_active          ON (is_active) WHERE is_active = true
```

### 2c. `profiles` — Extends `auth.users`

```sql
CREATE TABLE profiles (
  id                UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  organization_id   UUID REFERENCES organizations(id) ON DELETE SET NULL,
  full_name         JSONB NOT NULL DEFAULT '{"ar": "", "en": ""}'::jsonb,
  role              user_role NOT NULL DEFAULT 'member',
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);

INDEX: idx_profiles_organization_id ON (organization_id)
```

**Auto-created** via `handle_new_user()` trigger on auth.users INSERT.

### 2d. `entities` — Content Engine

```sql
CREATE TABLE entities (
  id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  branch_id         UUID NOT NULL REFERENCES branches(id) ON DELETE CASCADE,
  organization_id   UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  title             JSONB NOT NULL DEFAULT '{"ar": "", "en": ""}'::jsonb,
  content           JSONB NOT NULL DEFAULT '{"ar": "", "en": ""}'::jsonb,
  content_type      TEXT NOT NULL DEFAULT 'article'
                    CHECK (content_type IN ('video', 'article', 'audio')),
  is_public_to_hub  BOOLEAN NOT NULL DEFAULT false,
  -- Video fields
  video_id          TEXT,
  primary_source    TEXT NOT NULL DEFAULT 'youtube',
  fallback_source   TEXT,
  fallback_url      TEXT,
  -- Audio fields
  audio_url         TEXT,
  audio_file        TEXT,
  -- Premium monetization
  is_premium        BOOLEAN NOT NULL DEFAULT false,
  price             DECIMAL(10,2),
  -- Series ordering
  series_id         UUID REFERENCES series(id) ON DELETE SET NULL,
  sort_order        INT NOT NULL DEFAULT 0,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);

INDEXES:
  idx_entities_branch_id          ON (branch_id)
  idx_entities_organization_id    ON (organization_id)
  idx_entities_public_to_hub      ON (is_public_to_hub) WHERE is_public_to_hub = true
  idx_entities_premium            ON (is_premium)
  idx_entities_series_id          ON (series_id)
  idx_entities_series_order       ON (series_id, sort_order, created_at) WHERE series_id IS NOT NULL
```

**`content_type` values:**
| Value | Fields Used |
|---|---|
| `article` | `title`, `content` (rich text JSONB) |
| `video` | `title`, `content`, `video_id`, `primary_source`, `fallback_source`, `fallback_url` |
| `audio` | `title`, `content`, `audio_url`, `audio_file` |

### 2e. `series` — Educational Tracks / Playlists

```sql
CREATE TABLE series (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  branch_id       UUID NOT NULL REFERENCES branches(id) ON DELETE CASCADE,
  title           JSONB NOT NULL DEFAULT '{"ar": "", "en": ""}'::jsonb,
  description     JSONB DEFAULT '{"ar": "", "en": ""}'::jsonb,
  cover_url       TEXT,
  is_active       BOOLEAN NOT NULL DEFAULT true,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

INDEXES:
  idx_series_organization_id ON (organization_id)
  idx_series_branch_id       ON (branch_id)
```

### 2f. `observatory_analysts` — Observatory Access Control

```sql
CREATE TABLE observatory_analysts (
  id           UUID PRIMARY KEY REFERENCES profiles(id) ON DELETE CASCADE,
  role_type    TEXT NOT NULL CHECK (role_type IN ('observatory_manager', 'observatory_analyst')),
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

### 2g. `observatory_threats` — Digital Observatory Threats

```sql
CREATE TABLE observatory_threats (
  id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title                TEXT NOT NULL,
  source_url           TEXT NOT NULL,
  platform             TEXT NOT NULL DEFAULT 'unknown',
  danger_level         TEXT NOT NULL DEFAULT 'Medium' CHECK (danger_level IN ('Low', 'Medium', 'High')),
  status               TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'under_review', 'neutralized')),
  assigned_scholar_id  UUID REFERENCES profiles(id) ON DELETE SET NULL,
  reported_by          UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  response_url         TEXT,
  created_at           TIMESTAMPTZ NOT NULL DEFAULT now()
);

INDEXES:
  idx_threats_status        ON observatory_threats (status)
  idx_threats_platform      ON observatory_threats (platform)
  idx_threats_created_at    ON observatory_threats (created_at DESC)
  idx_threats_neutralized   ON observatory_threats (status) WHERE status = 'neutralized'
```

### 2h. `plans` — Subscription Tiers & Quotas (Migration 00015)

```sql
CREATE TABLE plans (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name           TEXT NOT NULL,
  slug           TEXT UNIQUE NOT NULL,
  description    TEXT,
  price_monthly  INTEGER NOT NULL DEFAULT 0,
  price_yearly   INTEGER NOT NULL DEFAULT 0,
  limits         JSONB NOT NULL DEFAULT '{}'::jsonb,
  features       JSONB NOT NULL DEFAULT '{}'::jsonb,
  is_active      BOOLEAN NOT NULL DEFAULT true,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

INDEX: idx_plans_slug ON plans (slug)
```

**Canonical plans seeded:**
- `community`: Free, perpetual (`branches: -1` unlimited, `custom_domain: false`, `ai_generate: false`)
- `pro`: Tiered (`branches: 10`, `custom_domain: true`, `ai_generate: true`)

### 2i. `subscriptions` — Tenant Plan Assignments (Migration 00015)

```sql
CREATE TABLE subscriptions (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id  UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  plan_id          UUID NOT NULL REFERENCES plans(id),
  status           TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'past_due', 'cancelled', 'expired')),
  billing_period   TEXT NOT NULL DEFAULT 'monthly' CHECK (billing_period IN ('monthly', 'yearly')),
  starts_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  expires_at       TIMESTAMPTZ,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

INDEX: idx_subscriptions_org_active ON subscriptions (organization_id) WHERE status = 'active'
```

### 2j. `ai_jobs` — Server-Only AI Inference Lifecycle (Migration 00010)

```sql
CREATE TABLE ai_jobs (
  id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id    UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  branch_id          UUID REFERENCES branches(id) ON DELETE SET NULL,
  user_id            UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  status             TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'processing', 'completed', 'failed', 'cancelled')),
  prompt             TEXT NOT NULL,
  system_prompt      TEXT,
  language           TEXT NOT NULL DEFAULT 'ar',
  model              TEXT NOT NULL,
  provider           TEXT NOT NULL DEFAULT 'nosana',
  estimated_tokens   INTEGER NOT NULL DEFAULT 0,
  tokens_used        INTEGER,
  error              TEXT,
  output             TEXT,
  stream_buffer      TEXT,
  period_month       VARCHAR(7) NOT NULL,
  quota_reconciled   BOOLEAN NOT NULL DEFAULT false,
  consumed           BOOLEAN NOT NULL DEFAULT false,
  last_heartbeat_at  TIMESTAMPTZ,
  created_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at         TIMESTAMPTZ NOT NULL DEFAULT now()
);

INDEXES:
  idx_ai_jobs_organization_id ON ai_jobs (organization_id)
  idx_ai_jobs_user_id         ON ai_jobs (user_id)
  idx_ai_jobs_status          ON ai_jobs (status)
  idx_ai_jobs_stale           ON ai_jobs (status, last_heartbeat_at)
```

### 2k. `ai_usage` — Monthly Quota Accounting Ledger (Migration 00010)

```sql
CREATE TABLE ai_usage (
  organization_id   UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  period_month      VARCHAR(7) NOT NULL,
  requests_used     INTEGER NOT NULL DEFAULT 0,
  tokens_reserved   INTEGER NOT NULL DEFAULT 0,
  tokens_used       INTEGER NOT NULL DEFAULT 0,
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (organization_id, period_month)
);
```

### 2l. `tenant_ai_credentials` — BYOK Encrypted Vault (Migration 00018)

```sql
CREATE TABLE tenant_ai_credentials (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id  UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  provider         TEXT NOT NULL,
  encrypted_key    TEXT NOT NULL,
  key_iv           TEXT NOT NULL,
  key_tag          TEXT NOT NULL,
  key_version      INTEGER NOT NULL DEFAULT 1,
  key_suffix       TEXT NOT NULL,
  base_url         TEXT,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT uq_tenant_ai_credentials_org_provider UNIQUE (organization_id, provider)
);

INDEX: idx_tenant_ai_credentials_lookup ON tenant_ai_credentials (organization_id, provider)
```

---

## 3. Triggers

### `handle_new_user()` — Auto-create Profile

```sql
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = ''
AS $$
BEGIN
  INSERT INTO public.profiles (id, full_name, role)
  VALUES (
    NEW.id,
    jsonb_build_object(
      'ar', COALESCE(NEW.raw_user_meta_data ->> 'full_name_ar', ''),
      'en', COALESCE(NEW.raw_user_meta_data ->> 'full_name_en', '')
    ),
    'member'
  );
  RETURN NEW;
END;
$$;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION handle_new_user();
```

### `auto_detect_platform()` — Auto-detect Threat Platform

```sql
CREATE OR REPLACE FUNCTION auto_detect_platform()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.platform := CASE
    WHEN NEW.source_url ~* 'tiktok\.com'     THEN 'tiktok'
    WHEN NEW.source_url ~* 'youtube\.com'    THEN 'youtube'
    WHEN NEW.source_url ~* 'youtu\.be'       THEN 'youtube'
    WHEN NEW.source_url ~* 'facebook\.com'   THEN 'facebook'
    WHEN NEW.source_url ~* 'x\.com'          THEN 'x'
    WHEN NEW.source_url ~* 'twitter\.com'    THEN 'x'
    WHEN NEW.source_url ~* 'instagram\.com'  THEN 'instagram'
    WHEN NEW.source_url ~* 'telegram\.(me|org)' THEN 'telegram'
    ELSE 'other'
  END;
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_auto_detect_platform
  BEFORE INSERT ON observatory_threats
  FOR EACH ROW
  EXECUTE FUNCTION auto_detect_platform();
```

### `check_branch_limit()` — Enforce Plan Branch Quotas (Migration 00016)

```sql
CREATE OR REPLACE FUNCTION public.check_branch_limit()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
...
-- Enforces plan limit from active subscription:
-- -1 = unlimited branches (Community plan)
-- > 0 = strict cap; raises 'branch_limit_exceeded' on breach
-- Super Admins bypass the limit
$$;

CREATE TRIGGER trg_enforce_branch_limit
  BEFORE INSERT ON public.branches
  FOR EACH ROW
  EXECUTE FUNCTION public.check_branch_limit();
```

### `enforce_profile_security()` — Guard Role Escalation & Tenant Boundaries (Migration 00017)

```sql
CREATE OR REPLACE FUNCTION public.enforce_profile_security()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
...
-- Prevents self-assignment to organizations
-- Blocks cross-tenant switching
-- Blocks unauthorized role elevation (member -> manager/owner/super_admin)
-- Enforces active subscription destination check on Super Admin assignments
$$;

CREATE TRIGGER trg_enforce_profile_security
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.enforce_profile_security();
```

**Behavior:**
- Fires on every `auth.users` INSERT (signup, admin create)
- Creates a `profiles` row with `role = 'member'` and `organization_id = NULL`
- The `register-tenant` API later upgrades this to `role = 'owner'` with the org ID

---

## 4. Helper Functions

All helper functions are `SECURITY DEFINER` (bypass RLS) to avoid recursion in RLS policies.

```sql
-- Get current user's role (default: 'member')
CREATE FUNCTION public.get_current_user_role()
RETURNS user_role
LANGUAGE SQL STABLE SECURITY DEFINER SET search_path = public
AS $$
  SELECT COALESCE(
    (SELECT role FROM profiles WHERE id = auth.uid() LIMIT 1),
    'member'::user_role
  );
$$;

-- Get current user's organization_id (nullable)
CREATE FUNCTION public.get_current_user_org_id()
RETURNS UUID
LANGUAGE SQL STABLE SECURITY DEFINER SET search_path = public
AS $$
  SELECT organization_id FROM profiles WHERE id = auth.uid() LIMIT 1;
$$;

-- Check if current user is an Observatory Manager
CREATE FUNCTION public.is_observatory_manager()
RETURNS BOOLEAN
LANGUAGE SQL STABLE SECURITY DEFINER SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM observatory_analysts
    WHERE id = auth.uid() AND role_type = 'observatory_manager'
  );
$$;

-- Check if current user is a System Super Admin
CREATE FUNCTION public.is_super_admin()
RETURNS BOOLEAN
LANGUAGE SQL STABLE SECURITY DEFINER SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM profiles
    WHERE id = auth.uid() AND role = 'super_admin'
  );
$$;

-- Evaluate Active Tenant Subscription (Migration 00015)
CREATE FUNCTION public.is_org_subscription_active(org_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.subscriptions
    WHERE organization_id = org_id
      AND status = 'active'
      AND (expires_at IS NULL OR expires_at > now())
  );
END;
$$;

-- Atomic Tenant Provisioning Engine (Migration 00019)
CREATE FUNCTION public.provision_tenant(p_user_id UUID, p_org_name TEXT, p_org_slug TEXT)
RETURNS JSONB
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
...
-- Single atomic transaction:
-- 1. Input sanitization & slug regex check
-- 2. Concurrency lock: SELECT id FROM profiles WHERE id = p_user_id FOR UPDATE
-- 3. Idempotency check: returns existing tenant if matching slug, rejects if user already owns tenant
-- 4. Inserts organization with unique slug error trapping
-- 5. Inserts perpetual community subscription
-- 6. Inserts canonical main branch
-- 7. Upgrades profile to owner
-- 8. Returns canonical JSON payload
$$;
-- Granted strictly to service_role; denied to public, anon, authenticated.

-- DeAI Inference RPCs (Migration 00010) — Granted strictly to service_role:
-- public.reserve_ai_job_quota(p_user_id, p_org_id, p_branch_id, p_prompt, p_system_prompt, p_model, p_provider, p_estimated_tokens, p_lang)
-- public.complete_ai_job(p_job_id, p_actual_tokens, p_output, p_model)
-- public.fail_ai_job(p_job_id, p_error)
-- public.cancel_ai_job(p_job_id)
-- public.heartbeat_ai_job(p_job_id)
-- public.reap_stale_ai_job(p_job_id)
-- public.reconcile_abandoned_terminal_ai_jobs(p_org_id)
```

**Permissions:** Helper function permissions are revoked from `public` and `anon`, and explicitly granted to `authenticated` users only (or restricted to `service_role` exclusively for RPCs like `provision_tenant` and DeAI lifecycle engines).

---

## 5. Row Level Security (RLS)

### 5a. `organizations`

| Policy | Operation | Scope |
|---|---|---|
| `organizations_select_all` | SELECT | Everyone (true) |
| `organizations_insert_super_admin` | INSERT | super_admin only |
| `organizations_update_owner_or_super_admin` | UPDATE | owner (same org) + super_admin |
| `organizations_delete_super_admin` | DELETE | super_admin only |

### 5b. `branches`

| Policy | Operation | Scope |
|---|---|---|
| `branches_select_public` | SELECT | Everyone (true) |
| `branches_insert_org_owner_or_manager` | INSERT | owner/manager (same org) + super_admin |
| `branches_update_org_owner_or_manager` | UPDATE | owner/manager (same org) + super_admin |
| `branches_delete_org_owner` | DELETE | owner (same org) + super_admin |

### 5c. `profiles`

| Policy | Operation | Scope |
|---|---|---|
| `profiles_select_own` | SELECT | Own row only (id = auth.uid()) |
| `profiles_select_org_members` | SELECT | Same org (via helper) + super_admin |
| `profiles_update_own` | UPDATE | Own row only |
| `profiles_update_org_staff` | UPDATE | owner (same org, via helper) + super_admin |

**Note:** Uses `get_current_user_org_id()` / `get_current_user_role()` helpers to avoid infinite recursion.

### 5d. `entities`

| Policy | Operation | Scope |
|---|---|---|
| `entities_select_public_hub` | SELECT | Public non-premium (unauthenticated OK) |
| `entities_select_org_member` | SELECT | Org members (premium blocked for member role) |
| `entities_insert_org_staff` | INSERT | owner/manager (same org) + super_admin |
| `entities_update_org_staff` | UPDATE | owner/manager (same org) + super_admin |
| `entities_delete_org_owner` | DELETE | owner/manager (same org) + super_admin |

**Premium logic:** `member` role users in an org see only non-premium entities. `owner`/`manager`/`super_admin` see everything.

### 5e. `series`

| Policy | Operation | Scope |
|---|---|---|
| `series_select_public` | SELECT (anon, auth) | Active series only (`is_active = true`) |
| `series_select_org` | SELECT (auth) | Same org members + super_admin |
| `series_insert_org` | INSERT | owner/manager (same org) + super_admin |
| `series_update_org` | UPDATE | owner/manager (same org) + super_admin |
| `series_delete_org` | DELETE | owner (same org) + super_admin |

### 5f. `observatory_analysts`

| Policy | Operation | Scope |
|---|---|---|
| `analysts_select_own` | SELECT | Own row only (`id = auth.uid()`) |
| `analysts_select_all_manager_or_super_admin` | SELECT | Observatory Manager or System Super Admin |
| `analysts_insert_manager_only` | INSERT | Observatory Manager or System Super Admin |
| `analysts_delete_manager_only` | DELETE | Observatory Manager or System Super Admin |

### 5g. `observatory_threats`

| Policy | Operation | Scope |
|---|---|---|
| `threats_insert_public` | INSERT | Everyone (`anon` or `authenticated`) |
| `threats_select_super_admin` | SELECT | Super Admin only |
| `threats_update_super_admin` | UPDATE | Super Admin only |
| `threats_delete_super_admin` | DELETE | Super Admin only |
| `threats_select_manager` | SELECT | Observatory Manager only |
| `threats_update_manager` | UPDATE | Observatory Manager only |
| `threats_delete_manager` | DELETE | Observatory Manager only |
| `threats_select_analyst` | SELECT | Observatory Analyst only |
| `threats_update_analyst` | UPDATE | Observatory Analyst only |
| `threats_select_neutralized_public` | SELECT | Everyone (`anon`/`auth`) for neutralized threats only (`status = 'neutralized'`) |

---

## 6. Storage

### Bucket: `organization_assets`

| Property | Value |
|---|---|
| Bucket ID | `organization_assets` |
| Public | `true` (URL access) |
| Max file size | 5 MB |
| Allowed MIME | `image/jpeg`, `image/png`, `image/gif`, `image/webp` |

### Storage RLS

| Policy | Operation | Role |
|---|---|---|
| `org_assets_insert` | INSERT | authenticated |
| `org_assets_select` | SELECT | public (removed in migration 00008 — public URL works via bucket public setting) |
| `org_assets_update` | UPDATE | authenticated |
| `org_assets_delete` | DELETE | authenticated |

---

## 7. API Endpoints

All endpoints are Nitro server routes in `server/api/`.

### `POST /api/auth/register-tenant`

3-step transaction using Supabase admin (service role) client:

```
Step  ┌────────────────────────────────────┐
 1    │ INSERT organization                │
      │   name: {ar, en}, org_slug, {}     │
      └────────────┬───────────────────────┘
                   │ org.id
                   ▼
Step  ┌────────────────────────────────────┐
 2    │ INSERT branch                      │
      │   org_id, name, slug:'main',       │
      │   module_type:'content'            │
      └────────────┬───────────────────────┘
                   │ (continues)
                   ▼
Step  ┌────────────────────────────────────┐
 3    │ UPDATE profile                     │
      │   org_id, role:'owner'             │
      │   WHERE id = auth_user.id          │
      └────────────┬───────────────────────┘
                   │
                   ▼
      RETURN { org, branch }
```

**Request body:**
```json
{
  "accessToken": "string (user session token)",
  "orgName": "string",
  "orgSlug": "string (URL-safe)"
}
```

**Errors:** 400 (validation), 401 (bad session), 409 (slug taken), 500 (DB failure)

### `GET /api/orgs`

Returns all organizations with their public entity count.

**Response:**
```json
[
  {
    "id": "uuid",
    "name": "string (JSONB)",
    "org_slug": "string",
    "settings": {},
    "created_at": "timestamp",
    "content_count": 0
  }
]
```

### `GET /api/orgs/[slug]`

Returns a single org with its branches. Used for tenant page rendering.

**Response:**
```json
{
  "id": "uuid",
  "name": "string (JSONB)",
  "org_slug": "string",
  "settings": {},
  "created_at": "timestamp",
  "branches": [
    { "id": "uuid", "name": "JSONB", "module_type": "content", "created_at": "timestamp" }
  ]
}
```

### `GET /api/entities/public`

Returns the 50 latest public non-premium entities for the hub feed. Includes nested org data.

**Response:**
```json
[
  {
    "id": "uuid",
    "title": "JSONB",
    "content": "JSONB",
    "is_public_to_hub": true,
    "is_premium": false,
    "price": null,
    "video_id": "string | null",
    "primary_source": "youtube",
    "created_at": "timestamp",
    "branch_id": "uuid",
    "organization_id": "uuid",
    "organizations": {
      "name": "string (JSONB)",
      "org_slug": "string",
      "settings": {}
    }
  }
]
```

### `POST /api/observatory/report`

Public reporting endpoint for registering intellectual threats. Bypasses RLS to submit a threat and automatically uses Turnstile verification if keys are provided in runtime config.

**Request body:**
```json
{
  "title": "string (Threat title/description)",
  "sourceUrl": "string (External platform URL)",
  "turnstileToken": "string (Cloudflare Turnstile client verification token)"
}
```

### `POST /api/observatory/analysts`

Admin endpoint for adding new observatory analysts. Restricted to Observatory Managers or Super Admins.

**Request body:**
```json
{
  "email": "string (Target user's email)",
  "roleType": "string ('observatory_manager' | 'observatory_analyst')",
  "accessToken": "string (Caller's session access token)"
}
```

### Server Utilities

**`server/utils/supabase.ts`:**
| Function | Client Type | Key | Use Case |
|---|---|---|---|
| `getSupabaseClient()` | Anon (public) | `SUPABASE_KEY` | Public reads (hub, tenant pages) |
| `getSupabaseAdmin()` | Service role | `SUPABASE_SECRET_KEY` | Admin ops (register-tenant, bypass RLS) |

The admin client has `autoRefreshToken: false` and `persistSession: false` since it uses the static service key.

---

## 8. Setup Instructions

### Create a New Supabase Project

1. Go to [supabase.com](https://supabase.com) and create a project.
2. Go to **SQL Editor** in the Supabase Dashboard.
3. Open the unified setup script [`supabase/schema.sql`](./supabase/schema.sql), copy its entire contents, paste it into the SQL Editor, and click **Run**. This will build all tables, custom enums, trigger functions, RLS policies, indexes, and storage bucket settings at once.


### Environment Variables

Copy `.env.example` to `.env` and fill in the values:
```bash
cp .env.example .env
```
Key variables required:
```
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_KEY=your-anon-key
SUPABASE_SECRET_KEY=your-service-role-key
NUXT_PUBLIC_TURNSTILE_SITE_KEY=your-cloudflare-turnstile-site-key
NUXT_TURNSTILE_SECRET_KEY=your-cloudflare-turnstile-secret-key
```

### Using Supabase CLI (Alternative)

```bash
supabase link --project-ref your-project-ref
supabase db push
```

### Verify Setup

1. Sign up a user → profile auto-created by trigger.
2. POST to `/api/auth/register-tenant` → org + main branch + profile updated.
3. Add a user as an observatory analyst using the database or `/api/observatory/analysts` endpoint.
4. Verify RLS: unauthenticated users should only be able to query neutralized threats.
