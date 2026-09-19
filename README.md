# Burhan Platform — بُرهان

### Sovereign SaaS Chassis & Decentralized AI Publishing Workspace

[![Tech Stack](https://img.shields.io/badge/Stack-Nuxt%204%20%7C%20Supabase%20%7C%20Tailwind-0ea5e9.svg)](https://nuxt.com/)
[![Database Isolation](https://img.shields.io/badge/Security-100%25%20PostgreSQL%20RLS-success.svg)](https://www.postgresql.org/)
[![Compute](https://img.shields.io/badge/DeAI-Nosana%20Inference%20Cluster-emerald.svg)](https://nosana.io/)
[![License: AGPL v3](https://img.shields.io/badge/License-AGPL_v3-blue.svg)](https://www.gnu.org/licenses/agpl-3.0)

> **Strategic Architecture: A Sovereign Technical Waqf (وقف تقني)**  
> Burhan is architected and dedicated as an **Ethical Technical Asset (Technical Waqf)**—a production-grade, source-available chassis engineered to guarantee data sovereignty, resist digital deplatforming, and provide an immutable foundation for independent knowledge systems.  
>  
> Built for zero vendor lock-in, Burhan empowers developers, independent researchers, and scholarly institutions to deploy fully self-hosted, tenant-isolated knowledge hubs in minutes.

---
<img width="1255" height="868" alt="Screenshot_٢٠٢٦٠٩١٨_٢٣٣٤٤٩" src="https://github.com/user-attachments/assets/87c50192-c029-414e-9e2b-ba6a0c19f98a" />


## 1. The Manifesto: Tech Sovereignty in the Age of Censorship

In an era of centralized digital monopolies, arbitrary deplatforming, and opaque algorithmic filtering, independent thinkers and scholarly institutions face a systemic threat: **Digital Censorship (الاغتيال الرقمي)**. When platforms gatekeep reach and purge archives at will, depending on proprietary, centralized infrastructure is an existential risk.

Burhan is architected as an Ethical & Sovereign Technical Asset (وقف تقني). It serves as an uncompromising, decentralized, and self-hosted alternative for media distribution, intellectual preservation, and rigorous scholarly discourse. By guaranteeing organizations and creators absolute sovereign ownership over their databases, content delivery networks, and AI inference pipelines, Burhan ensures that truth remains uncensored, preserved, and universally accessible.

---

## 2. Core Architectural Features

Burhan is built from the ground up for high performance, multi-tenant isolation, and resilient content delivery:

### 2.1 Multi-Tenant Database Isolation
Burhan employs a robust multi-tenant model where multiple organizations share a single database, yet remain completely isolated:
- **Database-Level Isolation:** 100% data separation is enforced via native PostgreSQL Row-Level Security (RLS) policies on all core tables.
- **4-Tier RBAC Hierarchy:** System access is governed by granular roles:
  - `super_admin`: Global administrative scope, platform hub, and cross-tenant operations.
  - `owner`: Full administrative privileges over a specific tenant (billing, deletion, content, team).
  - `manager`: Content creation and branch administration within the tenant organization.
  - `member`: Authenticated users with read-only access to free content.

### 2.2 Decentralized Fact-Checking & Knowledge Observatory (المرصد المعرفي)
A global, cross-tenant monitoring command center engineered to document and counter digital disinformation, platform censorship, and coordinated smear campaigns:
- **Public Signal Ingestion:** High-impact reporting pipeline protected by Cloudflare Turnstile spam prevention, allowing users to submit threat vectors, manipulation sources, and URL archives.
- **Analyst Triage & Counter-Manuscripts:** Sovereign research teams triage reports, dispatch verified rebuttals, and link immutable scholarly evidence to the public defense feed.

### 2.3 Omni-Channel Content Engine
A unified CMS supporting multiple content categories and formats with native bilingual (Arabic/English) layout support:
- **Rich-Text Publishing:** Native logical CSS properties via TiPTap v3 supporting seamless RTL/LTR layout transitions.
- **Resilient Video Streaming:** Media player supporting video embeddings alongside fallback stream sources (like Cloudflare Stream) to bypass platform takedowns.
- **Audio & Podcasts:** Native support for lectures and long-form podcasts via self-hosted audio or external stream links.

### 2.4 Premium Gate & Privacy-First Analytics
- **Subscription Gate:** Restricts exclusive research or specialized publications behind configurable subscription barriers.
- **Zero-Surveillance Analytics:** Built-in tracking using self-hosted, privacy-first Umami Analytics ensuring behavioral data is not harvested by ad networks.

### 2.5 Decentralized AI Inference Engine (DeAI M1)
A sovereign, censorship-resistant AI writing assistant built on decentralized GPU compute:
- **Decentralized Cluster Inference:** Streamed OpenAI-compatible inference orchestrated via the Nosana compute cluster with bounded timeouts (~120s) and keep-alive heartbeats.
- **Transactional Quota Ledger:** Monthly token and request allowances (`ai_usage`) reserved at job creation, debited on completion, and safely released on failure or cancellation.
- **Fail-Safe Recovery Watchdog:** Lazy stale-job reaper and recovery sweep preventing orphan jobs and locked quotas during client or worker dropouts.
- **Dashboard Assistant Modal:** Native drafting assistant in the article editor supporting streaming preview and insertion modes (`insert`, `append`, `replace`).

### 2.6 Atomic Tenant Provisioning & Email OTP Gate
Bulletproof tenant onboarding ensuring zero orphaned states:
- **Atomic Provisioning Engine (`provision_tenant`):** Single-transaction RPC orchestrating organization creation, perpetual community plan subscription, canonical main branch, and profile ownership upgrade.
- **3-Step Signup State Machine:** Enforces email verification via 6-digit OTP (`auth.verifyOtp`) prior to provisioning, with 60-second resend cooldowns and fail-closed rollbacks.
- **Resilient Localization:** Built-in tolerance in frontend helpers handling both structured bilingual JSONB objects and plain string tenant names without runtime crashes.

### 2.7 Multi-Tenant Subscriptions & Entitlements
- **Tier Hierarchy:** Out-of-the-box perpetual Community tier and Pro tier with customizable feature flags (`custom_domain`, `advanced_analytics`, `ai_generate`).
- **Database-Level Enforcement:** PostgreSQL triggers (`check_branch_limit`) enforce plan quotas directly on `INSERT`, preventing API-level bypasses.
- **Graceful Degradation:** Expired or cancelled tenants transition smoothly into read-only mode, retaining public viewability while guarding content mutations.

### 2.8 BYOK (Bring Your Own Key) Cryptographic Subsystem
Empowers enterprise tenants to provide their own LLM API credentials with maximum security:
- **Authenticated Encryption:** Keys are encrypted using AES-256-GCM with unique per-record IVs and authenticated tags, isolated from client-side exposure.
- **SSRF Protection Layer:** Strict runtime inspection blocks private IPv4/IPv6 ranges, loopbacks, cloud metadata endpoints (`169.254.169.254`), and prevents DNS rebinding attacks.

---

## 3. Project Structure

```text
burhan/
├── app/                  # Nuxt 4 Frontend & App Shell
│   ├── app.vue           # Root component & transitions
│   ├── assets/css/main.css # Onyx/Gold global design system styles
│   ├── components/
│   │   ├── dashboard/    # RichTextEditor, EntityAiAssistantModal, FloatingSidebar
│   │   ├── hub/          # EntityCard, CategorySection
│   │   ├── premium/      # PremiumGate
│   │   ├── tenant/       # OrgHeader, BranchNav, VideoPlayer
│   │   └── ui/           # Button, Badge, GlassCard, AppSelect, Avatar
│   ├── composables/      # useAiGenerate, useSubscription, useTenantBootstrap, useUser, useOrg
│   ├── i18n/             # Bilingual UI translations (ar.json, en.json)
│   ├── layouts/          # default.vue (public), dashboard.vue (admin)
│   ├── middleware/       # dashboard-auth.ts, org.global.ts, observatory-auth.ts
│   ├── pages/            # File-system routing (Hub, Tenant, Observatory, Dashboard, Signup OTP)
│   ├── types/            # Database & Subscription TypeScript definitions
│   └── utils/            # localized.ts (crash-resilient), image.ts
├── server/               # Nitro Server Engine (Cloudflare Pages compatible)
│   ├── api/              # Server routes (ai, auth, org, observatory, admin)
│   └── utils/            # nosana.ts, crypto.ts (AES-256-GCM), ssrf.ts, entitlements.ts, supabase.ts
├── supabase/             # Supabase database config
│   ├── migrations/       # Chronological database patches (00001 - 00021)
│   └── schema.sql        # Unified canonical database setup script (00001 - 00021 in one click)
├── public/               # PWA icons and loaders
├── nuxt.config.ts        # Nuxt configuration
├── tailwind.config.ts    # Tailwind onyx/gold theme definition
└── package.json          # Dependencies & scripts
```

---

## 4. Licensing & Sovereign Open-Source Covenant

Burhan is licensed under the **GNU Affero General Public License v3.0 (AGPL-3.0)**.

### Why AGPL-3.0?
- **Anti-SaaS Loophole:** We reject corporate freeloading. Any entity or organization that hosts, modifies, or runs Burhan as a network service (SaaS) is legally required to make their entire source code and modifications publicly available under the exact same AGPL-3.0 license.
- **Preservation of the Digital Commons:** This architecture is a sovereign technical public good. It cannot be privatized, closed-sourced, or converted into a proprietary cloud monopoly.
- **Sovereign Reciprocity:** If you build on Burhan, your improvements belong to the community and your end-users.

For full legal terms, refer to the [LICENSE](./LICENSE) file.

---

## 5. Getting Started

### 5.1 Prerequisites
- Node.js 20+
- A Supabase Project (URL, Anon Key, and Service Role Key)
- Nosana Inference Cluster Credentials (for Decentralized AI features)
- Cloudflare Turnstile Account (Optional, for Observatory form protection)

### 5.2 Local Installation

1. **Clone the repository and install dependencies:**
   ```bash
   git clone https://github.com/Ibrahem3/burhan-platform.git
   cd burhan-platform
   npm install
   ```

2. **Configure environment variables:**
   ```bash
   cp .env.example .env
   ```

   Populate your `.env` with the necessary keys:
   ```env
   # Supabase Connection Settings
   SUPABASE_URL=https://your-project.supabase.co
   SUPABASE_KEY=your-anon-public-key
   SUPABASE_SECRET_KEY=your-service-role-key

   # Platform Settings
   NUXT_PUBLIC_SITE_URL=http://localhost:3000
   NUXT_PUBLIC_SITE_NAME=Burhan

   # Cloudflare Turnstile (Optional)
   NUXT_PUBLIC_TURNSTILE_SITE_KEY=your-site-key
   NUXT_TURNSTILE_SECRET_KEY=your-secret-key

   # Decentralized AI Inference (Nosana Cluster)
   NUXT_NOSANA_API_ENDPOINT=https://api.nosana.io/v1
   NUXT_NOSANA_CLUSTER_KEY=your-nosana-cluster-key
   NUXT_NOSANA_DEFAULT_MODEL=deepseek-ai/DeepSeek-R1-Distill-Llama-70B

   # BYOK Master Encryption Key (64-character hex string for AES-256-GCM)
   BYOK_ENCRYPTION_KEY=your-64-char-hex-encryption-key
   ```

3. **Setup Database Schemas:**
   - Open your project in the Supabase Dashboard.
   - Navigate to the **SQL Editor**.
   - Copy the contents of `supabase/schema.sql` and run the script. This provisions all tables, enums, triggers, security policies (RLS), and functions in a single transaction.

4. **Start Development Server:**
   ```bash
   npm run dev
   ```
   Access the workspace at `http://localhost:3000`.

---

## 6. Contribution & Community

The core backend architecture, multi-tenant security layers (RLS), API routing, and translation engines are fully optimized and production-ready.

We actively welcome contributions to expand the front-end design system, add new decentralized compute adapters, and enhance analytics modules.

- Found a bug or have a suggestion? Open an issue or submit a Pull Request.
- Join the community: Connect with the ecosystem on [Ainux Discord](https://discord.gg/ainux).
