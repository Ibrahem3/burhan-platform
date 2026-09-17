-- ============================================================
-- BURHAN PLATFORM — Migration 00013
-- Align organization_assets bucket config with the app contract
--
-- Established contract (00005 + SUPABASE.md):
--   * max file size : 5 MB (5242880 bytes)
--   * allowed MIME  : image/jpeg, image/png, image/webp
--
-- GIF note: 00005 / SUPABASE.md list image/gif, but the application
-- never uploads a GIF. app/utils/compressImage.ts always transcodes
-- the selected file to image/webp before upload (all four callers in
-- app/pages/dashboard/{entities,series}/), so GIF never reaches the
-- bucket. This repair does not add a format the application cannot
-- produce; the effective contract excludes GIF.
--
-- Live drift corrected here:
--   * file_size_limit was 2097152 (2 MB) instead of 5242880 (5 MB)
--   * allowed_mime_types already matched the effective set (no GIF)
--
-- Additive + idempotent. Does not touch any other storage setting.
-- ============================================================

UPDATE storage.buckets
SET file_size_limit    = 5242880,
    allowed_mime_types = ARRAY['image/jpeg', 'image/png', 'image/webp']
WHERE id = 'organization_assets';
