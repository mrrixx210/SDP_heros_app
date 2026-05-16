# CLAUDE.md ... SDP Heroes v2 build context

> **Read this first.** Then read `AUDIT.md` (boundary doc) and `SDP_HEROES_BUILD.md` (the spec). Don't start coding without those.

## What this repo is

SDP Heroes v2 is the field-service backend + iOS field app + admin panel + agent API surface that **replaces Workiz** for Super Duper Pros.

Workiz costs SDP $1,500/month. This repo's existence is the business case.

## What this repo is NOT

- **NOT** a Tony agent codebase. Tony lives in `mrrixx210/sdp-tony-russo` and runs on Hetzner. Tony CALLS endpoints in this repo over HTTP. Do NOT embed Tony's Python here. Do NOT add an `agents/` directory at the root.
- **NOT** a Workiz UI clone. Copying their visual design is copyright infringement. We clone the **functional workflows** (job board, dispatch view, customer card, estimate builder ... category-standard) but every visual decision is fresh: SDP brand, our component library, our copy.
- **NOT** a port of the legacy code in this folder's untracked tree. Per `AUDIT.md`, that code stays as reference but does not get pulled into the new build wholesale.

## Standing rules (hard, enforced in code review)

- **No em dashes** anywhere ... copy, code, UI, SMS, email, PDF. Use `...`, commas, periods, or parens.
- **No copy/paste from Workiz or CompanyCam UI / code / layout.** Build from spec only.
- **Secrets via env vars only.** Never committed. `.gitignore` already hardened.
- **One PR per spec module.** Tests required before merge.
- **Tony's Supabase project (`svatqgizfqfgnlfugizw`) is OFF-LIMITS.** SDP Heroes uses a NEW Supabase project (`sdp-heroes-prod`).
- **iOS Supabase anon key MUST be rotated** as part of the AppConfig rewrite. The legacy key from the old codebase is treated as compromised.
- **Cloudflare Tunnels:** create SEPARATE launchd plists at `infra/cloudflared/com.sdp.heroes.*.plist`. Do NOT touch `~/Library/LaunchAgents/com.sdp.tony.tunnel.plist`.
- **No "on behalf of" tags** in messages. Tony writes in first person; same applies to system messages this codebase produces.

## Two-repo boundary

| Repo | Owner | What it does |
|---|---|---|
| `mrrixx210/SDP_heros_app` (this) | M4 Claude session | Field-service backend, admin panel, iOS app, agent API surface |
| `mrrixx210/sdp-tony-russo` | i5 Claude session, deploys to Hetzner | Chief-of-Staff agent stack: Tony, Vinny, gchat listener, post-call enforcer, daily debrief, outreach |

This repo's `apps/api/src/integrations/{qbo,stripe,meta,google,mercury,truss,plaid,sendblue,twilio,resend}/` directories are TypeScript rewrites of behavior contracts found at `~/Code/Tony/connectors/` (read-only reference). Don't import the Python; reproduce the contract in TS.

## Stack (locked Step 1)

- **Backend (`apps/api/`):** Node 20 + TypeScript 5.8 (strict) + Fastify + @supabase/supabase-js + Zod + BullMQ + Redis
- **Admin panel (`apps/admin/`):** Next.js 14 App Router + Tailwind 4 + shadcn/ui + TanStack Query + TanStack Table + Recharts
- **iOS app (`apps/ios/`):** SwiftUI + iOS 17+ + Supabase Swift SDK + xcconfig-based env injection (Debug + Release)
- **Shared (`packages/`):** `shared-types` (Zod schemas + TS types), `agent-sdk` (Step 7 client lib stub)
- **Tooling:** pnpm workspaces (no Turbo for now), Playwright for QA, GitHub Actions for CI

## Where the spec lives

- `SDP_HEROES_BUILD.md` ... full build spec, sections 1-8
- `SDP_HEROES_PLAYWRIGHT_QA.md` ... QA + smoke test strategy
- `AUDIT.md` ... Day 0 audit (kept-vs-dropped list)
- `AUDIT_REVIEW_FROM_TONY.md` ... peer review of audit
- `HANDOFF_STEP_1.md` ... per-step handoff notes
- `specs/01-schema.md` through `08-migration.md` ... extracted per-module specs

## How Tony interacts with this repo at runtime

Once Step 7 lands the agent API surface:

1. Tony has a row in `agent_users` table with a hashed bearer token.
2. Tony's Python code calls `https://api.superduperpros.com/api/agent/...` with `Authorization: Bearer ag_xxx`.
3. The Heroes API checks the hash, scopes the request to Tony's permissions, and returns JSON.
4. Tony's voice agent (ElevenLabs) likewise calls the agent surface for `book_job`, `send_estimate`, `pull_company_cam_photos`, etc.

This repo never imports Tony. Tony never imports this repo. They communicate over HTTP only.
