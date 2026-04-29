# Peer Review of AUDIT.md ... from Tony (M4 production agent)

**Reviewed by:** Tony Russo (Claude Code on M4, the SDP production agent stack)
**Reviewed against:** `~/Desktop/sdp-heroes/AUDIT.md` (Day 0 audit by Claude Code in VS)
**Date:** 2026-04-28
**Disposition:** Audit framework is solid. 10 issues to address before Step 1 scaffolding begins. None are blockers, all are coordination concerns that prevent duplication of production infrastructure.

---

## Critical context the audit is missing

Tony Russo (the SDP Chief of Staff agent) ALREADY runs in production from a SEPARATE repo at `mrrixx210/sdp-tony-russo`, locally at `~/Code/Tony/`. The local copy at `~/Desktop/sdp-heroes/agents/tony_russo/` is STALE and should not be treated as canonical. Several "KEEP" items in the audit duplicate code that's already shipped, deployed, and battle-tested in the production Tony repo. Carrying them into sdp-heroes would mean two sources of truth for the same logic.

Recommendation: SDP Heroes does NOT contain the Tony agent code. SDP Heroes is the FIELD SERVICE BACKEND that Tony's agent calls. Two repos, two responsibilities.

---

## Comments by section

### Comment 1 (Critical) ... agents/tony_russo is stale, drop from rebuild

AUDIT.md line 39 marks `agents/tony_russo/` as KEEP. Reality:
- Production Tony runs from `~/Code/Tony/` and `mrrixx210/sdp-tony-russo`
- The local copy at `~/Desktop/sdp-heroes/agents/tony_russo/` is a snapshot from an earlier build, missing months of production fixes (durable agent baseline restore, DM enforcer, natural-DM compose flow, Vinny QBO categorizer, post-call enforcer, etc.)
- Carrying the stale copy forward into sdp-heroes creates two sources of truth and guarantees drift

**Action for Step 1 scaffolding:**
- Do NOT carry `agents/tony_russo/` into the new monorepo
- Do NOT include `agents/` as a top-level monorepo directory
- Step 7 (Agent API surface) builds endpoints that Tony CONSUMES; Tony's agent code stays in its own repo
- Tony's repo will pin against this repo's API contract via `packages/shared-types/` once that's published

### Comment 2 (Material) ... Tony reports to principals directly, not through Alfred

AUDIT.md line 39: "Reports up the chain to Alfred (never directly to Rick)."

Wrong. Per Tony's current `CLAUDE.md` (in his production repo), he was promoted to Chief of Staff and reports DIRECTLY to principals (Rick Belmont, Marie Alice Belmont, Alfred) as peers. The "Alfred-only" routing is legacy from an earlier architecture.

**Action:** rewrite that line in AUDIT.md before merge. Affects how Step 7 thinks about who consumes Tony's output (it's the principals' Google Chat space, not Alfred specifically).

### Comment 3 (Material) ... workspace-cli is already done in Tony's repo

AUDIT.md line 43 marks `workspace-cli/` as KEEP for Step 7 plumbing. But Tony's production repo already has:
- `skills/chat_dm.py` ... send_dm, list_messages, download_attachment_bytes
- `skills/gchat_listener.py` ... 30s poller with intent detection, threaded replies, natural-DM compose, anti-hallucination guard, sender filtering

These are battle-tested, fixed many times, and currently running. workspace-cli's outbound poster + 10-second inbound listener duplicates this and creates conflict.

**Action:**
- Drop workspace-cli from the v2 rebuild
- Step 7 chat integration uses Tony's existing endpoints (e.g., `POST /api/tony/outbound/gchat`) OR factor Tony's chat code into a shared package both repos consume
- Recommend the shared-package path: `packages/google-chat-sdk/` ... but this is a Phase 2 refactor, not Step 1

### Comment 4 (Material) ... polling rate conflict

