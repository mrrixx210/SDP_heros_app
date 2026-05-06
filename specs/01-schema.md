# Spec 01 — Schema

Source of truth: `SDP_HEROES_BUILD.md` section 4. This file is the
extracted, canonicalized version that the migration files in
`apps/api/src/db/migrations/0001_initial_schema.sql` and
`0002_rls_policies.sql` implement verbatim.

## Tables (23 total)

### Identity
- `tech_users` — field technicians (plumbing/HVAC/demo/lead/foreman/apprentice)
- `admin_users` — office (owner/dispatcher/accounting/ops)
- `agent_users` — service-account-style rows for Tony / Vinny / Anna / Claude Code. Bearer tokens stored as hashes only. Step 7 wires actual auth.

### Customers + Jobs
- `customers` — name, address, lat/lng, source
- `jobs` — status (8 states), type, priority, scheduled_start/end, actual_start/end, assigned_tech_id, scope, gross_total, gp_estimate
- `job_status_log` — every status transition with timestamp + actor
- `job_tags` — many-to-one tags

### Money
- `estimates` — line_items jsonb, status (draft/sent/approved/rejected/expired/superseded)
- `invoices` — references estimate, holds stripe_payment_intent_id + qbo_invoice_id
- `payments` — stripe / cash / check / ach / mercury / zelle / other

### Field
- `job_photos` — url, thumbnail_url, lat/lng, ai_caption, uploaded_by_tech_id
- `job_notes` — body, voice_url, transcription, author_id
- `job_signatures` — url, signed_by, signed_at
- `job_checklists` — items jsonb, completed_count, total_count

### AI Output
- `ai_pages` — type (walkthrough/summary/daily_log/adjuster_packet/photo_to_estimate/anomaly), content jsonb, share_token (public-link)
- `ai_jobs_queue` — type, payload, status, retries, error

### Comms
- `sms_log` — direction, body, twilio_sid
- `email_log` — direction, subject, body, resend_id

### Inventory + Pricing
- `inventory_items` — sku, name, unit_cost, sell_price, qty_on_hand, reorder_point
- `job_parts_used` — qty, unit_cost, sell_price snapshot per job

### Integrations sync state
- `sync_state` — one row per integration (qbo, stripe, meta, google, mercury, truss, plaid, sendblue, twilio, resend), last_synced_at + cursor

## RLS rules (from 0002_rls_policies.sql)

- **service-role key bypasses RLS** ... used by backend for server-side reads/writes
- **`role=admin`** in JWT ... full read/write everywhere
- **`role=tech`** in JWT ... can SELECT only jobs (and child rows) where `assigned_tech_id = JWT.sub`. Can INSERT photos/notes/checklists scoped to those jobs.
- **`role=agent`** ... policies fill in Step 7 keyed on `agent_users.role`

## Idempotency

All `CREATE TABLE` statements are `IF NOT EXISTS`. All triggers are
`DO $$ ... duplicate_object handler ... $$`. CI runs the migration
file twice in a row and confirms no error. `pnpm test:migrations`
runs the same check locally.

## Migration verification

```bash
cd apps/api
pnpm install
# Set SUPABASE_DB_URL in .env
pnpm db:push
psql "$SUPABASE_DB_URL" -c "\dt" | wc -l   # expect ~25 (23 tables + headers)
```
