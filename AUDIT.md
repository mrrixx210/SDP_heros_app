# SDP Heroes — Day 0 Audit

**Date:** 2026-04-28
**Repo:** https://github.com/mrrixx210/SDP_heros_app
**Working path:** `~/Desktop/sdp-heroes/` (renamed from `~/Desktop/Co Work/Super Duper Pros/` during Step 0)
**Audited against:** `SDP_HEROES_BUILD.md` + `SDP_HEROES_PLAYWRIGHT_QA.md` (sit on disk in this directory; not yet committed to git)
**Audited by:** Claude Code on Tony's M4 Mac Mini

---

## Summary

The local tree at `~/Desktop/sdp-heroes/` (formerly `Co Work/Super Duper Pros/`) holds ~251 source files / ~24,500 LOC of working but spec-divergent code. Major stacks (iOS, dashboard, backend) need rewrites because the existing implementations chose different frameworks than the spec. The Tony Russo agent stack, the workspace-cli Google Chat integration, and several scripts (Workiz / QBO / CompanyCam clients) are aligned with spec intent and should be preserved.

The empty GitHub repo was seeded today with a minimal `main` (`.gitignore` + `README.md` only). The 253 MB tree on disk is **not** in this repo. Step 1 (`heroes-v2-rebuild`) will selectively port what's marked KEEP and rewrite what's marked REWRITE. Nothing is being lost — the disk content is preserved at `~/Desktop/sdp-heroes/` and can be referenced module by module as the rebuild progresses.

---

## Headline tensions vs spec

| Area | Existing | Spec | Decision |
|---|---|---|---|
| iOS auth | Bcrypt PIN + JWT | Supabase Auth | REWRITE |
| Admin panel framework | React 19 + Vite 6 | Next.js 14 App Router | REWRITE |
| Backend language/framework | Python 3.11 + FastAPI | Node + TypeScript + Fastify/Express | REWRITE |
| Schema breadth | jobs, gps, invoices, agent tables | + estimates, ai_pages, sms_log, email_log, signatures, checklists, inventory, parts, sync_state | REWRITE + GAPS |
| Scheduling backend | APScheduler in-process | BullMQ + Redis | REWRITE |
| Test layer | None for product code | Playwright (smoke/critical/regression/migration/failover/ai-quality) + XCUITest | GAPS |
| Local hosting | Dockerfile + railway.toml only | pm2 + Cloudflare Tunnel + Docker Redis on M4, Railway as failover | GAPS |
| Path | `Co Work/Super Duper Pros/` (space) | `sdp-heroes/` | RENAMED today |

---

## KEEP

These align with spec intent or are safe to carry forward verbatim. Marked KEEP **in concept**; selective import on `heroes-v2-rebuild` may still touch wiring.

### Agent layer
- **`agents/tony_russo/`** (~3,200 LOC) — full standalone Claude agent. System prompt + 5 skills (morning_brief, daily_earnings, gmail_monitor, workiz_scheduler, alfred_reporter) + 3 connectors (workiz, quickbooks, companycam, all read-only) + NeMo guardrails + memory module + Dockerfile + railway.toml. Reports up the chain to Alfred (never directly to Rick). Independent of the iOS/admin rebuild and parallels it.
- **`agents/operations_agent.md`**, **`agents/marketing_agent.md`**, **`agents/finance_agent.md`** — agent specs. Useful as design reference for Step 7 (Agent API surface).

### Google Workspace integration
- **`workspace-cli/`** — OAuth 2.0 desktop flow + 9 Google Chat spaces (CEO Direct, Chief of Staff, Operations, Finance, Marketing, Communications, Dispatch, Collections, Analytics) + outbound poster (port 5001) + inbound listener (10s polling). Spaces already created against rick@superduperpros.com. Tokens are gitignored. This is Step 7 / approval-flow plumbing already done.

### Reference data
- **`config/company_profile.md`** — team roster (Workiz IDs), services list, pricing tiers, lead sources, franchise vision. Source of truth for seed data.
- **`.env.template`** — 76 keys covering Workiz, Supabase, Anthropic, Google Chat per-space webhooks, Backend, QBO, CompanyCam, Facebook/Meta, WordPress, RoutePal, GMB, Telegram. Already aligned with most of spec section 9 — extension needed (see GAPS).

