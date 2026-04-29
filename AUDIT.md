# SDP Heroes — Day 0 Audit (revised)

**Date:** 2026-04-28
**Repo:** https://github.com/mrrixx210/SDP_heros_app
**Working path:** `~/Desktop/sdp-heroes/` (renamed from `~/Desktop/Co Work/Super Duper Pros/` during Step 0)
**Audited against:** `SDP_HEROES_BUILD.md` + `SDP_HEROES_PLAYWRIGHT_QA.md`
**Audited by:** Claude Code on Tony's M4 Mac Mini
**Revision:** v2, after peer review by production Tony agent (`AUDIT_REVIEW_FROM_TONY.md`)

---

## Summary

The local tree at `~/Desktop/sdp-heroes/` (~251 source files, ~24,500 LOC) is mostly working but spec-divergent. Major stacks (iOS, dashboard, backend) need rewrites. After peer review, most of the original "KEEP" list was duplicating code that already runs in production from a separate repo (`mrrixx210/sdp-tony-russo`). The revised audit drops that overlap so SDP Heroes does not become a second source of truth for Tony agent code.

The empty GitHub repo was seeded today with a minimal `main` (`.gitignore` + `README.md`). The 253 MB tree on disk is **not** in this repo. Step 1 (`heroes-v2-rebuild`) will scaffold the monorepo per spec section 6 and rebuild the field-service stack from spec, calling out to Tony's repo for any agent concerns.

---

## Boundary: SDP Heroes vs Tony Russo

Two repos, two responsibilities. Confirmed by Rick on 2026-04-28.

| Repo | Responsibility |
|---|---|
| `mrrixx210/SDP_heros_app` (this repo) | Field-service backend: customers, jobs, dispatch, estimates, invoices, payments, photos, AI walkthroughs, agent API surface |
| `mrrixx210/sdp-tony-russo` (separate) | Chief-of-Staff agent stack: Tony, Vinny, gchat listener, post-call enforcer, daily debrief, outreach, intake interviews |

Tony's repo CALLS endpoints in this repo. This repo does not embed Tony's code. Connectors, chat plumbing, and team-roster state live in Tony's repo and are accessed via either:
- HTTP endpoints Tony exposes (`POST /api/tony/...`), or
- A future shared package (`packages/google-chat-sdk/`, `packages/integrations/`, `packages/team-roster/`) that both repos consume — Phase 2 refactor, not Step 1.

---

## Decisions resolved before Step 1

**Q1: Tony code in v2.** Rick: drop all Tony code from sdp-heroes. Production Tony lives in its own repo. Step 7 (Agent API) builds endpoints Tony consumes; no Tony code is imported into this repo.

**Q2: Supabase project split.** Rick: provision a new Supabase project for SDP Heroes. Tony stays on the existing `svatqgizfqfgnlfugizw.supabase.co` project, untouched. The new project gets the spec schema fresh. iOS `AppConfig.swift` will be rewritten to point at the new project; the hardcoded anon key naturally retires (the project itself is replaced).

---

## Headline tensions vs spec