Workspace-cli polls every 10 seconds. Tony's gchat_listener polls every 30 seconds. If both run simultaneously against the same Chat spaces, that's 40 API hits/min/space. Risk of Google Chat rate-limit during volume spikes (e.g., a busy plumbing morning).

**Action:** related to Comment 3. Pick ONE poller. Recommend Tony's existing 30s listener wins because:
- Already has natural-DM compose flow
- Already has thread.name propagation (fixed 2026-04-27 after Altagracia estimate routing bug)
- Already filters by message-name (fixed 2026-04-28 after trusso@ identity overlap bug)
- Has anti-hallucination guard for the post-DM commitment failure mode
- Battle-tested across hundreds of conversations

### Comment 5 (Critical) ... Supabase project separation

AUDIT.md line 63 marks `008_tony_russo_tables.sql` and `009_approval_queue.sql` as KEEP, implying they live in the same Supabase project as the rest of SDP Heroes.

This violates the SDP separation rule documented in Tony's memory (`sdp_separation.md`). SDP infrastructure must live in SDP-owned accounts, never mixed with personal or other portfolio companies. Tony's data and SDP Heroes data are different layers and should be in different Supabase projects so:
- Either layer can be sold/separated independently
- A breach of one layer doesn't auto-leak the other
- RLS rules don't have to coexist across competing data models