### Integration scripts (will become Step 8 migration source)
- **`scripts/workiz_api.py`** + **`scripts/workiz_api_full.py`** — REST client wrappers. Will inform `import-workiz.ts`.
- **`scripts/companycam_api.py`** — read-only client + Claude Vision photo analysis. Will inform `import-companycam.ts`.
- **`scripts/quickbooks_api.py`** — OAuth 2.0 client, P&L, AR aging, invoice creation. Reusable for Step 5 QBO integration.
- **`scripts/bank_statement_parser.py`** — Chase / BofA / Wells CSV + PDF parsing. Reusable for Step 5 Plaid + Mercury + Truss reconciliation.
- **`scripts/reconciliation_engine.py`** — fuzzy-match bank txns to QBO. Reusable.
- **`scripts/workers_comp_pl.py`** — regulatory-grade P&L. Reusable as a finance utility.

### Operational docs (preserve as historical context, not rewrite)
- **`STATUS.md`** — claims 95% complete state of the *old* build. Keep as historical reference only; new STATUS will be built by the v2 system.
- **`MISSION_CONTROL.md`** — system architecture summary. Useful to read once for context, then supersede with `/specs/*.md` per spec section 6.
- **`config/company_profile.md`** — see above, kept.

### Database (partial)
- **`supabase/008_tony_russo_tables.sql`** — Tony's conversation/memory/task/digest_log tables. Independent of core schema, keep as-is for the agent stack.
- **`supabase/sdp_mission_control.sql`** — agent_activity_log + agent_outputs. Useful audit trail for the agent layer.
- **`supabase/009_approval_queue.sql`** — approval_queue table. Aligns with spec's AUTO_APPROVE / TONY_APPROVAL / CEO_APPROVAL tiers.

---

## REWRITE

These exist but the existing implementation does not match spec. Code on disk is reference material; new implementation goes into the new repo structure.

### iOS app — `SDPHeroes/`
Existing: 84 Swift files / ~2,100 LOC. SwiftUI ✓. Supabase Swift SDK ✓. CoreLocation GPS tracking ✓. Models for Job / Invoice / Employee / Schedule / Warranty / Announcement. Views for Login / Today / JobList / JobDetail / DispatchBoard / EmployeeList / Invoice / PriceBook / Margin / Warranty / Settings.

Spec divergence:
- Auth is bcrypt PIN + custom JWT — **spec wants Supabase Auth.**
- Missing native camera capture flow with offline queueing.
- Missing voice notes (WhisperKit on-device + Whisper API fallback).
- Missing AI walkthrough flow (audio + photos → structured doc).
- Missing Day Wrap (end-of-day log generation).
- Missing StripeTerminal SDK for tap-to-pay.
- Missing photo signing / customer signature capture.
- Missing background uploads via URLSession background config.
- Missing APNs push notification registration.
- Per spec naming: existing dispatch / job views fine, but new screens must use "Day Wrap" / "Job Summary" / "Project Timeline" (not CompanyCam-style "Daily Log" / "Summary" / "Progress Recap").

Approach: keep this version as reference. New app at `apps/ios/` rebuilt against Supabase Auth + spec screen list. Cherry-pick UI primitives (StatCardView, BadgeView, etc.) where they don't carry CompanyCam-style patterns.

### Admin panel — `dashboard/`
Existing: React 19 + Vite 6 + TypeScript 5.8 + Tailwind 4. 10 pages (Dashboard, Jobs, Dispatch, Employees, Invoices, PriceBook, Agents, Reports, Announcements, Settings). TonyChatWidget floating bubble. Supabase client. TanStack Query. Recharts. ESLint + TS strict mode.

Spec divergence:
- **Framework: Vite + React → spec wants Next.js 14 App Router.** Server components, server actions, file-based routing all need to be adopted.
- Missing shadcn/ui (currently bare Tailwind components).
- Missing TanStack Table.
- Missing Supabase Realtime subscriptions on dispatch board (drag-drop must update instantly across clients).
- Missing approval queue UI surface.
- Missing customer SMS reply toasts + thread view.
- Missing all CompanyCam-style photo gallery views (those will be public, share-token gated).

