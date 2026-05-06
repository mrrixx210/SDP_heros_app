-- ============================================================================
-- SDP Heroes v2 ... initial schema.
-- Source: SDP_HEROES_BUILD.md section 4. Verbatim modulo Postgres-flavor
-- type adjustments (jsonb, text[], uuid, timestamptz). Idempotent so
-- the migration test suite can re-run it without error.
-- ============================================================================

-- Required for gen_random_uuid() and gen_random_bytes() (api_key generation).
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ── Identity ────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS tech_users (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name            text NOT NULL,
    phone           text,
    email           text UNIQUE,
    role            text NOT NULL CHECK (role IN ('plumbing','hvac','demo','lead','foreman','apprentice')),
    active          boolean NOT NULL DEFAULT true,
    created_at      timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS tech_users_active_idx ON tech_users(active) WHERE active;

CREATE TABLE IF NOT EXISTS admin_users (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name            text NOT NULL,
    email           text UNIQUE NOT NULL,
    role            text NOT NULL CHECK (role IN ('owner','dispatcher','accounting','ops')),
    active          boolean NOT NULL DEFAULT true,
    created_at      timestamptz NOT NULL DEFAULT now()
);

-- agent_users gets seeded in Step 7. Empty until then.
CREATE TABLE IF NOT EXISTS agent_users (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name            text NOT NULL,
    agent_type      text NOT NULL CHECK (agent_type IN ('tony','vinny','anna','claude_code','other')),
    api_key_hash    text UNIQUE NOT NULL,
    active          boolean NOT NULL DEFAULT true,
    created_at      timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS agent_users_active_idx ON agent_users(active) WHERE active;

-- ── Customers + Jobs ────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS customers (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name            text NOT NULL,
    phone           text,
    email           text,
    address_line1   text,
    address_line2   text,
    city            text,
    state           text,
    zip             text,
    lat             numeric(9,6),
    lng             numeric(9,6),
    notes           text,
    source          text,
    created_at      timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS customers_phone_idx ON customers(phone);
CREATE INDEX IF NOT EXISTS customers_email_idx ON customers(email);
CREATE INDEX IF NOT EXISTS customers_zip_idx ON customers(zip);

CREATE TABLE IF NOT EXISTS jobs (
    id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id        uuid NOT NULL REFERENCES customers(id) ON DELETE RESTRICT,
    status             text NOT NULL DEFAULT 'unscheduled'
                         CHECK (status IN ('unscheduled','scheduled','enroute','onsite','completed','invoiced','paid','canceled')),
    type               text NOT NULL CHECK (type IN ('plumbing','hvac','demo','plumbing_hvac','other')),
    source             text,
    priority           text NOT NULL DEFAULT 'normal' CHECK (priority IN ('low','normal','high','urgent')),
    scheduled_start    timestamptz,
    scheduled_end      timestamptz,
    actual_start       timestamptz,
    actual_end         timestamptz,
    assigned_tech_id   uuid REFERENCES tech_users(id),
    scope              text,
    internal_notes     text,
    gross_total        numeric(10,2),
    gp_estimate        numeric(10,2),
    created_by         uuid,
    created_at         timestamptz NOT NULL DEFAULT now(),
    updated_at         timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS jobs_status_idx ON jobs(status);
CREATE INDEX IF NOT EXISTS jobs_assigned_tech_idx ON jobs(assigned_tech_id);
CREATE INDEX IF NOT EXISTS jobs_scheduled_start_idx ON jobs(scheduled_start);
CREATE INDEX IF NOT EXISTS jobs_customer_idx ON jobs(customer_id);

CREATE TABLE IF NOT EXISTS job_status_log (
    id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    job_id       uuid NOT NULL REFERENCES jobs(id) ON DELETE CASCADE,
    from_status  text,
    to_status    text NOT NULL,
    changed_by   uuid,
    changed_at   timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS job_status_log_job_idx ON job_status_log(job_id, changed_at DESC);

CREATE TABLE IF NOT EXISTS job_tags (
    id      uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    job_id  uuid NOT NULL REFERENCES jobs(id) ON DELETE CASCADE,
    tag     text NOT NULL,
    UNIQUE (job_id, tag)
);

-- ── Money ───────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS estimates (
    id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    job_id       uuid NOT NULL REFERENCES jobs(id) ON DELETE CASCADE,
    line_items   jsonb NOT NULL DEFAULT '[]'::jsonb,
    subtotal     numeric(10,2) NOT NULL DEFAULT 0,
    tax          numeric(10,2) NOT NULL DEFAULT 0,
    total        numeric(10,2) NOT NULL DEFAULT 0,
    status       text NOT NULL DEFAULT 'draft'
                   CHECK (status IN ('draft','sent','approved','rejected','expired','superseded')),
    sent_at      timestamptz,
    approved_at  timestamptz,
    created_at   timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS estimates_job_idx ON estimates(job_id);
CREATE INDEX IF NOT EXISTS estimates_status_idx ON estimates(status);

CREATE TABLE IF NOT EXISTS invoices (
    id                         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    job_id                     uuid NOT NULL REFERENCES jobs(id) ON DELETE CASCADE,
    estimate_id                uuid REFERENCES estimates(id),
    line_items                 jsonb NOT NULL DEFAULT '[]'::jsonb,
    subtotal                   numeric(10,2) NOT NULL DEFAULT 0,
    tax                        numeric(10,2) NOT NULL DEFAULT 0,
    total                      numeric(10,2) NOT NULL DEFAULT 0,
    status                     text NOT NULL DEFAULT 'draft'
                                 CHECK (status IN ('draft','sent','partial','paid','overdue','void')),
    sent_at                    timestamptz,
    paid_at                    timestamptz,
    stripe_payment_intent_id   text,
    qbo_invoice_id             text,
    created_at                 timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS invoices_job_idx ON invoices(job_id);
CREATE INDEX IF NOT EXISTS invoices_status_idx ON invoices(status);

CREATE TABLE IF NOT EXISTS payments (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    invoice_id      uuid NOT NULL REFERENCES invoices(id) ON DELETE RESTRICT,
    amount          numeric(10,2) NOT NULL,
    method          text NOT NULL CHECK (method IN ('stripe','cash','check','ach','mercury','zelle','other')),
    stripe_id       text,
    mercury_ref     text,
    paid_at         timestamptz NOT NULL DEFAULT now(),
    created_at      timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS payments_invoice_idx ON payments(invoice_id);

-- ── Field ──────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS job_photos (
    id                     uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    job_id                 uuid NOT NULL REFERENCES jobs(id) ON DELETE CASCADE,
    url                    text NOT NULL,
    thumbnail_url          text,
    taken_at               timestamptz,
    lat                    numeric(9,6),
    lng                    numeric(9,6),
    category               text,
    caption                text,
    ai_caption             text,
    uploaded_by_tech_id    uuid REFERENCES tech_users(id),
    created_at             timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS job_photos_job_idx ON job_photos(job_id);

CREATE TABLE IF NOT EXISTS job_notes (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    job_id          uuid NOT NULL REFERENCES jobs(id) ON DELETE CASCADE,
    body            text,
    voice_url       text,
    transcription   text,
    author_id       uuid,
    created_at      timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS job_notes_job_idx ON job_notes(job_id, created_at DESC);

CREATE TABLE IF NOT EXISTS job_signatures (
    id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    job_id      uuid NOT NULL REFERENCES jobs(id) ON DELETE CASCADE,
    url         text NOT NULL,
    signed_by   text,
    signed_at   timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS job_checklists (
    id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    job_id            uuid NOT NULL REFERENCES jobs(id) ON DELETE CASCADE,
    items             jsonb NOT NULL DEFAULT '[]'::jsonb,
    completed_count   integer NOT NULL DEFAULT 0,
    total_count       integer NOT NULL DEFAULT 0,
    created_at        timestamptz NOT NULL DEFAULT now()
);

-- ── AI Output ──────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS ai_pages (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    job_id              uuid REFERENCES jobs(id) ON DELETE CASCADE,
    type                text NOT NULL CHECK (type IN ('walkthrough','summary','daily_log','adjuster_packet','photo_to_estimate','anomaly')),
    content             jsonb NOT NULL DEFAULT '{}'::jsonb,
    generated_by        text NOT NULL,
    source_photo_ids    text[],
    source_audio_url    text,
    share_token         text UNIQUE,
    created_at          timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS ai_pages_job_idx ON ai_pages(job_id);
CREATE INDEX IF NOT EXISTS ai_pages_share_token_idx ON ai_pages(share_token);

CREATE TABLE IF NOT EXISTS ai_jobs_queue (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    type            text NOT NULL,
    payload         jsonb NOT NULL DEFAULT '{}'::jsonb,
    status          text NOT NULL DEFAULT 'queued'
                      CHECK (status IN ('queued','running','completed','failed')),
    retries         integer NOT NULL DEFAULT 0,
    error           text,
    created_at      timestamptz NOT NULL DEFAULT now(),
    completed_at    timestamptz
);
CREATE INDEX IF NOT EXISTS ai_jobs_queue_status_idx ON ai_jobs_queue(status, created_at);

-- ── Comms ──────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS sms_log (
    id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    job_id        uuid REFERENCES jobs(id) ON DELETE SET NULL,
    customer_id   uuid REFERENCES customers(id) ON DELETE SET NULL,
    direction     text NOT NULL CHECK (direction IN ('inbound','outbound')),
    body          text,
    twilio_sid    text,
    sent_at       timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS sms_log_job_idx ON sms_log(job_id);

CREATE TABLE IF NOT EXISTS email_log (
    id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    job_id        uuid REFERENCES jobs(id) ON DELETE SET NULL,
    customer_id   uuid REFERENCES customers(id) ON DELETE SET NULL,
    direction     text NOT NULL CHECK (direction IN ('inbound','outbound')),
    subject       text,
    body          text,
    resend_id     text,
    sent_at       timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS email_log_job_idx ON email_log(job_id);

-- ── Inventory + Pricing ────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS inventory_items (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    sku             text UNIQUE,
    name            text NOT NULL,
    category        text,
    unit_cost       numeric(10,2),
    sell_price      numeric(10,2),
    qty_on_hand     integer NOT NULL DEFAULT 0,
    reorder_point   integer NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS job_parts_used (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    job_id              uuid NOT NULL REFERENCES jobs(id) ON DELETE CASCADE,
    inventory_item_id   uuid NOT NULL REFERENCES inventory_items(id) ON DELETE RESTRICT,
    qty                 numeric(10,3) NOT NULL,
    unit_cost           numeric(10,2),
    sell_price          numeric(10,2)
);
CREATE INDEX IF NOT EXISTS job_parts_used_job_idx ON job_parts_used(job_id);

-- ── Integrations sync state ────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS sync_state (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    integration         text NOT NULL,
    last_synced_at      timestamptz,
    cursor              text,
    status              text NOT NULL DEFAULT 'idle'
                          CHECK (status IN ('idle','running','error','paused')),
    UNIQUE (integration)
);

-- ── Touch-updated_at triggers (keeps updated_at fresh on UPDATE) ───────────

CREATE OR REPLACE FUNCTION sdp_touch_updated_at() RETURNS trigger AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DO $$ BEGIN
    CREATE TRIGGER customers_touch_updated_at
        BEFORE UPDATE ON customers
        FOR EACH ROW EXECUTE FUNCTION sdp_touch_updated_at();
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE TRIGGER jobs_touch_updated_at
        BEFORE UPDATE ON jobs
        FOR EACH ROW EXECUTE FUNCTION sdp_touch_updated_at();
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
