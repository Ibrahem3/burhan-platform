-- ============================================================
-- BURHAN PLATFORM — Migration 00005
-- Create organization_assets storage bucket + RLS policies
-- ============================================================

-- 1. Create the bucket (id = name = 'organization_assets')
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'organization_assets',
  'organization_assets',
  true,
  5242880, -- 5 MB
  ARRAY['image/jpeg', 'image/png', 'image/gif', 'image/webp']
)
ON CONFLICT (id) DO NOTHING;

-- 2. Drop any conflicting default policies that Supabase auto-creates
DROP POLICY IF EXISTS "Give users access to own folder 1pkutm_0" ON storage.objects;
DROP POLICY IF EXISTS "Give users access to own folder 1pkutm_1" ON storage.objects;
DROP POLICY IF EXISTS "Give users access to own folder 1pkutm_2" ON storage.objects;
DROP POLICY IF EXISTS "Give users access to own folder 1pkutm_3" ON storage.objects;

-- 3. Allow authenticated users to upload into the bucket
CREATE POLICY "org_assets_insert"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (bucket_id = 'organization_assets');

-- 4. Allow public read (bucket is public)
CREATE POLICY "org_assets_select"
ON storage.objects FOR SELECT TO public
USING (bucket_id = 'organization_assets');

-- 5. Allow authenticated users to update files
CREATE POLICY "org_assets_update"
ON storage.objects FOR UPDATE TO authenticated
USING (bucket_id = 'organization_assets')
WITH CHECK (bucket_id = 'organization_assets');

-- 6. Allow authenticated users to delete files
CREATE POLICY "org_assets_delete"
ON storage.objects FOR DELETE TO authenticated
USING (bucket_id = 'organization_assets');
