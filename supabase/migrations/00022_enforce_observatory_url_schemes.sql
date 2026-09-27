-- ============================================================
-- BURHAN PLATFORM — Migration 00022
-- Enforce Strict URL Scheme Constraints at Database Layer
--
-- Objective:
--   Mitigate stored XSS (such as javascript:, data:, vbscript: URIs)
--   at the PostgreSQL schema level.
--   Enforces that source_url and response_url must be valid HTTP or HTTPS URLs.
-- ============================================================

-- 1. Enforce http/https on observatory_threats.source_url and response_url
ALTER TABLE public.observatory_threats
  DROP CONSTRAINT IF EXISTS check_observatory_threats_source_url,
  ADD CONSTRAINT check_observatory_threats_source_url
    CHECK (source_url ~* '^https?://');

ALTER TABLE public.observatory_threats
  DROP CONSTRAINT IF EXISTS check_observatory_threats_response_url,
  ADD CONSTRAINT check_observatory_threats_response_url
    CHECK (response_url IS NULL OR response_url = '' OR response_url ~* '^https?://');

-- 2. Enforce http/https on entities.audio_url and fallback_url if provided
ALTER TABLE public.entities
  DROP CONSTRAINT IF EXISTS check_entities_audio_url,
  ADD CONSTRAINT check_entities_audio_url
    CHECK (audio_url IS NULL OR audio_url = '' OR audio_url ~* '^https?://');

ALTER TABLE public.entities
  DROP CONSTRAINT IF EXISTS check_entities_fallback_url,
  ADD CONSTRAINT check_entities_fallback_url
    CHECK (fallback_url IS NULL OR fallback_url = '' OR fallback_url ~* '^https?://');

COMMENT ON CONSTRAINT check_observatory_threats_source_url ON public.observatory_threats IS 'Enforce http/https scheme on threat source URLs';
COMMENT ON CONSTRAINT check_observatory_threats_response_url ON public.observatory_threats IS 'Enforce http/https scheme on countermeasure response URLs';
COMMENT ON CONSTRAINT check_entities_audio_url ON public.entities IS 'Enforce http/https scheme on audio URLs';
COMMENT ON CONSTRAINT check_entities_fallback_url ON public.entities IS 'Enforce http/https scheme on fallback URLs';
