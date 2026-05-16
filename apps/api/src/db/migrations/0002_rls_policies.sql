-- ============================================================================
-- SDP Heroes v2 ... Row-Level Security policies.
-- Source: SDP_HEROES_BUILD.md section 4 RLS rules.
--
-- Roles (auth.jwt() claims):
--   role='tech'    -> sees only jobs assigned to themselves
--   role='admin'   -> sees everything
--   role='agent'   -> scoped per-row by agent_users.role (Step 7 fills in)
--
-- All policies are idempotent (DROP + CREATE) so the migration test
-- suite can re-run without error.
-- ============================================================================

-- Enable RLS on every business table. Service-role key bypasses RLS
-- (used by the backend API for server-side reads/writes).

ALTER TABLE customers           ENABLE ROW LEVEL SECURITY;
ALTER TABLE jobs                ENABLE ROW LEVEL SECURITY;
ALTER TABLE job_status_log      ENABLE ROW LEVEL SECURITY;
ALTER TABLE job_tags            ENABLE ROW LEVEL SECURITY;
ALTER TABLE estimates           ENABLE ROW LEVEL SECURITY;
ALTER TABLE invoices            ENABLE ROW LEVEL SECURITY;
ALTER TABLE payments            ENABLE ROW LEVEL SECURITY;
ALTER TABLE job_photos          ENABLE ROW LEVEL SECURITY;
ALTER TABLE job_notes           ENABLE ROW LEVEL SECURITY;
ALTER TABLE job_signatures      ENABLE ROW LEVEL SECURITY;
ALTER TABLE job_checklists      ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_pages            ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_jobs_queue       ENABLE ROW LEVEL SECURITY;
ALTER TABLE sms_log             ENABLE ROW LEVEL SECURITY;
ALTER TABLE email_log           ENABLE ROW LEVEL SECURITY;
ALTER TABLE inventory_items     ENABLE ROW LEVEL SECURITY;
ALTER TABLE job_parts_used      ENABLE ROW LEVEL SECURITY;
ALTER TABLE sync_state          ENABLE ROW LEVEL SECURITY;

-- Identity tables: each user can read their own row; admins see all.
ALTER TABLE tech_users          ENABLE ROW LEVEL SECURITY;
ALTER TABLE admin_users         ENABLE ROW LEVEL SECURITY;
ALTER TABLE agent_users         ENABLE ROW LEVEL SECURITY;

-- Helper: pull role + user_id out of the JWT, with fallbacks.
CREATE OR REPLACE FUNCTION sdp_jwt_role() RETURNS text AS $$
    SELECT coalesce(auth.jwt() ->> 'role', '')::text;
$$ LANGUAGE sql STABLE;

CREATE OR REPLACE FUNCTION sdp_jwt_user_id() RETURNS uuid AS $$
    SELECT nullif(coalesce(auth.jwt() ->> 'sub', ''), '')::uuid;
$$ LANGUAGE sql STABLE;

CREATE OR REPLACE FUNCTION sdp_is_admin() RETURNS boolean AS $$
    SELECT sdp_jwt_role() = 'admin';
$$ LANGUAGE sql STABLE;

CREATE OR REPLACE FUNCTION sdp_is_tech() RETURNS boolean AS $$
    SELECT sdp_jwt_role() = 'tech';
$$ LANGUAGE sql STABLE;

-- ── customers ──────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS customers_admin_all ON customers;
CREATE POLICY customers_admin_all ON customers FOR ALL
    USING (sdp_is_admin()) WITH CHECK (sdp_is_admin());

DROP POLICY IF EXISTS customers_tech_read_assigned ON customers;
CREATE POLICY customers_tech_read_assigned ON customers FOR SELECT
    USING (
        sdp_is_tech() AND id IN (
            SELECT customer_id FROM jobs WHERE assigned_tech_id = sdp_jwt_user_id()
        )
    );

