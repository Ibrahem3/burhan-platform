-- ============================================================
-- BURHAN PLATFORM — Migration 00007
-- Add content_type, audio_url, audio_file to entities
-- ============================================================

-- 1. Add content_type to entities (video / article / audio)
ALTER TABLE entities
  ADD COLUMN IF NOT EXISTS content_type TEXT NOT NULL DEFAULT 'article';

-- 2. Add audio fields for podcast/audio content
ALTER TABLE entities
  ADD COLUMN IF NOT EXISTS audio_url  TEXT,
  ADD COLUMN IF NOT EXISTS audio_file TEXT;

-- 3. Update the type check constraint to include audio
--    (if a CHECK constraint already exists, skip or drop first)
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conrelid = 'entities'::regclass
    AND conname = 'entities_content_type_check'
  ) THEN
    ALTER TABLE entities DROP CONSTRAINT entities_content_type_check;
  END IF;
END $$;

ALTER TABLE entities
  ADD CONSTRAINT entities_content_type_check
  CHECK (content_type IN ('video', 'article', 'audio'));

-- 4. Comments
COMMENT ON COLUMN entities.content_type IS 'Content classification: video, article, or audio';
COMMENT ON COLUMN entities.audio_url     IS 'External streaming URL (SoundCloud, Spotify, etc.)';
COMMENT ON COLUMN entities.audio_file    IS 'Path to self-hosted .mp3 in organization_assets bucket';
