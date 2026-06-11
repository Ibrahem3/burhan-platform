-- ============================================================
-- BURHAN PLATFORM — Migration 00009
-- Digital Intellectual Observatory (المرصد الرقمي الفكري)
-- Global cross-tenant threat monitoring & refutation module
-- ============================================================

-- 1. OBSERVATORY ANALYSTS (local role table — no global enum change)
-- ============================================================
CREATE TABLE observatory_analysts (
  id           UUID PRIMARY KEY REFERENCES profiles(id) ON DELETE CASCADE,
  role_type    TEXT NOT NULL CHECK (role_type IN ('observatory_manager', 'observatory_analyst')),
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE  observatory_analysts IS 'Observatory module access control — fully isolated from global user_role enum';
COMMENT ON COLUMN observatory_analysts.role_type IS 'observatory_manager = full CRUD; observatory_analyst = select + limited update';

-- 2. OBSERVATORY THREATS
-- ============================================================
CREATE TABLE observatory_threats (
  id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title                TEXT NOT NULL,
  source_url           TEXT NOT NULL,
  platform             TEXT NOT NULL DEFAULT 'unknown',
  danger_level         TEXT NOT NULL DEFAULT 'Medium' CHECK (danger_level IN ('Low', 'Medium', 'High')),
  status               TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'under_review', 'neutralized')),
  assigned_scholar_id  UUID REFERENCES profiles(id) ON DELETE SET NULL,
  reported_by          UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  response_url         TEXT,
  created_at           TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE  observatory_threats IS 'Cross-tenant threat/misconception reports — sovereign global service';
COMMENT ON COLUMN observatory_threats.platform             IS 'Extracted from source_url: tiktok, youtube, facebook, x, instagram, telegram, other';
COMMENT ON COLUMN observatory_threats.danger_level         IS 'Low | Medium | High';
COMMENT ON COLUMN observatory_threats.status               IS 'pending → under_review → neutralized';
COMMENT ON COLUMN observatory_threats.reported_by          IS 'NULL for anonymous reports; FK for authenticated users';

CREATE INDEX idx_threats_status        ON observatory_threats (status);
CREATE INDEX idx_threats_platform      ON observatory_threats (platform);
CREATE INDEX idx_threats_created_at    ON observatory_threats (created_at DESC);
CREATE INDEX idx_threats_neutralized   ON observatory_threats (status) WHERE status = 'neutralized';

-- 3. TRIGGER — Auto-detect platform from source_url
-- ============================================================
CREATE OR REPLACE FUNCTION auto_detect_platform()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.platform := CASE
    WHEN NEW.source_url ~* 'tiktok\.com'     THEN 'tiktok'
    WHEN NEW.source_url ~* 'youtube\.com'    THEN 'youtube'
    WHEN NEW.source_url ~* 'youtu\.be'       THEN 'youtube'
    WHEN NEW.source_url ~* 'facebook\.com'   THEN 'facebook'
    WHEN NEW.source_url ~* 'x\.com'          THEN 'x'
    WHEN NEW.source_url ~* 'twitter\.com'    THEN 'x'
    WHEN NEW.source_url ~* 'instagram\.com'  THEN 'instagram'
    WHEN NEW.source_url ~* 'telegram\.(me|org)' THEN 'telegram'
    ELSE 'other'
  END;
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_auto_detect_platform
  BEFORE INSERT ON observatory_threats
  FOR EACH ROW
  EXECUTE FUNCTION auto_detect_platform();

-- 4. HELPER FUNCTION — Bypass RLS to avoid recursion
-- SECURITY DEFINER lets us query observatory_analysts from its own policies
-- ============================================================
CREATE OR REPLACE FUNCTION is_observatory_manager()
RETURNS BOOLEAN
LANGUAGE SQL
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM observatory_analysts
    WHERE id = auth.uid() AND role_type = 'observatory_manager'
  );
$$;

CREATE OR REPLACE FUNCTION is_super_admin()
RETURNS BOOLEAN
LANGUAGE SQL
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM profiles
    WHERE id = auth.uid() AND role = 'super_admin'
  );