**Action for Step 1:**
- Provision a NEW Supabase project for SDP Heroes (separate from Tony's project)
- Tony's tables stay in Tony's project, untouched
- The new project's schema is built fresh per the spec, not migrated from Tony's

This also resolves the iOS anon-key rotation noted in AUDIT.md line 145 cleanly: rotating means a fresh project entirely, not just a key rotation.

### Comment 6 (Material) ... Sendblue missing from Step 5 integrations

AUDIT.md line 219-228 lists Step 5 integrations but doesn't include Sendblue. Sendblue is the iMessage / SMS provider for Anna's customer-initiated install funnel (window AC, water heater, mini-split via click-to-SMS). Already in flight, account currently being reactivated.

**Action:** add Sendblue to the Step 5 integrations list. API surface needed:
- Inbound webhook: customer message → conversation handler
- Outbound API: agent-generated reply
- iMessage detection (blue vs green bubble routing)

### Comment 7 (Material) ... Anna agent endpoints missing from Step 7

AUDIT.md line 184-186 lists Anna's job/SMS/estimate endpoints but doesn't address the BIDIRECTIONAL surface Anna needs. Anna runs as an ElevenLabs voice agent on i5 (NOT the M4 backend) and needs:
- Webhook receiver: ElevenLabs call-start hook → context loader (caller continuity, ISO 9001 lookup of recent calls)
- Webhook receiver: ElevenLabs call-end hook → post-call enforcer trigger (verifies all verbal commitments fired actual tools)
- Endpoint: post-call audit query (returns transcript_summary + tool_calls fired + commitments detected)
- Endpoint: QA digest write (17:30 PT daily rollup to Office channel)

**Action:** add Anna webhook + audit endpoints to Step 7. Reference Tony's existing `webapp/backend/routers/meet_bridge.py` and `skills/post_enforcer.py` for the pattern; the new SDP Heroes API can implement equivalent.

### Comment 8 (Minor) ... config/company_profile.md duplicates state/team.json

AUDIT.md line 46 marks `config/company_profile.md` as KEEP for team roster + Workiz IDs + pricing. Tony's repo has `state/team.json` doing the same thing.

**Action:** pick ONE canonical source. Recommend Tony's `state/team.json` because:
- It's already wired into Tony's runtime (skills query it constantly)
- It has the canonical phone numbers + DM space IDs in addition to Workiz IDs
- Updating two places guarantees drift

If SDP Heroes API needs the same data, it reads from a shared `packages/team-roster/` that wraps team.json (or fetches via Tony's HTTP endpoint).

### Comment 9 (Minor) ... Cloudflare tunnel coordination

AUDIT.md line 211 calls for `api.superduperpros.com` and `admin.superduperpros.com` Cloudflare Tunnel routes. Tony already runs `tony.superduperpros.com` from M4 via launchd-managed cloudflared.

**Action:** confirm new tunnels are configured as SEPARATE cloudflared services with their own launchd plists, so a misconfig of one doesn't kill Tony's production tunnel. Don't try to consolidate into a single cloudflared instance routing all three subdomains.

Pattern to follow:
```
~/Library/LaunchAgents/com.sdp.tony.tunnel.plist     (existing, do not modify)
~/Library/LaunchAgents/com.sdp.heroes.api.tunnel.plist     (new)
~/Library/LaunchAgents/com.sdp.heroes.admin.tunnel.plist   (new)
```

### Comment 10 (Material) ... existing Tony Workiz/CompanyCam connectors are the canonical source

AUDIT.md lines 50-54 mark `scripts/workiz_api.py`, `scripts/companycam_api.py`, `scripts/quickbooks_api.py` as KEEP, will inform `import-workiz.ts` etc.

These already exist as production-tested clients in Tony's repo at:
- `~/Code/Tony/connectors/workiz.py`
- `~/Code/Tony/connectors/companycam.py`
- `~/Code/Tony/connectors/quickbooks.py`
- `~/Code/Tony/skills/vinny/qbo.py` (production QBO with full OAuth, refresh token, and live realm-id 9341452947539582)

The local snapshots are again stale.

**Action for Step 8 migration tooling:**
- Reference Tony's production connectors for behavior contracts
- Don't port the Python locally; either rewrite to TypeScript fresh per spec, or factor into a shared `packages/integrations/` that both repos consume
- Recommend the rewrite-to-TypeScript path for Step 8 since the spec wants a Node API stack anyway

---

## Two questions for Rick before Step 1 starts

These need explicit Rick approval before scaffolding because they shift the scope of the v2 rebuild:

**Q1.** Should sdp-heroes carry any Tony-related code (agents/tony_russo, workspace-cli, Tony's connector scripts, Tony's Supabase tables), or drop ALL of them entirely? Tony stays in his own repo at mrrixx210/sdp-tony-russo, SDP Heroes provides API endpoints Tony CALLS.

**Recommendation: drop all Tony code from sdp-heroes.**

**Q2.** Should sdp-heroes provision a NEW Supabase project, or reuse Tony's existing one?

**Recommendation: new Supabase project. Per SDP separation rule. Cleaner data model, cleaner separation, cleaner sale story when SDP exits.**

If Rick approves both: the audit's KEEP section shrinks substantially (just `.env.template` patterns and Step 6/7/8 reference docs), the REWRITE section is unaffected, and Step 1 scaffolding starts from a cleaner monorepo without `agents/` or duplicate connectors.

---

## What's strong about the audit (to preserve)

- KEEP/REWRITE/DELETE/GAPS framework is the right structure for a Day 0 audit
- Secrets sweep methodology is thorough and the JWT finding (AppConfig.swift line 5-6) is exactly the kind of thing that needs flagging
- Stack divergence table at the top (line 21-31) is honest and captures the real cost of the rebuild
- Recognizing iOS UI primitives are reusable while the auth layer is not is correct
- Recommendation to scaffold the monorepo per spec section 6 BEFORE selectively porting is correct order of operations

These structural decisions hold even after the 10 comments above land.

---

## What's next

The other Claude session reads this file, addresses each comment in AUDIT.md (or appends rationale for keeping the original decision), then asks Rick the two open questions Q1/Q2 before scaffolding `heroes-v2-rebuild`. The audit_day_0 PR can either:
- Wait for the comments to be addressed and merge a clean v2 audit, OR
- Merge as-is with these comments archived as a "follow-up actions" appendix

Either path is fine; the comments above are the substance.

Tony out.
