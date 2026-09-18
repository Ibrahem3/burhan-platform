-- ============================================================
-- BURHAN PLATFORM — Migration 00010
-- Hardened DeAI Backend: AI jobs, quota accounting, terminal
-- state machine, watchdog, atomic reconciliation.
--
-- Design summary (see map2.md directive sections 3-21):
--  * Membership authorization uses profiles.id + profiles.organization_id + profiles.role.
--    NO "organization_members" table exists anywhere. Never invent it.
--  * All RPCs accept an explicit p_user_id (service-role path). They never
--    depend on auth.uid() being populated. The Nitro server passes the
--    verified user id (browser JWT -> Nitro auth -> RPC).
--  * reserve_ai_quota / create_ai_job use SELECT ... FOR UPDATE (row lock)
--    + conditional UPDATE so two concurrent reservations cannot oversubscribe.
--  * Terminal transitions (complete/fail/cancel/reap) are ATOMIC with quota
--    reconciliation: the conditional status transition (WHERE status=...) and
--    the ai_usage delta happen in ONE transaction. quota_reconciled guards
--    idempotency; a recovery sweep reconciles any terminal job left
--    unreconciled exactly once (crash-window invariant).
--  * Reconciliation always targets the job's original period_month — never
--    CURRENT_DATE at reconcile time.
--  * Per the 00008 convention: REVOKE EXECUTE FROM public/anon/authenticated
--    and GRANT EXECUTE only to service_role. The browser cannot mutate jobs;
--    the client is limited to a SELECT-own RLS policy.
--  * Quota semantics: requests are consumed at admission (never refunded);
--    tokens are estimated-reserved at admission and reconciled at terminal:
--      completed => tokens_used += actual; tokens_reserved -= estimated (net actual)
--      failed/cancelled => tokens_reserved -= estimated (release 0 - E)
-- ============================================================

-- ============================================================
-- 1. TABLES
-- ============================================================

CREATE TABLE IF NOT EXISTS ai_jobs (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id           UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  organization_id   UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  branch_id         UUID REFERENCES branches(id) ON DELETE SET NULL,
  prompt            TEXT NOT NULL,
  system_prompt     TEXT,
  language          TEXT NOT NULL DEFAULT 'ar',
  model             TEXT,
  status            TEXT NOT NULL DEFAULT 'pending'
                    CHECK (status IN ('pending', 'processing', 'completed', 'failed', 'cancelled')),
  output_buffer     TEXT NOT NULL DEFAULT '',
  output_final      TEXT,
  error             TEXT,
  tokens_estimated  INTEGER NOT NULL DEFAULT 0 CHECK (tokens_estimated >= 0),
  tokens_used       INTEGER CHECK (tokens_used >= 0),
  period_month      TEXT NOT NULL CHECK (period_month ~ '^[0-9]{4}-[0-9]{2}$'),
  quota_reconciled  BOOLEAN NOT NULL DEFAULT FALSE,
  consumed          BOOLEAN NOT NULL DEFAULT FALSE,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  last_heartbeat_at TIMESTAMPTZ
);

COMMENT ON TABLE  ai_jobs IS 'Server-only AI inference job lifecycle. Client may only SELECT own rows.';
COMMENT ON COLUMN ai_jobs.status IS 'pending -> processing -> {completed|failed|cancelled}; terminal states are immutable.';
COMMENT ON COLUMN ai_jobs.period_month IS 'Immutable original quota period (YYYY-MM); reconciliation uses this, never CURRENT_DATE.';
COMMENT ON COLUMN ai_jobs.quota_reconciled IS 'Idempotency guard: exactly one successful reconciliation per terminal job.';
COMMENT ON COLUMN ai_jobs.last_heartbeat_at IS 'Worker liveness field for the watchdog (kept separate from updated_at).';

CREATE INDEX IF NOT EXISTS idx_ai_jobs_organization_id ON ai_jobs (organization_id);
CREATE INDEX IF NOT EXISTS idx_ai_jobs_user_id         ON ai_jobs (user_id);
CREATE INDEX IF NOT EXISTS idx_ai_jobs_status          ON ai_jobs (status);
CREATE INDEX IF NOT EXISTS idx_ai_jobs_stale
  ON ai_jobs (status, last_heartbeat_at)
  WHERE status IN ('pending', 'processing');

