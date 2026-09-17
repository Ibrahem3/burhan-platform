-- ============================================================
-- BURHAN PLATFORM — Migration 00014
-- Restore entities.content_type CHECK constraint
--
-- 00007 declared:
--   CHECK (content_type IN ('video', 'article', 'audio'))
-- but the live database does not enforce it (invalid values such as
-- 'bogus' were accepted during M1.6). This restores the exact
-- repository contract without redesigning the content model.
--
-- Additive + idempotent. No valid values are changed.
-- ============================================================

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conrelid = 'public.entities'::regclass
      AND conname  = 'entities_content_type_check'
  ) THEN
    ALTER TABLE public.entities
      ADD CONSTRAINT entities_content_type_check
      CHECK (content_type IN ('video', 'article', 'audio'));
  END IF;
END $$;
