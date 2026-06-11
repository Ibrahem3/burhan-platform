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

**Behavior:**
- Fires on every `auth.users` INSERT (signup, admin create)
- Creates a `profiles` row with `role = 'member'` and `organization_id = NULL`
- The `register-tenant` API later upgrades this to `role = 'owner'` with the org ID

---

## 4. Helper Functions

Both are `SECURITY DEFINER` (bypass RLS) to avoid recursion in profiles policies.

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
```

**Permissions:** Revoked from `public`/`anon`, granted to `authenticated` only.

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
| `series_select_public` | SELECT (anon) | Active series only |
| `series_select_org` | SELECT (auth) | Same org members + super_admin |
| `series_insert_org` | INSERT | owner/manager (same org) + super_admin |
| `series_update_org` | UPDATE | owner/manager (same org) + super_admin |
| `series_delete_org` | DELETE | owner (same org) + super_admin |

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

1. Go to [supabase.com](https://supabase.com) and create a project
2. Go to **SQL Editor**
3. Run each migration file in order:
   ```
   supabase/migrations/00001_initial_schema.sql
   supabase/migrations/00002_fix_branches_rls.sql
   supabase/migrations/00003_fix_profiles_rls_recursion.sql
   supabase/migrations/00004_add_branch_slug_is_active.sql
   supabase/migrations/00005_storage_bucket_policies.sql
   supabase/migrations/00006_series_and_playlists.sql
   supabase/migrations/00007_add_content_type_audio.sql
   supabase/migrations/00008_fix_security_lints.sql
   ```

### Environment Variables

```
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_KEY=your-anon-key
SUPABASE_SECRET_KEY=your-service-role-key
```

### Using Supabase CLI (Alternative)

```bash
supabase link --project-ref your-project-ref
supabase db push
```

### Verify Setup

1. Sign up a user → profile auto-created by trigger
2. POST to `/api/auth/register-tenant` → org + main branch + profile updated
3. Check RLS: anon can SELECT organizations; auth can SELECT own profile