CREATE TABLE IF NOT EXISTS ai_usage (
  organization_id   UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  period_month      TEXT NOT NULL CHECK (period_month ~ '^[0-9]{4}-[0-9]{2}$'),
  requests_used     INTEGER NOT NULL DEFAULT 0 CHECK (requests_used >= 0),
  tokens_reserved   INTEGER NOT NULL DEFAULT 0 CHECK (tokens_reserved >= 0),
  tokens_used       INTEGER NOT NULL DEFAULT 0 CHECK (tokens_used >= 0),
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (organization_id, period_month)
);

COMMENT ON TABLE  ai_usage IS 'Organization/month AI quota accounting. UNIQUE(organization_id, period_month) enforced via PK.';
COMMENT ON COLUMN ai_usage.requests_used   IS 'Admitted requests. Consumed at admission/reservation; never refunded on inference failure/cancellation.';
COMMENT ON COLUMN ai_usage.tokens_reserved IS 'Estimated tokens reserved for in-flight/pending jobs. Released on terminal transition.';
COMMENT ON COLUMN ai_usage.tokens_used     IS 'Final billable tokens for terminal jobs (actual on success, 0 on failure/cancellation).';

-- ============================================================
-- 2. HELPERS (SECURITY DEFINER, narrow responsibility)
-- ============================================================

-- Super-admin check over an explicit user id (service-role path).
CREATE OR REPLACE FUNCTION public.ai_is_super_admin(p_user_id UUID)
RETURNS BOOLEAN
LANGUAGE SQL
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM profiles WHERE id = p_user_id AND role = 'super_admin'
  );
$$;

