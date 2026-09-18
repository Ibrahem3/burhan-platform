# بُرهان — Burhan Platform

<table align="left" style="border: 1px solid #e0e0e0; border-radius: 12px; padding: 16px; max-width: 500px; background: #ffffff;">
  <tr>
    <td>
      <img alt="GitHub" src="https://ph-files.imgix.net/dae462f6-9602-4dba-a3b6-4f7f89a78ab3.png?auto=compress,format&codec=mozjpeg&cs=strip&fit=crop&h=80&w=80" width="64" height="64" style="border-radius: 8px;">
    </td>
    <td style="padding-left: 12px; vertical-align: top;">
      <strong style="font-size: 18px; color: #1a1a1a;">GitHub</strong><br>
      <span style="font-size: 14px; color: #666666; line-height: 1.4;">Production-ready SaaS boilerplate to ship in hours.</span>
    </td>
  </tr>
  <tr>
    <td colspan="2" align="center" style="padding-top: 12px;">
      <a href="https://www.producthunt.com/products/github-442?embed=true&utm_source=embed&utm_medium=post_embed" target="_blank" rel="noopener">
        <img src="https://img.shields.io/badge/Check%20it%20out%20on-Product%20Hunt-FF6154?style=for-the-badge&logo=producthunt&logoColor=white" alt="Product Hunt">
      </a>
    </td>
  </tr>
</table>
<br clear="left" />