-- ── jobs (the heart of RLS: techs see only their own assigned jobs) ────────
DROP POLICY IF EXISTS jobs_admin_all ON jobs;
CREATE POLICY jobs_admin_all ON jobs FOR ALL
    USING (sdp_is_admin()) WITH CHECK (sdp_is_admin());

DROP POLICY IF EXISTS jobs_tech_read_assigned ON jobs;
CREATE POLICY jobs_tech_read_assigned ON jobs FOR SELECT
    USING (sdp_is_tech() AND assigned_tech_id = sdp_jwt_user_id());

DROP POLICY IF EXISTS jobs_tech_update_assigned ON jobs;
CREATE POLICY jobs_tech_update_assigned ON jobs FOR UPDATE
    USING (sdp_is_tech() AND assigned_tech_id = sdp_jwt_user_id())
    WITH CHECK (sdp_is_tech() AND assigned_tech_id = sdp_jwt_user_id());

-- ── Per-job child tables: read-if-job-readable pattern ─────────────────────
-- One macro-style helper for the many child tables that share the rule:
-- "you can see the row if you can see the parent job".

DROP POLICY IF EXISTS job_status_log_admin_all ON job_status_log;
CREATE POLICY job_status_log_admin_all ON job_status_log FOR ALL
    USING (sdp_is_admin()) WITH CHECK (sdp_is_admin());
DROP POLICY IF EXISTS job_status_log_tech_read ON job_status_log;
CREATE POLICY job_status_log_tech_read ON job_status_log FOR SELECT
    USING (
        sdp_is_tech() AND job_id IN (
            SELECT id FROM jobs WHERE assigned_tech_id = sdp_jwt_user_id()
        )
    );

DROP POLICY IF EXISTS job_tags_admin_all ON job_tags;
CREATE POLICY job_tags_admin_all ON job_tags FOR ALL
    USING (sdp_is_admin()) WITH CHECK (sdp_is_admin());
DROP POLICY IF EXISTS job_tags_tech_read ON job_tags;
CREATE POLICY job_tags_tech_read ON job_tags FOR SELECT
    USING (
        sdp_is_tech() AND job_id IN (
            SELECT id FROM jobs WHERE assigned_tech_id = sdp_jwt_user_id()
        )
    );

DROP POLICY IF EXISTS estimates_admin_all ON estimates;
CREATE POLICY estimates_admin_all ON estimates FOR ALL
    USING (sdp_is_admin()) WITH CHECK (sdp_is_admin());
DROP POLICY IF EXISTS estimates_tech_read ON estimates;
CREATE POLICY estimates_tech_read ON estimates FOR SELECT
    USING (
        sdp_is_tech() AND job_id IN (
            SELECT id FROM jobs WHERE assigned_tech_id = sdp_jwt_user_id()
        )
    );

DROP POLICY IF EXISTS invoices_admin_all ON invoices;
CREATE POLICY invoices_admin_all ON invoices FOR ALL
    USING (sdp_is_admin()) WITH CHECK (sdp_is_admin());

DROP POLICY IF EXISTS payments_admin_all ON payments;
CREATE POLICY payments_admin_all ON payments FOR ALL
    USING (sdp_is_admin()) WITH CHECK (sdp_is_admin());

DROP POLICY IF EXISTS job_photos_admin_all ON job_photos;
CREATE POLICY job_photos_admin_all ON job_photos FOR ALL
    USING (sdp_is_admin()) WITH CHECK (sdp_is_admin());
DROP POLICY IF EXISTS job_photos_tech_rw ON job_photos;
CREATE POLICY job_photos_tech_rw ON job_photos FOR ALL
    USING (
        sdp_is_tech() AND job_id IN (
            SELECT id FROM jobs WHERE assigned_tech_id = sdp_jwt_user_id()
        )
    )
    WITH CHECK (
        sdp_is_tech() AND uploaded_by_tech_id = sdp_jwt_user_id()
    );

DROP POLICY IF EXISTS job_notes_admin_all ON job_notes;
CREATE POLICY job_notes_admin_all ON job_notes FOR ALL
    USING (sdp_is_admin()) WITH CHECK (sdp_is_admin());