| Area | Existing | Spec | Decision |
|---|---|---|---|
| iOS auth | Bcrypt PIN + JWT | Supabase Auth | REWRITE |
| Admin panel framework | React 19 + Vite 6 | Next.js 14 App Router | REWRITE |
| Backend language/framework | Python 3.11 + FastAPI | Node + TypeScript + Fastify/Express | REWRITE |
| Schema breadth | jobs, gps, invoices (Tony's project) | + customers, estimates, ai_pages, sms_log, email_log, signatures, checklists, inventory, parts, sync_state — in a NEW Supabase project | REWRITE + GAPS |
| Scheduling backend | APScheduler in-process (in Tony's repo) | BullMQ + Redis | GAP (built fresh in this repo) |
| Test layer | None for product code | Playwright + XCUITest per QA addendum | GAP |
| Local hosting | Dockerfile + railway.toml only | pm2 + Cloudflare Tunnel + Docker Redis on M4, Railway as failover | GAP |
| Path | `Co Work/Super Duper Pros/` (space) | `sdp-heroes/` | RENAMED today |
| Tony agent code in this repo | Stale snapshot at `agents/tony_russo/` | Should not be here at all (separate repo) | DROP — see Comment 1 |

---

## KEEP (revised, narrowed)

These are SDP-product items that have no equivalent in Tony's repo and can be referenced (or rewritten in TS) during the v2 build.

### SDP marketing / SEO automation (no Tony equivalent)
- **`scripts/seo_data.py`** — services + cities reference data
- **`scripts/seo_content_engine.py`** — Claude Haiku content generator for SEO pages
- **`scripts/seo_page_generator.py`** — batch WordPress page creator
- **`scripts/seo_audit.py`** — WordPress coverage audit
- **`scripts/membership_campaign.py`** (799 LOC) — HVAC membership outreach pipeline with lead scoring
- **`scripts/wp_api.py`** — WordPress REST client (read + write)
- **`scripts/workers_comp_pl.py`** — regulatory P&L for workers comp audit (utility)

These get rewritten in TypeScript or kept as Python utilities under `scripts/` in the new monorepo. They are not Tony's responsibility.

### Reference data
- **`.env.template`** — 76 keys, partial alignment with spec section 9. Will be the starting point for the new repo's `.env.example`. Several keys (Workiz, CompanyCam, QBO) will be removed since SDP Heroes doesn't talk to those directly — Tony does. Sendblue (Comment 6), Plaid Chase + BofA, Mercury, Truss, Twilio, Resend, Stripe, Meta, Google Ads need to be added per spec.

### Specs
- **`SDP_HEROES_BUILD.md`**, **`SDP_HEROES_PLAYWRIGHT_QA.md`** — source specs. Get split into `specs/01-schema.md` ... `specs/08-migration.md` per spec section 6 during Step 1 scaffolding.

### Operational docs (historical reference only, supersede during build)
- **`STATUS.md`**, **`MISSION_CONTROL.md`** — describe the *old* combined system. Read once for context, then supersede with new docs as v2 modules ship.
- **`agents/operations_agent.md`**, **`agents/marketing_agent.md`**, **`agents/finance_agent.md`** — design references for thinking about Step 7 agent API surface, but the agents themselves are not in this repo.

---

## DROP — lives in Tony's repo, do not import

Per Q1: drop all Tony code from sdp-heroes.

| Local artifact | Canonical location | Notes |
|---|---|---|
| `agents/tony_russo/` | `mrrixx210/sdp-tony-russo` (entire repo) | Stale snapshot; production has months of fixes (durable baseline restore, DM enforcer, natural-DM compose, post-call enforcer, Vinny QBO categorizer). Comment 1. |
| `agents/` (top-level dir) | n/a | Do not include `agents/` in the v2 monorepo at all. Comment 1. |
| `workspace-cli/` | `~/Code/Tony/skills/chat_dm.py` + `~/Code/Tony/skills/gchat_listener.py` | Production has natural-DM compose flow, thread.name propagation, sender-name filtering, anti-hallucination guard. Comment 3. Polling-rate conflict (10s vs 30s) resolved in favor of the 30s production listener. Comment 4. |
| `scripts/workiz_api.py` | `~/Code/Tony/connectors/workiz.py` | Tony's connector is canonical. For Step 8 import-workiz.ts, rewrite fresh in TS or factor into shared package. Comment 10. |
| `scripts/workiz_api_full.py` | same | Same. |
| `scripts/workiz_reconciler.py` | same + `~/Code/Tony/skills/vinny/reconcile.py` | Same. |
| `scripts/companycam_api.py` | `~/Code/Tony/connectors/companycam.py` | Comment 10. |
| `scripts/quickbooks_api.py` | `~/Code/Tony/connectors/quickbooks.py` + `~/Code/Tony/skills/vinny/qbo.py` | Live realm-id 9341452947539582 already wired in Tony. Comment 10. |
| `scripts/bank_statement_parser.py` | `~/Code/Tony/skills/vinny/ingest.py` | Tony's Vinny owns reconciliation. |
| `scripts/reconciliation_engine.py` | `~/Code/Tony/skills/vinny/reconcile.py` | Same. |
| `scripts/daily_report.py` | `~/Code/Tony/skills/daily_debrief.py` + `daily_earnings_report.py` | Tony owns daily ops digests. |
| `scripts/export_report.py` | `~/Code/Tony/skills/call_digest.py` (similar pattern) | Same. |
| `scripts/google_drive_watcher.py` | Tony has bank-ingest equivalents | Same. |
| `config/company_profile.md` | `~/Code/Tony/state/team.json` | Tony's `state/team.json` has Workiz IDs + canonical phone numbers + DM space IDs. Two sources guarantee drift. Comment 8. SDP Heroes API reads via shared `packages/team-roster/` (Phase 2) or HTTP from Tony. |
| `supabase/008_tony_russo_tables.sql` | Tony's existing Supabase project | Stay on `svatqgizfqfgnlfugizw`. Do not copy to the new SDP Heroes project. Comment 5. |
| `supabase/sdp_mission_control.sql` | Tony's existing Supabase project | Same. |
| `supabase/009_approval_queue.sql` | Tony's existing Supabase project | Same. The new SDP Heroes project may have its own approval queue if needed for the field-service approval tiers (AUTO / TONY / CEO), but that's a fresh table on the new project. |

---

## REWRITE

These exist locally but the existing implementation does not match spec. Code on disk is reference material; new implementation goes into the new repo structure.

### iOS app — `SDPHeroes/`
Existing: 84 Swift files / ~2,100 LOC. SwiftUI ✓. Supabase Swift SDK ✓. CoreLocation GPS tracking ✓. Models for Job / Invoice / Employee / Schedule / Warranty / Announcement. Views for Login / Today / JobList / JobDetail / DispatchBoard / EmployeeList / Invoice / PriceBook / Margin / Warranty / Settings.

Spec divergence:
- Auth is bcrypt PIN + custom JWT — **spec wants Supabase Auth.** Rebuild against new Supabase project's Auth.
- Hardcoded Supabase URL + anon JWT in `AppConfig.swift:5-6` — superseded by new project entirely (per Q2). New project = new keys. Old key retires.
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
Existing: React 19 + Vite 6 + TypeScript 5.8 + Tailwind 4. 10 pages. TonyChatWidget. Supabase client. TanStack Query. Recharts. ESLint + TS strict.

Spec divergence:
- **Framework: Vite + React → spec wants Next.js 14 App Router.** Server components, server actions, file-based routing.
- Missing shadcn/ui, TanStack Table, Realtime subscriptions on dispatch board, approval queue UI, customer SMS reply toasts + thread view.
- Missing CompanyCam-replacement photo gallery with share-token gating.

Approach: full rewrite at `apps/admin/`. Keep page list as a starting point. TonyChatWidget calls Tony's HTTP endpoints (no embedded agent code).

### Backend — `backend/`
Existing: Python 3.11 + FastAPI + APScheduler. 8 agents registered. Workiz webhook receiver. Supabase sync. NeMo guardrails wrapper.

Spec divergence:
- **Stack mismatch: Python/FastAPI → Node + TypeScript + Fastify or Express.**
- **Background jobs: APScheduler → BullMQ + Redis (Docker on M4).**
- Missing all `/api/v1/` endpoints per spec section 4.
- Missing agent API surface (Anna, Tony, Vinny endpoints) with bearer-token auth and tiered approvals.
- Missing Twilio SMS, Resend email, Stripe webhook handling.
- The 8 in-process agents in this codebase are the OLD design. The new design is: Tony's repo runs the agents; SDP Heroes exposes endpoints they call.

Approach: full rewrite at `apps/api/` per spec. The Workiz HMAC verification logic is reusable as reference but the connector itself comes from Tony's repo (HTTP or shared package).

### Supabase schema (new project)
Existing migrations on the OLD shared project (Tony's project, do not touch):
- `003_field_service_tables.sql` — jobs, gps_tracking, invoices, schedules
- `004_hash_pins.sql`, `005_harden_rls.sql`, `006_workiz_qbo_sync.sql`, `007_reconciliation_tables.sql` — historical, stay where they are

Per Q2: a NEW Supabase project for SDP Heroes gets a fresh schema written under `apps/api/src/db/migrations/` matching spec section 4 verbatim:
- `tech_users`, `admin_users`, `agent_users`
- `customers` (top-level, not embedded in jobs)
- `jobs`, `job_status_log`, `job_tags`
- `estimates`, `invoices`, `payments`
- `job_photos`, `job_notes`, `job_signatures`, `job_checklists`
- `ai_pages`, `ai_jobs_queue`
- `sms_log`, `email_log`
- `inventory_items`, `job_parts_used`
- `sync_state`

RLS rules per spec: techs see only assigned jobs, admins see everything, agents scoped per role.

---

## DELETE

- **`Super Duper Pros.zip`** (69 MB) — legacy archive, do not import.
- **`reports/daily/*.json`** — generated, gitignored.
- **`.DS_Store`** files throughout — gitignored.
- **`dashboard/dist/`** — Vite build output, gitignored.
- **`workspace-cli/token.json`**, **`workspace-cli/client_secret.json`**, **`agents/tony_russo/config/token.json`**, **`agents/tony_russo/config/client_secret.json`** — OAuth secrets. Now gitignored. Re-issue during v2 deployment, do not copy.
- **Any UI screenshot or copied layout from Workiz / CompanyCam** — none flagged in inventory but called out as forbidden per spec rule 5.
- **`MARKETING-REPORT-superduperpros-com.pdf`** — marketing artifact, belongs in Drive, not the build repo.

---

## GAPS — spec requires, does not exist

### iOS native features (Step 3)
- Camera capture with offline queue + background URLSession upload
- Voice notes with WhisperKit on-device transcription, Whisper API fallback
- AI walkthrough flow (audio + photos → structured doc + share token)
- Day Wrap (end-of-day generated log → posted to principals' Google Chat space via Tony's HTTP endpoint, not directly)
- StripeTerminal SDK for tap-to-pay
- Customer signature capture
- APNs push notification registration

### AI pipeline (Step 6)
- Photo captioning (Haiku batch)
- Job Walkthrough generation (Sonnet)
- Day Wrap generation (Sonnet)
- Adjuster Packet (Sonnet, IICRC-formatted PDF for water/mold via MitiFlow, generic for others)
- Photo-to-Estimate (Sonnet vision, draft line items)
- Anomaly Detection (Haiku, every 30 min)
- `ai_pages` table + share-token public URLs + PDF export

### Agent API surface (Step 7) — endpoints Tony's repo CALLS
- `Authorization: Bearer ag_xxx` token auth, `agent_users` table for key hashes
- **Anna endpoints** (Comment 7 — bidirectional): POST /jobs, PATCH /jobs/:id, POST /sms/send, POST /estimates, POST /invoices, GET /jobs/queue, POST /jobs/:id/photos/share, **plus**:
  - Inbound webhook receiver: ElevenLabs `call-start` → caller-continuity context loader (recent calls, ISO 9001 lookup)
  - Inbound webhook receiver: ElevenLabs `call-end` → post-call enforcer trigger (verifies verbal commitments fired tools)
  - GET endpoint: post-call audit query (returns transcript_summary + tool_calls fired + commitments detected)
  - POST endpoint: QA digest write (17:30 PT daily rollup to Office channel)
- **Tony endpoints**: POST /ai/anomaly-scan, GET /reports/daily, GET /reports/marketing, POST /ad-campaigns/*
- **Vinny endpoints**: GET /invoices?status=overdue, POST /qbo/sync, GET /reconciliation/unmatched, POST /reports/pl
- Approval tiers: AUTO_APPROVE / TONY_APPROVAL / CEO_APPROVAL enforced server-side. Tony's `office_approval_listener.py` is the consumer; SDP Heroes is the producer.
- Reference patterns from Tony's repo: `webapp/backend/routers/meet_bridge.py`, `skills/post_enforcer.py`

### Migration tooling (Step 8)
- `scripts/import-workiz.ts` — idempotent, dry-run, CSV-driven, rewritten fresh in TypeScript per spec
- `scripts/import-companycam.ts` — preserves timestamps, GPS, captions, maps projects → jobs by address+date
- `scripts/seed-pricing.ts`
- `scripts/promote-railway.ts` — failover trigger
- (Reference Tony's `connectors/workiz.py` and `connectors/companycam.py` for behavior contracts. Do NOT port the Python; rewrite to TS.)

### Test layer (per QA addendum)
- Playwright config: chromium / webkit / mobile-safari projects
- Custom reporters: google-chat-reporter, hermes-memory-reporter
- `tests/playwright/{smoke,critical-path,regression,migration,pre-cutover,failover,ai-quality}/`
- XCUITest suite via `fastlane scan`

### Local hosting on M4 (spec section 5)
- pm2 ecosystem file (sdp-api, sdp-admin, sdp-workers, sdp-scheduler)
- docker-compose.yml for Redis container
- Cloudflare Tunnel: `api.superduperpros.com` and `admin.superduperpros.com` as **separate cloudflared services with their own launchd plists**, NOT consolidated into a single instance, so a misconfig of one cannot kill Tony's existing `tony.superduperpros.com` tunnel. Comment 9. Pattern:
  ```
  ~/Library/LaunchAgents/com.sdp.tony.tunnel.plist     (existing — DO NOT MODIFY)
  ~/Library/LaunchAgents/com.sdp.heroes.api.tunnel.plist     (new)
  ~/Library/LaunchAgents/com.sdp.heroes.admin.tunnel.plist   (new)
  ```
- Restic + Backblaze B2 nightly backup cron

### Failover (Railway warm standby)
- Railway project `sdp-heroes-failover` linked to this repo on `release` branch
- Cloudflare DNS health-check + automated flip on 3 consecutive M4 failures
- `pnpm tony:promote-railway` script

### Integrations (Step 5) — including Sendblue (Comment 6)
- **Twilio**: SMS send + inbound webhook (legacy SMS path)
- **Sendblue**: iMessage / SMS for Anna's customer-initiated install funnel (window AC, water heater, mini-split via click-to-SMS). Account currently being reactivated. API surface needed:
  - Inbound webhook: customer message → conversation handler
  - Outbound API: agent-generated reply
  - iMessage detection (blue vs green bubble routing)
  - Tony's `connectors/sendblue.py` is reference; SDP Heroes implements its own TS version for the field-service flow
- **Resend**: transactional email
- **Stripe**: Payment Intents + Payment Links + Terminal + webhooks
- **Meta Ads**: Marketing API daily pull + lead webhook
- **Google Ads**: Ads API daily pull + call extension tracking
- **Mercury**: API transaction read + daily match (Tony's Vinny owns; SDP Heroes API just exposes the data write endpoint Tony posts to)
- **Truss**: same pattern as Mercury
- **Plaid**: Plaid Link + daily transaction pull (Chase + BofA), same pattern
- **QuickBooks Online**: full OAuth + sync. Tony's `skills/vinny/qbo.py` already has this with live realm-id 9341452947539582. SDP Heroes API exposes the data endpoints; Tony does the QBO talking.

### Repo structure (Step 0 / spec section 6, narrowed)
Spec calls for:
```
apps/api/    apps/admin/    apps/ios/
packages/shared-types/  packages/agent-sdk/
specs/01-schema.md  ...  specs/08-migration.md
scripts/  infra/{docker-compose.yml, pm2.ecosystem.json, cloudflared/, railway/}
```
Note: NO `agents/` dir at top level (Comment 1). Future `packages/google-chat-sdk/`, `packages/integrations/`, `packages/team-roster/` are Phase 2 refactors that let Tony's repo and this repo share code without duplication; not in Step 1.

### Operational
- Heartbeat → Hermes every 15 min
- Self-healing rules (rerun migrations, restart pm2, retry AI jobs) before escalating
- Daily 7am PT digest to Google Chat #sdp-build (`GOOGLE_CHAT_WEBHOOK_SDP_BUILD` not in `.env` — needs creation)

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
| Bearer tokens in source | 0 |
| Credential-pattern literals in source | 1 false positive (Keychain identifier) |
| JWT (`eyJ*.*.* `) in source | **1 real finding** |
| Hex blobs (32/40/64 char) in source | 0 (excluding lock files) |
| Private key blocks | 0 |

**Real finding:** `SDPHeroes/SDPHeroes/Config/AppConfig.swift:5-6` hardcodes the Supabase project URL (`svatqgizfqfgnlfugizw.supabase.co`) and anon JWT.

**Cross-project finding:** That same project URL is used by both `~/Desktop/sdp-heroes/.env` AND `~/Code/Tony/.env` AND iOS `AppConfig.swift`. There is no SDP/Tony separation today — all three contexts share one Supabase project.

**Resolution (per Q2):** SDP Heroes provisions a NEW Supabase project. Tony stays on `svatqgizfqfgnlfugizw` untouched. The hardcoded anon key in AppConfig.swift becomes irrelevant during the iOS rewrite (new project = new keys, old project remains valid for Tony but unused by SDP Heroes). This is cleaner than rotating a key inside the existing project because it also separates the data plane.

**Pre-known credential files** now covered by hardened `.gitignore`: `workspace-cli/token.json`, `workspace-cli/client_secret.json`, `agents/tony_russo/config/token.json`, `agents/tony_russo/config/client_secret.json`, `dashboard/.env`, root `.env`. None were ever committed; the hardened gitignore prevents accidental adds going forward.

---

## Review responses (Comments 1–10 from Tony's review)

| # | Severity | Topic | Disposition |
|---|---|---|---|
| 1 | Critical | `agents/tony_russo/` is stale, drop from rebuild | **Accepted.** Drop entirely. No `agents/` dir in v2 monorepo. Q1 confirms. |
| 2 | Material | Tony reports to principals directly, not through Alfred | **Accepted.** Removed the "reports to Alfred only" framing throughout. Step 7 thinks about Tony's audience as principals (Rick, Marie Alice, Alfred) as peers. |
| 3 | Material | `workspace-cli/` duplicates Tony's `chat_dm.py` + `gchat_listener.py` | **Accepted.** Drop `workspace-cli/`. Step 7 chat integration uses Tony's existing endpoints or a future shared `packages/google-chat-sdk/`. |
| 4 | Material | Polling-rate conflict (10s vs 30s) | **Accepted.** Resolved by Comment 3: dropping workspace-cli eliminates the second poller. Tony's 30s listener wins (battle-tested, has natural-DM compose, thread propagation, sender-name filtering, anti-hallucination guard). |
| 5 | Critical | Supabase project separation | **Accepted.** Q2 confirms. NEW Supabase project for SDP Heroes; Tony's tables stay on `svatqgizfqfgnlfugizw` untouched. |
| 6 | Material | Sendblue missing from Step 5 integrations | **Accepted.** Added to Step 5 GAPS section with the bidirectional surface (inbound webhook, outbound API, iMessage detection). |
| 7 | Material | Anna agent endpoints missing | **Accepted.** Added the four bidirectional endpoints to Step 7 GAPS (call-start hook, call-end hook, audit query, QA digest write). |
| 8 | Minor | `config/company_profile.md` duplicates `state/team.json` | **Accepted.** Drop `config/company_profile.md` from KEEP. Tony's `state/team.json` is canonical. SDP Heroes reads via shared package or HTTP from Tony in Phase 2. |
| 9 | Minor | Cloudflare Tunnel coordination | **Accepted.** GAPS section now specifies three SEPARATE cloudflared services with their own launchd plists; DO NOT MODIFY the existing `com.sdp.tony.tunnel.plist`. |
| 10 | Material | Tony's connectors are canonical | **Accepted.** Connector scripts moved from KEEP to DROP. Step 8 import scripts get rewritten fresh in TypeScript; Tony's connectors are reference for behavior contracts only. |

---

## Recommendation

Proceed to Step 1 (Schema + Auth) on a new branch `heroes-v2-rebuild`. In that branch:

1. Provision the new Supabase project for SDP Heroes (per Q2). Capture URL + keys in a non-committed `.env`.
2. Rewrite iOS `AppConfig.swift` to read from build configuration (Info.plist injection).
3. Scaffold the monorepo per spec section 6: `apps/{api,admin,ios}`, `packages/`, `specs/`, `scripts/`, `infra/`. **No `agents/` dir.**
4. Carry forward only the SDP-product items in the revised KEEP section. Reference Tony's repo for connector behavior contracts; do not import code.
5. Write fresh Supabase migrations matching spec section 4 verbatim against the new project.
6. Build new Cloudflare Tunnel services as separate launchd plists; do not touch Tony's existing tunnel.
7. Open one PR per spec module per spec rule 3.

The existing on-disk code at `~/Desktop/sdp-heroes/` (untracked by git) stays as a reference until each module is rewritten, then gets removed.

---

## What's in this PR

This PR (`audit-day-0` → `main`) contains only the audit (revised). No code, no schema, no scaffolding. Approving signals:
- The KEEP / DROP / REWRITE / GAPS calls are accepted
- The two-repo boundary (SDP Heroes vs Tony Russo) is accepted
- Q1 (drop all Tony code) and Q2 (new Supabase project) decisions are accepted
- Step 1 may begin on a new `heroes-v2-rebuild` branch