![Sovereignty](https://img.shields.io/badge/Sovereignty-Ethical_Asset-blueviolet?style=for-the-badge)
![Status](https://img.shields.io/badge/Status-Production_Ready-success?style=for-the-badge)
![License](https://img.shields.io/badge/License-Ethical_Islamic_License-gold?style=for-the-badge)
![Stack](https://img.shields.io/badge/Stack-Nuxt_4_%2B_Supabase_%2B_Tailwind-black?style=for-the-badge&logo=nuxtdotjs)

---

> [!IMPORTANT]
> ### 🛡️ Strategic & Ethical Architecture: A Sovereign Technical Waqf (وقف تقني)
> Burhan is engineered and dedicated as an **Ethical Technical Asset (وقف تقني)**—a production-grade, source-available platform built to advance digital sovereignty, resist centralized data monopolies, and plant enduring seeds of light across the open web (نشر بذور النور في الأرض).
> 
> By exposing this sovereign architecture, the objective is to empower independent thinkers, developers, and scholarly organizations with battle-tested infrastructure that eliminates months of development. Burhan is built for autonomous self-hosting, community-driven enhancements, and total intellectual resilience.
> 
> ⚡ **Current Phase — Decentralized AI Architecture:**
> We are actively extending Burhan's sovereign chassis to integrate decentralized, permissionless GPU inference. By shifting intelligence to open compute networks, Burhan eliminates reliance on centralized, surveillance-driven AI gatekeepers, bringing censorship-resistant, private writing pipelines directly to content creators.

---

### 1. The Manifesto: Tech Sovereignty in the Age of Censorship

In an era of centralized digital monopolies, arbitrary deplatforming, and opaque algorithmic filtering, independent thinkers and scholarly institutions face a systemic threat: **Digital Censorship (الاغتيال الرقمي)**. When platforms gatekeep reach and purge archives at will, depending on proprietary, centralized infrastructure is an existential risk.

Burhan is architected as an **Ethical & Sovereign Technical Asset (وقف تقني)**. It serves as an uncompromising, decentralized, and self-hosted alternative for media distribution, intellectual defense (الثغور الفكرية), and rigorous scholarly discourse. 

By guaranteeing organizations and creators absolute sovereign ownership over their databases, content delivery networks, and AI inference pipelines, Burhan ensures that truth remains uncensored, preserved, and universally accessible.
---

## 2. Core Architectural Features

Burhan is built from the ground up for high performance, multi-tenant isolation, and resilient content delivery:

### 2.1 Multi-Tenant Database Isolation
Burhan employs a robust multi-tenant model where multiple organizations share a single database, yet remain completely isolated:
*   **Database-level Isolation:** 100% data separation is enforced via PostgreSQL **Row-Level Security (RLS)** policies on all core tables.
*   **4-Tier RBAC Hierarchy:** System access is governed by roles:
    *   `super_admin`: Global bypass of RLS, manages the platform hub and cross-tenant services.
    *   `owner`: Full administrative privileges over a specific tenant organization (billing, deletion, content, managers).
    *   `manager`: Content creation and branch administration within the tenant organization.
    *   `member`: General authenticated users with read-only access to free content.

### 2.2 Digital Intellectual Observatory (المرصد الفكري)
A global, cross-tenant monitoring command center designed to track and refute digital misconceptions and threats:
*   **Public Report Intake:** A glowing, high-impact public form protected by **Cloudflare Turnstile** spam prevention, allowing users to report threat URLs with danger levels and spread matrices.
*   **Analyst Control Panel:** Observatory managers and analysts can triage incoming reports, assign scholars, and link scientific refutations (counter-measures). Neutralized threats are automatically published to the public defense feed.

### 2.3 Omni-Channel Content Engine
A unified CMS supporting multiple content categories and formats with native bilingual (Arabic/English) layout support:
*   **Articles:** Rich text writing via TiPTap v3 with native logical CSS properties supporting seamless RTL/LTR layout transitions.
*   **Video Streaming:** Resilient media player supporting YouTube embeddings alongside fallback stream sources (like Cloudflare Stream) to bypass censorship.
*   **Audio/Podcasts:** Complete support for podcasts and lectures, allowing self-hosted MP3 uploads or external stream links.

### 2.4 Premium Gate & Privacy-First Analytics
*   **Premium Gate:** Restricts exclusive courses or refutations behind a subscription barrier, bypassed automatically for tenant staff.
*   **Umami Integration:** Built-in tracking using self-hosted, privacy-first Umami Analytics to ensure analytics data is not harvested by advertising networks.

---

## 3. Project Structure

```
burhan/
├── app/                          # Nuxt 4 Frontend & App Shell
│   ├── app.vue                   # Root component & transitions
│   ├── assets/css/main.css       # Onyx/Gold global design system styles
│   ├── components/
│   │   ├── dashboard/            # RichTextEditor, FloatingSidebar, editor-toolbar
│   │   ├── hub/                  # EntityCard, CategorySection
│   │   ├── premium/              # PremiumGate
│   │   ├── tenant/               # OrgHeader, BranchNav, VideoPlayer
│   │   └── ui/                   # Button, Badge, GlassCard, AppSelect, Avatar
│   ├── composables/              # useUser, useOrg, useLocale, useEntities
│   ├── i18n/                     # Bilingual UI translations (ar.json, en.json)
│   ├── layouts/                  # default.vue (public), dashboard.vue (admin)
│   ├── middleware/               # dashboard-auth.ts, org.global.ts, observatory-auth.ts
│   ├── pages/                    # File-system routing (Hub, Tenant, Observatory, Dashboard)
│   ├── types/                    # Database TypeScript definitions
│   └── utils/                    # localized.ts, image.ts
├── server/                       # Nitro Server Engine (Cloudflare Pages compatible)
│   ├── api/                      # Server routes (auth, tenant registration, observatory)
│   └── utils/                    # supabase.ts (admin client factory)
├── supabase/                     # Supabase database config
│   ├── migrations/               # Chronological database patches (00001 - 00009)
│   └── schema.sql                # Unified database setup script (one-click setup)
├── public/                       # PWA icons and loaders
├── nuxt.config.ts                # Nuxt configuration
├── tailwind.config.ts            # Tailwind onyx/gold theme definition
└── package.json                  # Dependencies & scripts
```

---

## 4. Ethical Use License & Policy (سياسة الاستخدام الأخلاقي)

Burhan is open-source but carries strict ethical constraints. The source code and database schemas are provided as a sovereign technical asset (**وقف تقني**).

By cloning, deploying, or contributing to this project, you agree to the following restrictions:
*   You **shall not** deploy this software on platforms or for organizations that promote atheism or actively undermine Islamic values.
*   You **shall not** use this software to serve hostile entities, promote sectarian hatred, or distribute unethical/immoral media.
*   The creators and contributors of Burhan reserve the right to revoke permission to use this codebase if these terms are violated.

---

## 5. Getting Started

### 5.1 Prerequisites
*   Node.js 20+
*   A Supabase Project (URL + Anon Key + Service Role Key)
*   Cloudflare Turnstile Account (Optional, for Observatory spam protection)

### 5.2 Local Installation

1.  **Clone the repository and install dependencies:**
    ```bash
    git clone https://github.com/Ibrahem3/burhan-platform.git
    cd burhan-platform
    npm install
    ```

2.  **Configure environment variables:**
    ```bash
    cp .env.example .env
    ```
    Open `.env` and fill in your Supabase project endpoints and credentials:
    ```bash
    SUPABASE_URL=https://your-project.supabase.co
    SUPABASE_KEY=your-anon-public-key
    SUPABASE_SECRET_KEY=your-service-role-key
    # Optional Cloudflare Turnstile keys
    NUXT_PUBLIC_TURNSTILE_SITE_KEY=your-site-key
    NUXT_TURNSTILE_SECRET_KEY=your-secret-key
    ```

3.  **Setup Database Schemas:**
    *   Open your project in the **Supabase Dashboard**.
    *   Go to the **SQL Editor** tab.
    *   Open [`supabase/schema.sql`](./supabase/schema.sql) in your code editor, copy its entire contents, paste it into the Supabase SQL Editor, and click **Run**. This builds all tables, enums, triggers, security functions, RLS policies, and storage buckets in one click.

4.  **Run the local server:**
    ```bash
    npm run dev
    ```
    Your site will be available at `http://localhost:3000`.

---

## 6. Contribution Guide: Join the Intellectual Defense

The core backend architecture, multi-tenant security layers (RLS), API routing, database schema, and translation engines are fully optimized, solid, and **production-ready**.

However, the Frontend UI is currently in a functional state. We explicitly invite the open-source community to **fork, contribute, and enhance the UI/UX**.

### How to Contribute:
1.  Fork the repository.
2.  Create a feature branch (`git checkout -b feature/ui-enhancement`).
3.  Polish the UI components under [`app/components/`](./app/components) or pages under [`app/pages/`](./app/pages).
4.  Submit a Pull Request with a clear explanation of your visual improvements.

Let's build a sovereign and resilient infrastructure together!

💬 **Join our Discord Community:** [Join Ainux on Discord](https://discord.gg/mD9eQ7TX8S)