Approach: full rewrite at `apps/admin/`. Keep the page list and the TonyChatWidget concept. Rebuild components against shadcn/ui. Wire realtime via Supabase channels.

### Backend — `backend/`
Existing: Python 3.11 + FastAPI + APScheduler. 8 agents registered (chief_of_staff, operations, finance, marketing, communications, dispatch, collections, analytics). Workiz webhook receiver with HMAC-SHA256 verification. Supabase sync. Guardrails wrapper (NeMo).

Spec divergence:
- **Stack mismatch: Python/FastAPI → spec wants Node + TypeScript + Fastify or Express.**
- **Background jobs: APScheduler in-process → spec wants BullMQ + Redis (Docker on M4).**
- Missing all spec API endpoints under `/api/v1/` (customers, jobs, estimates, invoices, payments, photos, ai/*).
- Missing agent API surface with `Authorization: Bearer ag_xxx` and tiered approvals.
- Missing Twilio inbound/outbound SMS endpoints.
- Missing Resend email integration.
- Missing Stripe webhook handling (separate from Workiz webhook).

Approach: full rewrite at `apps/api/`. Keep the agent dispatcher *concept* but reimplement in TypeScript. Keep the Workiz HMAC verification logic as reference. Move agent definitions into `packages/agent-sdk/`.

### Supabase schema — `supabase/`
Existing migrations:
- `003_field_service_tables.sql` — jobs, gps_tracking, invoices, schedules
- `004_hash_pins.sql` — bcrypt PIN hashing
- `005_harden_rls.sql` — RLS for admin / supervisor / tech
- `006_workiz_qbo_sync.sql` — sync logs
- `007_reconciliation_tables.sql` — bank reconciliation
- `008_tony_russo_tables.sql` — KEEP (see above)
- `009_approval_queue.sql` — KEEP (see above)
- `DEPLOY_ALL.sql` — bundled idempotent deploy script

Spec divergence:
- Missing: `tech_users`, `admin_users`, `agent_users` (current schema collapses into single users table)
- Missing: `customers` (currently jobs reference customer info inline)
- Missing: `job_status_log`, `job_tags`
- Missing: `estimates` (line items, status, sent_at, approved_at)
- Missing: `payments` (separate from invoices)
- Missing: `job_photos`, `job_notes`, `job_signatures`, `job_checklists`
- Missing: `ai_pages`, `ai_jobs_queue`
- Missing: `sms_log`, `email_log`
- Missing: `inventory_items`, `job_parts_used`
- Missing: `sync_state` (single source of truth for integration cursors)
- RLS rules need rewriting for tech-only-assigned-jobs / admin-everything / agent-scoped-per-role.

Approach: write fresh migrations under `apps/api/src/db/migrations/` matching spec's schema verbatim. Migrate any actual data only after Step 8.

### iOS hardcoded Supabase config — `SDPHeroes/SDPHeroes/Config/AppConfig.swift`
Lines 5-6 hardcode the Supabase project URL and anon JWT. Anon keys are RLS-protected and rate-limited (less catastrophic than service_role), but should not be in source. **REWRITE in Step 1:** drive from build configuration / env-injected `Info.plist` keys. Treat the existing anon key as already-public; rotate during Step 1.

---

## DELETE

Items that should not be carried into the new repo at all.

- **`Super Duper Pros.zip`** (69 MB) — legacy archive at parent path, already excluded by virtue of the rename. Do not import.
- **Generated reports under `reports/daily/*.json`** — output, not source. Already gitignored.
- **`.DS_Store`** files throughout — macOS clutter. Now gitignored.
- **`dashboard/dist/`** — Vite build output. Now gitignored.
- **`workspace-cli/token.json`**, **`workspace-cli/client_secret.json`**, **`agents/tony_russo/config/token.json`**, **`agents/tony_russo/config/client_secret.json`** — OAuth secrets that were previously sitting unprotected. Now gitignored. These need to be re-issued during the v2 deployment, not copied into the new repo.
- **Any UI screenshot, copied layout file, or text file containing Workiz or CompanyCam UI copy** — none flagged in the inventory, but called out as a forbidden category going forward per spec rule 5 ("No copying").
- **`MARKETING-REPORT-superduperpros-com.pdf`** — marketing report, not source code. Belongs in Drive or a marketing folder, not the build repo.

---

## GAPS — spec requires, does not exist anywhere on disk

### iOS native features (Step 3)
- Camera capture with offline queue + background URLSession upload
- Voice notes with WhisperKit on-device transcription, Whisper API fallback
- AI walkthrough flow (audio + photos → structured doc + share token)
- Day Wrap (end-of-day generated log → Tony's Google Chat)
- StripeTerminal SDK for tap-to-pay
- Customer signature capture
- APNs push notification registration

### AI pipeline (Step 6)
- Photo captioning service (Haiku batch)
- Job Walkthrough generation (Sonnet)
- Day Wrap generation (Sonnet)
- Adjuster Packet (Sonnet, IICRC-formatted PDF for water/mold via MitiFlow, generic for others)
- Photo-to-Estimate (Sonnet vision, draft line items)
- Anomaly Detection (Haiku, every 30 min)
- `ai_pages` table + share-token public URLs + PDF export

### Agent API surface (Step 7)
- `Authorization: Bearer ag_xxx` token auth
- Anna endpoints: POST /jobs, PATCH /jobs/:id, POST /sms/send, POST /estimates, POST /invoices, GET /jobs/queue, POST /jobs/:id/photos/share
- Tony endpoints: POST /ai/anomaly-scan, GET /reports/daily, GET /reports/marketing, POST /ad-campaigns/*
- Vinny endpoints: GET /invoices?status=overdue, POST /qbo/sync, GET /reconciliation/unmatched, POST /reports/pl
- Approval tiers: AUTO_APPROVE / TONY_APPROVAL / CEO_APPROVAL enforced server-side

### Migration tooling (Step 8)
- `scripts/import-workiz.ts` — idempotent, dry-run mode, CSV-driven
- `scripts/import-companycam.ts` — preserves timestamps, GPS, captions; maps projects → jobs by address+date
- `scripts/seed-pricing.ts` — pricing book seed
- `scripts/promote-railway.ts` — failover trigger

### Test layer (per QA addendum)
- Playwright config with chromium / webkit / mobile-safari projects
- Custom reporters: google-chat-reporter, hermes-memory-reporter
- `tests/playwright/smoke/` — runs every 15 min against tunnel URL
- `tests/playwright/critical-path/` — runs on every PR (job-lifecycle, estimate-to-invoice, photo-upload, walkthrough-generation, sms-customer-thread, anna-creates-job, anomaly-detection, vinny-reconciliation)
- `tests/playwright/regression/` — runs nightly
- `tests/playwright/migration/` — runs once per migration batch
- `tests/playwright/pre-cutover/` — 7 consecutive green days gate
- `tests/playwright/failover/` — weekly drill
- `tests/playwright/ai-quality/` — structural + factual constraints, Haiku-as-judge
- XCUITest suite for iOS via `fastlane scan`

### Local hosting on M4 (Step 5 of section 5)
- pm2 ecosystem file (sdp-api, sdp-admin, sdp-workers, sdp-scheduler)
- docker-compose.yml for Redis container
- Cloudflare Tunnel config (`~/.cloudflared/config.yml`) routing `api.superduperpros.com` and `admin.superduperpros.com` to localhost
- Restic + Backblaze B2 nightly backup cron

### Failover (Railway warm standby)
- Railway project `sdp-heroes-failover` linked to this repo on `release` branch
- Cloudflare DNS health-check + automated flip on 3 consecutive M4 failures
- `pnpm tony:promote-railway` script

### Integrations (Step 5)
- Twilio: SMS send + inbound webhook
- Resend: transactional email
- Stripe: Payment Intents + Payment Links + Terminal + webhooks
- Meta Ads: Marketing API daily pull + lead webhook
- Google Ads: Ads API daily pull + call extension tracking
- Mercury: API transaction read + daily match
- Truss: API transaction read
- Plaid: Plaid Link + daily transaction pull (Chase + BofA)
- QuickBooks Online: full OAuth + sync module (existing script-only, needs proper service)

### Repo structure (Step 0 / spec section 6)
Spec calls for:
```
apps/api/    apps/admin/    apps/ios/
packages/shared-types/  packages/agent-sdk/
specs/01-schema.md  ...  specs/08-migration.md
scripts/  infra/{docker-compose.yml, pm2.ecosystem.json, cloudflared/, railway/}
```
None of this monorepo layout exists yet. Will be scaffolded at the start of Step 1 / `heroes-v2-rebuild`.

### Operational
- Heartbeat → Hermes every 15 min
- Self-healing rules (rerun migrations, restart pm2, retry AI jobs) before escalating
- Daily 7am PT digest to Google Chat #sdp-build (no `GOOGLE_CHAT_WEBHOOK_SDP_BUILD` in `.env` yet — needs creation)

---

## Secrets findings (defense-in-depth sweep)

Patterns scanned across the entire tree (excluding `node_modules`, `dist`, `__pycache__`, `.git`):

| Pattern class | Hits |
|---|---|
| AWS access keys (`AKIA*`) | 0 |
| GitHub tokens (`gh[psour]_*`) | 0 |
| `sk-` prefixed (OpenAI / Anthropic / Stripe) | 0 |
| Google API keys (`AIza*`) | 0 |
| Twilio `AC*` / `SK*` | 0 |
| Slack `xoxb-` / `xoxp-` | 0 |
| Bearer tokens in source files | 0 |
| Credential-pattern literals (`api_key/secret/password = "..."`) in source | 1 false positive (Keychain identifier `com.superduperpros.sdpheroes.accessToken`) |
| JWT (`eyJ*.*.* `) in source | **1 real finding** |
| Hex blobs (32/40/64 char) in source | 0 (excluding lock files / hashes) |
| Private key blocks (`BEGIN ... PRIVATE KEY`) | 0 |

**Real finding:** `SDPHeroes/SDPHeroes/Config/AppConfig.swift` lines 5-6 hardcode the Supabase project URL and anon JWT. Anon JWTs are rate-limited and RLS-enforced (lower severity than `service_role`), but they are anchored to a specific project and should not live in source.

**Action:**
1. The current `main` does NOT contain `AppConfig.swift` (only `.gitignore` + `README.md` are committed). No leak from this commit.
2. When iOS code is imported on `heroes-v2-rebuild` in Step 1, this file must be rewritten to read from build configuration (`Info.plist` injected at build time, or a non-committed `Config.local.swift`).
3. Treat the existing anon key as already-public; rotate during Step 1 by issuing a new anon key in the Supabase project (and update wherever the old one is in use).

**Pre-known credential files** now covered by hardened `.gitignore`: `workspace-cli/token.json`, `workspace-cli/client_secret.json`, `agents/tony_russo/config/token.json`, `agents/tony_russo/config/client_secret.json`, `dashboard/.env`, root `.env`. None of these files were ever committed; the hardened `.gitignore` ensures they cannot be added accidentally going forward.

---

## Recommendation

Proceed to Step 1 (Schema + Auth in Supabase) on a new branch `heroes-v2-rebuild`. In that branch:

1. Scaffold the monorepo per spec section 6 (`apps/{api,admin,ios}`, `packages/`, `specs/`, `scripts/`, `infra/`).
2. Selectively port KEEP items into their new homes (`agents/tony_russo/` → keep at root; `workspace-cli/` → `apps/api/src/integrations/google-chat/` or keep as-is; integration scripts → `scripts/`).
3. Write fresh Supabase migrations matching spec schema in `apps/api/src/db/migrations/`.
4. Apply the existing RLS hardening as a starting point but rebuild rules per spec.
5. Rotate the Supabase anon key called out in the secrets findings.
6. Open one PR per spec module per spec rule 3.

Existing on-disk code at `~/Desktop/sdp-heroes/` (untracked by git) stays as a reference until each module is ported or rewritten, then the on-disk-only files for that module can be removed.

---

## What's in this PR

This PR (`audit-day-0` → `main`) contains **only** `AUDIT.md`. No code, no schema, no scaffolding. Approving this PR signals that the audit decisions above are accepted and Step 1 may begin on a new `heroes-v2-rebuild` branch.