DROP POLICY IF EXISTS job_notes_tech_rw ON job_notes;
CREATE POLICY job_notes_tech_rw ON job_notes FOR ALL
    USING (
        sdp_is_tech() AND job_id IN (
            SELECT id FROM jobs WHERE assigned_tech_id = sdp_jwt_user_id()
        )
    )
    WITH CHECK (
        sdp_is_tech() AND author_id = sdp_jwt_user_id()
    );

DROP POLICY IF EXISTS job_signatures_admin_all ON job_signatures;
CREATE POLICY job_signatures_admin_all ON job_signatures FOR ALL
    USING (sdp_is_admin()) WITH CHECK (sdp_is_admin());

DROP POLICY IF EXISTS job_checklists_admin_all ON job_checklists;
CREATE POLICY job_checklists_admin_all ON job_checklists FOR ALL
    USING (sdp_is_admin()) WITH CHECK (sdp_is_admin());
DROP POLICY IF EXISTS job_checklists_tech_rw ON job_checklists;
CREATE POLICY job_checklists_tech_rw ON job_checklists FOR ALL
    USING (
        sdp_is_tech() AND job_id IN (
            SELECT id FROM jobs WHERE assigned_tech_id = sdp_jwt_user_id()
        )
    );

DROP POLICY IF EXISTS ai_pages_admin_all ON ai_pages;
CREATE POLICY ai_pages_admin_all ON ai_pages FOR ALL
    USING (sdp_is_admin()) WITH CHECK (sdp_is_admin());

DROP POLICY IF EXISTS ai_jobs_queue_admin_all ON ai_jobs_queue;
CREATE POLICY ai_jobs_queue_admin_all ON ai_jobs_queue FOR ALL
    USING (sdp_is_admin()) WITH CHECK (sdp_is_admin());

DROP POLICY IF EXISTS sms_log_admin_all ON sms_log;
CREATE POLICY sms_log_admin_all ON sms_log FOR ALL
    USING (sdp_is_admin()) WITH CHECK (sdp_is_admin());

DROP POLICY IF EXISTS email_log_admin_all ON email_log;
CREATE POLICY email_log_admin_all ON email_log FOR ALL
    USING (sdp_is_admin()) WITH CHECK (sdp_is_admin());

DROP POLICY IF EXISTS inventory_items_admin_all ON inventory_items;
CREATE POLICY inventory_items_admin_all ON inventory_items FOR ALL
    USING (sdp_is_admin()) WITH CHECK (sdp_is_admin());

DROP POLICY IF EXISTS job_parts_used_admin_all ON job_parts_used;
CREATE POLICY job_parts_used_admin_all ON job_parts_used FOR ALL
    USING (sdp_is_admin()) WITH CHECK (sdp_is_admin());

DROP POLICY IF EXISTS sync_state_admin_all ON sync_state;
CREATE POLICY sync_state_admin_all ON sync_state FOR ALL
    USING (sdp_is_admin()) WITH CHECK (sdp_is_admin());

-- ── Identity tables ────────────────────────────────────────────────────────

DROP POLICY IF EXISTS tech_users_admin_all ON tech_users;
CREATE POLICY tech_users_admin_all ON tech_users FOR ALL
    USING (sdp_is_admin()) WITH CHECK (sdp_is_admin());
DROP POLICY IF EXISTS tech_users_self_read ON tech_users;
CREATE POLICY tech_users_self_read ON tech_users FOR SELECT
    USING (sdp_is_tech() AND id = sdp_jwt_user_id());

DROP POLICY IF EXISTS admin_users_admin_all ON admin_users;
CREATE POLICY admin_users_admin_all ON admin_users FOR ALL
    USING (sdp_is_admin()) WITH CHECK (sdp_is_admin());

DROP POLICY IF EXISTS agent_users_admin_all ON agent_users;
CREATE POLICY agent_users_admin_all ON agent_users FOR ALL
    USING (sdp_is_admin()) WITH CHECK (sdp_is_admin());
