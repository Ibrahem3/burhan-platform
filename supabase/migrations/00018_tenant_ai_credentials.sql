-- ============================================================
-- BURHAN PLATFORM — Migration 00018
-- Tenant AI Credentials / Bring Your Own Key (BYOK)
--
-- Architecture:
--   Organization -> Tenant AI Credentials (Encrypted at Rest) -> OpenAI-compatible Provider
--
-- Principles:
--   1. Plaintext Lifetime Invariant: Plaintext API keys exist only in Nitro server
--      memory for the minimum execution window required to make the provider HTTP request.
--   2. Encrypted-at-Rest: Table stores only AES-256-GCM ciphertext, 12-byte IV,
--      16-byte auth tag, key version, and masked suffix. No plaintext secrets in DB/WAL.
--   3. Absolute Client Revocation: Direct PostgREST access is revoked from anon and
--      authenticated roles. Credential management is strictly server-side (service_role)
--      through owner-authorized Nitro endpoints.
--   4. M1 DeAI Backend Contract: M1 job lifecycle, RPCs, and quota accounting
--      remain 100% locked and untouched.
-- ============================================================

-- 1. TENANT AI CREDENTIALS TABLE
-- ============================================================
CREATE TABLE IF NOT EXISTS public.tenant_ai_credentials (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id  UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  provider         TEXT NOT NULL CHECK (provider IN ('openai', 'nosana', 'openrouter', 'custom')),
  encrypted_key    TEXT NOT NULL,
  key_iv           TEXT NOT NULL,
  key_tag          TEXT NOT NULL,
  key_suffix       TEXT NOT NULL,
  key_version      INTEGER NOT NULL DEFAULT 1,
  base_url         TEXT,
  custom_model     TEXT,
  is_active        BOOLEAN NOT NULL DEFAULT true,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT uq_tenant_ai_credentials_org_provider UNIQUE (organization_id, provider)
);

COMMENT ON TABLE public.tenant_ai_credentials IS
  'Encrypted tenant-owned AI provider credentials for Bring Your Own Key (BYOK). Service-role only.';
COMMENT ON COLUMN public.tenant_ai_credentials.encrypted_key IS
  'AES-256-GCM ciphertext in hex format. Plaintext never persisted.';
COMMENT ON COLUMN public.tenant_ai_credentials.key_iv IS
  'Cryptographically random 12-byte initialization vector in hex format. Never reused.';
COMMENT ON COLUMN public.tenant_ai_credentials.key_tag IS
  '16-byte GCM authentication tag in hex format verifying integrity.';
COMMENT ON COLUMN public.tenant_ai_credentials.key_version IS
  'Master encryption key version for future key rotation.';
COMMENT ON COLUMN public.tenant_ai_credentials.key_suffix IS
  'Display-only key tail (last 4 chars) for user UI identification.';
COMMENT ON COLUMN public.tenant_ai_credentials.base_url IS
  'Optional custom OpenAI-compatible endpoint URL. Subject to strict SSRF validation.';

-- 2. INDEXES
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_tenant_ai_credentials_org
  ON public.tenant_ai_credentials (organization_id);

CREATE INDEX IF NOT EXISTS idx_tenant_ai_credentials_lookup
  ON public.tenant_ai_credentials (organization_id, provider)
  WHERE is_active = true;

-- 3. ROW LEVEL SECURITY & PRIVILEGES
-- ============================================================
ALTER TABLE public.tenant_ai_credentials ENABLE ROW LEVEL SECURITY;

-- Deny all client-side PostgREST operations unconditionally
REVOKE ALL ON public.tenant_ai_credentials FROM PUBLIC;
REVOKE ALL ON public.tenant_ai_credentials FROM anon;
REVOKE ALL ON public.tenant_ai_credentials FROM authenticated;

-- Grant execution/access strictly to the service_role for Nitro server endpoints
GRANT ALL ON public.tenant_ai_credentials TO service_role;
