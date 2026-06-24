# بُرهان — Burhan Platform

Multi-tenant intellectual refutations platform for scholarly dialogues and media archive.

## Features

- **Hub platform** — browse all organizations
- **Tenant pages** — per-org sites with branches, content, and series
- **Rich text editor** — Tiptap v3 with formatting, links, RTL support
- **Multi-lingual** — Arabic (default) and English with RTL/LTR
- **Premium gate** — subscriber-only content with role-based access
- **Dashboard** — overview, branches, entities, series management
- **Floating sidebar** — hover-to-expand desktop nav with mobile overlay
- **Video player** — YouTube + fallback source support
- **Audio content** — audio content type for podcasts/lectures
- **Digital Observatory** — cross-tenant threat reporting, Turnstile spam protection, and analyst review command center
- **PWA** — offline caching, service worker, standalone install
- **Analytics** — Umami self-hosted analytics
- **Legal pages** — About, Privacy, Terms, Contact

---

## Tech Stack

| Layer | Tech |
|---|---|
| Framework | Nuxt 4 + Vue 3 |
| Language | TypeScript |
| Styling | Tailwind CSS (onyx/gold dark theme) |
| Rich text | Tiptap v3 (StarterKit, Link, Underline, TextAlign, Placeholder) |
| PWA | @vite-pwa/nuxt + Workbox |
| i18n | @nuxtjs/i18n (prefix_except_default) |
| Backend | Nitro server (Cloudflare Pages preset) |
| Database | Supabase (Postgres + auth + storage) |
| Auth | Supabase PKCE flow |

---

## Project Structure

```
burhan/
├── app/                          # Nuxt application
│   ├── app.vue                   # App shell, head, splash screen
│   ├── assets/css/main.css       # Global styles + prose-gold typography
│   ├── components/
│   │   ├── dashboard/            # RichTextEditor, FloatingSidebar, editor-toolbar
│   │   ├── hub/                  # EntityCard, CategorySection
│   │   ├── premium/              # PremiumGate
│   │   ├── tenant/               # OrgHeader, BranchNav, VideoPlayer
│   │   └── ui/                   # Button, Badge, GlassCard, AppSelect, Avatar, SplashScreen
│   ├── composables/              # useUser, useOrg, useLocale, useScrollAware, useEntities
│   ├── i18n/                     # ar.json, en.json
│   ├── layouts/                  # default.vue (public), dashboard.vue
│   ├── middleware/               # dashboard-auth.ts, org.global.ts
│   ├── pages/                    # All routes (see below)
│   ├── types/                    # database.ts (Supabase types)
│   └── utils/                    # localized.ts
├── server/                       # Nitro backend
│   ├── api/
│   │   ├── auth/register-tenant.post.ts
│   │   ├── entities/public.ts
│   │   ├── orgs/index.ts
│   │   └── orgs/[slug].ts
│   └── utils/                    # supabase.ts (admin client)
├── supabase/
│   ├── migrations/               # 00001 – 00009
│   └── schema.sql                # Unified database setup script
├── public/                       # Static assets (favicon, loader, PWA icons)
├── nuxt.config.ts
├── tailwind.config.ts
└── package.json
```

---

## Pages

| Route | Description |
|---|---|
| `/` | Hub — organization listing |
| `/[org_slug]` | Org tenant home |
| `/[org_slug]/branches/[branch_id]` | Branch content listing |
| `/[org_slug]/content/[id]` | Article / content page |
| `/[org_slug]/series/[id]` | Series page |
| `/login` | Login |
| `/signup` | Registration + org creation |
| `/dashboard` | Overview stats |
| `/dashboard/branches` | Branch management |
| `/dashboard/entities` | Entity management (list, edit, new) |
| `/dashboard/series` | Series management (list, edit, new) |
| `/about` | About the platform |
| `/privacy` | Privacy policy |
| `/terms` | Terms & conditions |
| `/contact` | Contact form |

---

## Database Migrations

| Migration | Description |
|---|---|
| `00001` | Initial schema — orgs, branches, entities, profiles, series, triggers |
| `00002` | Fix branches RLS policies |
| `00003` | Fix profiles RLS recursion |
| `00004` | Add branch slug + is_active |
| `00005` | Storage bucket policies for media assets |
| `00006` | Series and playlists tables |
| `00007` | Add audio content type |
| `00008` | Security lint fixes — revoke public/anon EXECUTE |
| `00009` | Observatory module — threats, analysts, triggers, and RLS policies |

### Roles

- `member` — basic access to org public content
- `owner` — full org management
- `manager` — content management (no billing/delete)
- `super_admin` — bypass all RLS, cross-org access

---

## Getting Started

### Prerequisites

- Node.js 20+
- Supabase project (URL + anon key + service role key)
- Cloudflare account (for deployment)

### Local Development

1. **Install dependencies:**
   ```bash
   npm install
   ```

2. **Configure environment variables:**
   ```bash
   cp .env.example .env
   ```
   Open the generated `.env` file and fill in `SUPABASE_URL`, `SUPABASE_KEY`, and `SUPABASE_SECRET_KEY`. Optionally add Turnstile site keys for the Observatory module.

3. **Initialize the database:**
   Go to the **SQL Editor** in your Supabase project dashboard, copy the entire contents of the unified setup script [`supabase/schema.sql`](file:///mnt/Data/burhan/supabase/schema.sql), paste it, and click **Run**. This will build the tables, enums, triggers, and RLS policies.

4. **Start the development server:**
   ```bash
   npm run dev
   ```

### Deploy to Cloudflare Pages

```bash
npm run build
npx wrangler pages deploy dist
```

---

## Environment Variables

| Variable | Required | Description |
|---|---|---|
| `SUPABASE_URL` | Yes | Supabase project URL |
| `SUPABASE_KEY` | Yes | Supabase anon/public key |
| `SUPABASE_SECRET_KEY` | Yes | Service role key (admin operations) |
| `NUXT_PUBLIC_SITE_URL` | No | Canonical base URL for production (defaults to localhost:3000) |
| `NUXT_PUBLIC_SITE_NAME` | No | Site name for SEO (defaults to Burhan) |
| `NUXT_PUBLIC_TURNSTILE_SITE_KEY` | No | Cloudflare Turnstile public site key for Digital Observatory |
| `NUXT_TURNSTILE_SECRET_KEY` | No | Cloudflare Turnstile secret key for Digital Observatory verification |

---

## PWA

- Powered by `@vite-pwa/nuxt`
- Workbox caches static assets (JS, CSS, images, fonts) only
- Navigation is **not** handled by the service worker (SSR via Cloudflare Worker)
- Auto-update on new deploy
- 192×192 and 512×512 icons with standalone display

---

## Key Conventions

- **Toolbar buttons** use `@mousedown.prevent` (not `@click`) to preserve editor focus
- **Tiptap commands** use `editor.chain().focus()...run()` 
- **Custom `AppSelect`** replaces native `<select>` on mobile to prevent viewport clipping
- **Scroll-aware** composable (`useScrollAware`) hides floating bars on scroll-down
- **Localized fields** use `localizedValue()` utility (handles JSONB objects)
- **Service role** operations happen in `server/` only, using `getSupabaseAdmin()`
- **CSS logical properties** (`border-inline-start`, `padding-inline-start`) for RTL-aware styling

---

## License

All rights reserved.