-- Internal: validate membership and perform the ATOMIC estimated-token
-- reservation for (organization, current period) under a row lock.
-- Raises:
--   ai_unauthorized            user unknown or not a member of p_org_id
--   ai_invalid_estimate        negative/zero estimate
--   ai_quota_exceeded          request or token limit would be breached
CREATE OR REPLACE FUNCTION public.ai_reserve_usage(
  p_user_id          UUID,
  p_org_id           UUID,
  p_tokens_estimated INTEGER,
  p_request_limit    INTEGER,
  p_token_limit      INTEGER
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_member   BOOLEAN;
  v_period   TEXT;
  v_requests INTEGER;
  v_reserved INTEGER;
BEGIN
  IF p_tokens_estimated IS NULL OR p_tokens_estimated < 0 THEN
    RAISE EXCEPTION 'ai_invalid_estimate'
      USING ERRCODE = 'P0001';
  END IF;
  IF p_request_limit IS NULL OR p_token_limit IS NULL OR p_request_limit < 0 OR p_token_limit < 0 THEN
    RAISE EXCEPTION 'ai_invalid_limit'
      USING ERRCODE = 'P0001';
  END IF;

  -- Authorization: explicit p_user_id must belong to p_org_id (or be super admin).
  SELECT (role = 'super_admin' OR organization_id = p_org_id) INTO v_member
    FROM profiles WHERE id = p_user_id;
  IF v_member IS NULL OR NOT v_member THEN
    RAISE EXCEPTION 'ai_unauthorized'
      USING ERRCODE = 'P0001';
  END IF;

  -- Original quota period is fixed at reservation/admission time.
  v_period := to_char(current_date, 'YYYY-MM');

  -- Create the usage row if necessary, then LOCK it to serialize admissions.
  INSERT INTO ai_usage (organization_id, period_month)
  VALUES (p_org_id, v_period)
  ON CONFLICT (organization_id, period_month) DO NOTHING;

  SELECT requests_used, tokens_reserved INTO v_requests, v_reserved
    FROM ai_usage
    WHERE organization_id = p_org_id AND period_month = v_period
    FOR UPDATE;

  IF v_requests IS NULL THEN
    RAISE EXCEPTION 'ai_usage_row_missing'
      USING ERRCODE = 'P0001';
  END IF;

  -- Checks under the row lock (no SELECT/IF/UPDATE race window).
  IF v_requests + 1 > p_request_limit THEN
    RAISE EXCEPTION 'ai_quota_exceeded'
      USING ERRCODE = 'P0001',
            DETAIL = 'request limit';
  END IF;
  IF v_reserved + p_tokens_estimated > p_token_limit THEN
    RAISE EXCEPTION 'ai_quota_exceeded'
      USING ERRCODE = 'P0001',
            DETAIL = 'token limit';
  END IF;

  -- Increment the reservation (request consumed at admission; never refunded).
  UPDATE ai_usage
    SET requests_used   = requests_used + 1,
        tokens_reserved = tokens_reserved + p_tokens_estimated,
        updated_at      = now()
    WHERE organization_id = p_org_id AND period_month = v_period;

  RETURN jsonb_build_object(
    'organization_id', p_org_id,
    'period_month',    v_period,
    'requests_used',   v_requests + 1,
    'tokens_reserved', v_reserved + p_tokens_estimated
  );
END;
$$;

-- Internal: reconcile a job's quota exactly once (idempotent).
-- Safe to call from: terminal transition RPCs (same transaction) and the
-- recovery sweep for terminal jobs left unreconciled (crash-window invariant).
CREATE OR REPLACE FUNCTION public.ai_reconcile_job(p_job_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_status      TEXT;
  v_org         UUID;
  v_period      TEXT;
  v_estimated   INTEGER;
  v_used        INTEGER;
  v_reconciled  BOOLEAN;
  v_delta_used  INTEGER;
BEGIN
  SELECT status, organization_id, period_month, tokens_estimated,
         COALESCE(tokens_used, tokens_estimated), quota_reconciled
    INTO v_status, v_org, v_period, v_estimated, v_used, v_reconciled
    FROM ai_jobs WHERE id = p_job_id FOR UPDATE;

  IF NOT FOUND OR v_reconciled OR v_status IN ('pending', 'processing') THEN
    RETURN FALSE;
  END IF;

  -- completed => final accounting = actual (A - E net of reservation release).
  -- failed/cancelled => release the reserved estimate (0 - E).
  IF v_status = 'completed' THEN
    v_delta_used := v_used;
  ELSE
    v_delta_used := 0;
  END IF;

  UPDATE ai_usage
    SET tokens_used     = tokens_used + v_delta_used,
        tokens_reserved = tokens_reserved - v_estimated,
        updated_at      = now()
    WHERE organization_id = v_org AND period_month = v_period;

  UPDATE ai_jobs
    SET quota_reconciled = TRUE,
        updated_at       = now()
    WHERE id = p_job_id;

  RETURN TRUE;
END;
$$;

-- ============================================================
-- 3. ADMISSION RPCs (service-role only)
-- ============================================================

-- Standalone atomic reservation (audit + tests + admission primitive).
CREATE OR REPLACE FUNCTION public.reserve_ai_quota(
  p_user_id          UUID,
  p_org_id           UUID,
  p_tokens_estimated INTEGER,
  p_request_limit    INTEGER,
  p_token_limit      INTEGER
)
RETURNS jsonb
LANGUAGE SQL
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT public.ai_reserve_usage(p_user_id, p_org_id, p_tokens_estimated, p_request_limit, p_token_limit);
$$;

-- Atomic admission + job creation in ONE transaction (no orphaned reservation
-- window between reserve and insert).
CREATE OR REPLACE FUNCTION public.create_ai_job(
  p_user_id          UUID,
  p_org_id           UUID,
  p_branch_id        UUID,
  p_prompt           TEXT,
  p_system_prompt    TEXT,
  p_language         TEXT DEFAULT 'ar',
  p_model            TEXT DEFAULT NULL,
  p_tokens_estimated INTEGER DEFAULT 500,
  p_request_limit    INTEGER DEFAULT NULL,
  p_token_limit      INTEGER DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_res     jsonb;
  v_period  TEXT;
  v_job_id  UUID;
BEGIN
  IF p_prompt IS NULL OR length(trim(p_prompt)) = 0 THEN
    RAISE EXCEPTION 'ai_invalid_prompt'
      USING ERRCODE = 'P0001';
  END IF;

  -- Branch, when provided, must belong to the same organization.
  IF p_branch_id IS NOT NULL
     AND NOT EXISTS (SELECT 1 FROM branches WHERE id = p_branch_id AND organization_id = p_org_id) THEN
    RAISE EXCEPTION 'ai_invalid_branch'
      USING ERRCODE = 'P0001';
  END IF;

  v_res := public.ai_reserve_usage(
    p_user_id, p_org_id, p_tokens_estimated, p_request_limit, p_token_limit
  );
  v_period := v_res ->> 'period_month';

  INSERT INTO ai_jobs (
    user_id, organization_id, branch_id, prompt, system_prompt,
    language, model, tokens_estimated, period_month, status
  )
  VALUES (
    p_user_id, p_org_id, p_branch_id, p_prompt, p_system_prompt,
    COALESCE(p_language, 'ar'), p_model, p_tokens_estimated, v_period, 'pending'
  )
  RETURNING id INTO v_job_id;

  RETURN jsonb_build_object(
    'id',              v_job_id,
    'organization_id', p_org_id,
    'period_month',    v_period,
    'status',          'pending'
  );
END;
$$;

-- ============================================================
-- 4. LIFECYCLE RPCs (worker / server-only)
-- ============================================================

-- Claim: pending -> processing (conditional). Sets worker liveness.
CREATE OR REPLACE FUNCTION public.start_ai_job(
  p_job_id UUID,
  p_user_id UUID,
  p_model TEXT DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_out    jsonb;
  v_status TEXT;
  v_owned  BOOLEAN;
BEGIN
  UPDATE ai_jobs
    SET status = 'processing',
        model = COALESCE(p_model, model),
        last_heartbeat_at = now(),
        updated_at = now()
    WHERE id = p_job_id
      AND status = 'pending'
      AND (user_id = p_user_id OR public.ai_is_super_admin(p_user_id))
    RETURNING jsonb_build_object('changed', TRUE, 'status', 'processing') INTO v_out;

  IF v_out IS NOT NULL THEN
    RETURN v_out;
  END IF;

  SELECT status, (user_id = p_user_id OR public.ai_is_super_admin(p_user_id))
    INTO v_status, v_owned
    FROM ai_jobs WHERE id = p_job_id;

  IF v_status IS NULL THEN
    RETURN jsonb_build_object('changed', FALSE, 'reason', 'missing');
  END IF;
  IF NOT v_owned THEN
    RAISE EXCEPTION 'ai_unauthorized' USING ERRCODE = 'P0001';
  END IF;

  RETURN jsonb_build_object('changed', FALSE, 'status', v_status);
END;
$$;

-- Worker liveness + persisted cumulative output buffer. Only valid in
-- 'processing'; never touches terminal jobs.
CREATE OR REPLACE FUNCTION public.heartbeat_ai_job(
  p_job_id        UUID,
  p_user_id       UUID,
  p_output_buffer TEXT DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_status TEXT;
  v_owned  BOOLEAN;
BEGIN
  SELECT status, (user_id = p_user_id OR public.ai_is_super_admin(p_user_id))
    INTO v_status, v_owned
    FROM ai_jobs WHERE id = p_job_id;

  IF v_status IS NULL THEN
    RETURN jsonb_build_object('changed', FALSE, 'reason', 'missing');
  END IF;
  IF NOT v_owned THEN
    RAISE EXCEPTION 'ai_unauthorized' USING ERRCODE = 'P0001';
  END IF;
  IF v_status <> 'processing' THEN
    RETURN jsonb_build_object('changed', FALSE, 'status', v_status);
  END IF;

  UPDATE ai_jobs
    SET last_heartbeat_at = now(),
        output_buffer     = COALESCE(p_output_buffer, output_buffer),
        updated_at        = now()
    WHERE id = p_job_id;

  RETURN jsonb_build_object('changed', TRUE, 'status', 'processing');
END;
$$;

-- ============================================================
-- 5. TERMINAL TRANSITIONS — each is ATOMIC with reconciliation
-- ============================================================

-- processing -> completed. Reconciles tokens_used += actual (reservation released).
CREATE OR REPLACE FUNCTION public.complete_ai_job(
  p_job_id       UUID,
  p_user_id      UUID,
  p_tokens_used  INTEGER DEFAULT NULL,
  p_output_final TEXT DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_status TEXT;
  v_owned  BOOLEAN;
BEGIN
  SELECT status, (user_id = p_user_id OR public.ai_is_super_admin(p_user_id))
    INTO v_status, v_owned
    FROM ai_jobs WHERE id = p_job_id FOR UPDATE;

  IF v_status IS NULL THEN
    RETURN jsonb_build_object('changed', FALSE, 'reason', 'missing');
  END IF;
  IF NOT v_owned THEN
    RAISE EXCEPTION 'ai_unauthorized' USING ERRCODE = 'P0001';
  END IF;
  IF v_status <> 'processing' THEN
    RETURN jsonb_build_object('changed', FALSE, 'status', v_status);
  END IF;

  -- Conditional transition (we own it). Reconciliation follows in the SAME transaction.
  UPDATE ai_jobs
    SET status      = 'completed',
        tokens_used = COALESCE(p_tokens_used, tokens_estimated),
        output_final = COALESCE(p_output_final, output_buffer),
        error       = NULL,
        updated_at  = now()
    WHERE id = p_job_id;

  PERFORM public.ai_reconcile_job(p_job_id);

  RETURN jsonb_build_object('changed', TRUE, 'status', 'completed');
END;
$$;

-- {pending|processing} -> failed. Releases the reserved estimate (0 - E).
CREATE OR REPLACE FUNCTION public.fail_ai_job(
  p_job_id  UUID,
  p_user_id UUID,
  p_error   TEXT DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_status TEXT;
  v_owned  BOOLEAN;
BEGIN
  SELECT status, (user_id = p_user_id OR public.ai_is_super_admin(p_user_id))
    INTO v_status, v_owned
    FROM ai_jobs WHERE id = p_job_id FOR UPDATE;

  IF v_status IS NULL THEN
    RETURN jsonb_build_object('changed', FALSE, 'reason', 'missing');
  END IF;
  IF NOT v_owned THEN
    RAISE EXCEPTION 'ai_unauthorized' USING ERRCODE = 'P0001';
  END IF;
  IF v_status NOT IN ('pending', 'processing') THEN
    RETURN jsonb_build_object('changed', FALSE, 'status', v_status);
  END IF;

  UPDATE ai_jobs
    SET status     = 'failed',
        error      = COALESCE(p_error, 'Inference failed'),
        updated_at = now()
    WHERE id = p_job_id;

  PERFORM public.ai_reconcile_job(p_job_id);

  RETURN jsonb_build_object('changed', TRUE, 'status', 'failed');
END;
$$;

-- {pending|processing} -> cancelled (strict ownership: own job only or super admin).
-- Releases the reserved estimate exactly once.
CREATE OR REPLACE FUNCTION public.cancel_ai_job(
  p_job_id  UUID,
  p_user_id UUID
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_status TEXT;
  v_owned  BOOLEAN;
BEGIN
  SELECT status, (user_id = p_user_id OR public.ai_is_super_admin(p_user_id))
    INTO v_status, v_owned
    FROM ai_jobs WHERE id = p_job_id FOR UPDATE;

  IF v_status IS NULL THEN
    RETURN jsonb_build_object('changed', FALSE, 'reason', 'missing');
  END IF;
  IF NOT v_owned THEN
    RAISE EXCEPTION 'ai_unauthorized' USING ERRCODE = 'P0001';
  END IF;
  IF v_status NOT IN ('pending', 'processing') THEN
    RETURN jsonb_build_object('changed', FALSE, 'status', v_status);
  END IF;

  UPDATE ai_jobs
    SET status     = 'cancelled',
        updated_at = now()
    WHERE id = p_job_id;

  PERFORM public.ai_reconcile_job(p_job_id);

  RETURN jsonb_build_object('changed', TRUE, 'status', 'cancelled');
END;
$$;

-- Consumed marker (Accept/Discard completed flow). No accounting change.
CREATE OR REPLACE FUNCTION public.consume_ai_job(
  p_job_id  UUID,
  p_user_id UUID
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_ok BOOLEAN;
BEGIN
  UPDATE ai_jobs
    SET consumed   = TRUE,
        updated_at = now()
    WHERE id = p_job_id
      AND user_id = p_user_id
      AND status = 'completed'
    RETURNING TRUE INTO v_ok;

  IF v_ok THEN
    RETURN jsonb_build_object('changed', TRUE, 'consumed', TRUE);
  END IF;

  SELECT (status = 'completed' AND user_id = p_user_id)
    INTO v_ok
    FROM ai_jobs WHERE id = p_job_id;

  RETURN jsonb_build_object('changed', FALSE, 'consumed', COALESCE(v_ok, FALSE));
END;
$$;

-- ============================================================
-- 6. WATCHDOG (lazy reaper) — conditional, idempotent, reconciles
--    ONLY when it actually transitioned processing -> failed.
-- ============================================================
CREATE OR REPLACE FUNCTION public.reap_stale_ai_job(
  p_job_id               UUID,
  p_stale_after_seconds  INTEGER DEFAULT 90
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_status         TEXT;
  v_hb             TIMESTAMPTZ;
  v_max            TIMESTAMPTZ;
BEGIN
  v_max := now() - make_interval(secs => GREATEST(p_stale_after_seconds, 1));

  SELECT status, last_heartbeat_at INTO v_status, v_hb
    FROM ai_jobs WHERE id = p_job_id FOR UPDATE;

  IF NOT FOUND OR v_status IS NULL THEN
    RETURN jsonb_build_object('changed', FALSE, 'reason', 'missing');
  END IF;

  -- Only an in-flight job with a stale (or never-beaten) heartbeat is eligible.
  IF v_status <> 'processing'
     OR (v_hb IS NOT NULL AND v_hb >= v_max) THEN
    RETURN jsonb_build_object('changed', FALSE, 'status', v_status);
  END IF;

  UPDATE ai_jobs
    SET status     = 'failed',
        error      = 'Watchdog: stale heartbeat (no heartbeat within ' || p_stale_after_seconds || 's)',
        updated_at = now()
    WHERE id = p_job_id;

  -- Only after the conditional transition succeeded may we reconcile.
  PERFORM public.ai_reconcile_job(p_job_id);

  RETURN jsonb_build_object('changed', TRUE, 'status', 'failed');
END;
$$;

-- ============================================================
-- 7. RECOVERY SWEEP — crash-window invariant:
--    every terminal job gets exactly one reconciliation; no terminal job
--    may remain permanently unreconciled. Normally a no-op because the
--    terminal transition RPCs are atomic with reconciliation.
-- ============================================================
CREATE OR REPLACE FUNCTION public.reconcile_abandoned_terminal_ai_jobs(
  p_job_id UUID DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_row   RECORD;
  v_count INTEGER := 0;
BEGIN
  FOR v_row IN
    SELECT id FROM ai_jobs
    WHERE status IN ('completed', 'failed', 'cancelled')
      AND quota_reconciled = FALSE
      AND (p_job_id IS NULL OR id = p_job_id)
    ORDER BY id
    FOR UPDATE SKIP LOCKED
  LOOP
    IF public.ai_reconcile_job(v_row.id) THEN
      v_count := v_count + 1;
    END IF;
  END LOOP;

  RETURN jsonb_build_object('reconciled', v_count);
END;
$$;

-- ============================================================
-- 8. ROW LEVEL SECURITY
-- ============================================================

ALTER TABLE ai_jobs  ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_usage ENABLE ROW LEVEL SECURITY;

-- Client: SELECT own jobs only. No INSERT/UPDATE/DELETE policies:
-- job lifecycle is server-only (service-role path).
CREATE POLICY "ai_jobs_select_own"
  ON ai_jobs FOR SELECT TO authenticated
  USING (user_id = auth.uid());

-- Client: read own organization's usage (existing helper pattern from 00003).
CREATE POLICY "ai_usage_select_org"
  ON ai_usage FOR SELECT TO authenticated
  USING (
    organization_id = public.get_current_user_org_id()
    OR public.get_current_user_role() = 'super_admin'
  );

-- ============================================================
-- 9. PRIVILEGES
-- ============================================================

-- Server-only lifecycle: strip accidental client write privileges that
-- Supabase default privileges would otherwise bestow on new tables.
REVOKE INSERT, UPDATE, DELETE ON ai_jobs  FROM anon, authenticated;
REVOKE INSERT, UPDATE, DELETE ON ai_usage FROM anon, authenticated;
REVOKE SELECT ON ai_jobs  FROM anon;
REVOKE SELECT ON ai_usage FROM anon;
GRANT SELECT ON ai_jobs  TO authenticated;

-- RPCs are service-role only (server path). Supabase complains loudly if we
-- expose strongly privileged SECURITY DEFINER functions to the client.
REVOKE EXECUTE ON FUNCTION public.ai_is_super_admin(UUID)     FROM public, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.ai_reserve_usage(UUID, UUID, INTEGER, INTEGER, INTEGER) FROM public, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.ai_reconcile_job(UUID)      FROM public, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.reserve_ai_quota(UUID, UUID, INTEGER, INTEGER, INTEGER) FROM public, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.create_ai_job(UUID, UUID, UUID, TEXT, TEXT, TEXT, TEXT, INTEGER, INTEGER, INTEGER) FROM public, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.start_ai_job(UUID, UUID, TEXT)            FROM public, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.heartbeat_ai_job(UUID, UUID, TEXT)        FROM public, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.complete_ai_job(UUID, UUID, INTEGER, TEXT) FROM public, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.fail_ai_job(UUID, UUID, TEXT)             FROM public, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.cancel_ai_job(UUID, UUID)                 FROM public, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.consume_ai_job(UUID, UUID)                FROM public, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.reap_stale_ai_job(UUID, INTEGER)          FROM public, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.reconcile_abandoned_terminal_ai_jobs(UUID) FROM public, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.ai_is_super_admin(UUID)     TO service_role;
GRANT EXECUTE ON FUNCTION public.ai_reserve_usage(UUID, UUID, INTEGER, INTEGER, INTEGER) TO service_role;
GRANT EXECUTE ON FUNCTION public.ai_reconcile_job(UUID)      TO service_role;
GRANT EXECUTE ON FUNCTION public.reserve_ai_quota(UUID, UUID, INTEGER, INTEGER, INTEGER) TO service_role;
GRANT EXECUTE ON FUNCTION public.create_ai_job(UUID, UUID, UUID, TEXT, TEXT, TEXT, TEXT, INTEGER, INTEGER, INTEGER) TO service_role;
GRANT EXECUTE ON FUNCTION public.start_ai_job(UUID, UUID, TEXT)            TO service_role;
GRANT EXECUTE ON FUNCTION public.heartbeat_ai_job(UUID, UUID, TEXT)        TO service_role;
GRANT EXECUTE ON FUNCTION public.complete_ai_job(UUID, UUID, INTEGER, TEXT) TO service_role;
GRANT EXECUTE ON FUNCTION public.fail_ai_job(UUID, UUID, TEXT)             TO service_role;
GRANT EXECUTE ON FUNCTION public.cancel_ai_job(UUID, UUID)                 TO service_role;
GRANT EXECUTE ON FUNCTION public.consume_ai_job(UUID, UUID)                TO service_role;
GRANT EXECUTE ON FUNCTION public.reap_stale_ai_job(UUID, INTEGER)          TO service_role;
GRANT EXECUTE ON FUNCTION public.reconcile_abandoned_terminal_ai_jobs(UUID) TO service_role;