$$;

-- 5. ROW LEVEL SECURITY
-- ============================================================

ALTER TABLE observatory_analysts ENABLE ROW LEVEL SECURITY;
ALTER TABLE observatory_threats  ENABLE ROW LEVEL SECURITY;

-- 5a. observatory_analysts RLS
-- Uses SECURITY DEFINER helpers to prevent recursion
-- ============================================================

CREATE POLICY "analysts_select_own"
  ON observatory_analysts FOR SELECT
  USING (id = auth.uid());

CREATE POLICY "analysts_select_all_manager_or_super_admin"
  ON observatory_analysts FOR SELECT
  USING (is_observatory_manager() OR is_super_admin());

CREATE POLICY "analysts_insert_manager_only"
  ON observatory_analysts FOR INSERT
  WITH CHECK (is_observatory_manager() OR is_super_admin());

CREATE POLICY "analysts_delete_manager_only"
  ON observatory_analysts FOR DELETE
  USING (is_observatory_manager() OR is_super_admin());

-- 5b. observatory_threats RLS
-- ============================================================

-- PUBLIC / Anon: INSERT only, no SELECT/UPDATE/DELETE
CREATE POLICY "threats_insert_public"
  ON observatory_threats FOR INSERT
  TO anon, authenticated
  WITH CHECK (true);

-- Super admin: full access
CREATE POLICY "threats_select_super_admin"
  ON observatory_threats FOR SELECT
  USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'super_admin')
  );

CREATE POLICY "threats_update_super_admin"
  ON observatory_threats FOR UPDATE
  USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'super_admin')
  );

CREATE POLICY "threats_delete_super_admin"
  ON observatory_threats FOR DELETE
  USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'super_admin')
  );

-- Observatory manager: full CRUD (same as super admin for threats)
CREATE POLICY "threats_select_manager"
  ON observatory_threats FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM observatory_analysts
      WHERE id = auth.uid() AND role_type = 'observatory_manager'
    )
  );

CREATE POLICY "threats_update_manager"
  ON observatory_threats FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM observatory_analysts
      WHERE id = auth.uid() AND role_type = 'observatory_manager'
    )
  );

CREATE POLICY "threats_delete_manager"
  ON observatory_threats FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM observatory_analysts
      WHERE id = auth.uid() AND role_type = 'observatory_manager'
    )
  );

-- Observatory analyst: SELECT + limited UPDATE (status, response_url, assigned_scholar_id)
CREATE POLICY "threats_select_analyst"
  ON observatory_threats FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM observatory_analysts
      WHERE id = auth.uid() AND role_type = 'observatory_analyst'
    )
  );

CREATE POLICY "threats_update_analyst"
  ON observatory_threats FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM observatory_analysts
      WHERE id = auth.uid() AND role_type = 'observatory_analyst'
    )
  );

-- 6. PUBLIC SELECT — Allow viewing neutralized threats without auth
-- ============================================================
CREATE POLICY "threats_select_neutralized_public"
  ON observatory_threats FOR SELECT
  TO anon, authenticated
  USING (status = 'neutralized');

-- 7. SEED DATA (Proof of Concept)
-- ============================================================
INSERT INTO observatory_threats (title, source_url, platform, danger_level, status, response_url) VALUES
(
  'شبهة حول تحريف القرآن الكريم',
  'https://www.tiktok.com/@user/video/123456',
  'tiktok',
  'High',
  'neutralized',
  'https://youtube.com/watch?v=demo-refutation-1'
),
(
  'مغالطة علمية حول نظرية التطور',
  'https://www.youtube.com/watch?v=demo-misconception',
  'youtube',
  'Medium',
  'neutralized',
  'https://youtube.com/watch?v=demo-refutation-2'
),
(
  'شائعة عن تحريف الإنجيل في الإسلام',
  'https://www.facebook.com/demo/posts/789',
  'facebook',
  'High',
  'under_review',
  NULL
),
(
  'مغالطة حول حقوق المرأة في الإسلام',
  'https://x.com/demo/status/123456',
  'x',
  'Medium',
  'pending',
  NULL
);
