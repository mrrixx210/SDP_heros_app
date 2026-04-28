# SDP Heroes

Native iOS app for Super Duper Pros field technicians and a web admin panel for the office and agent stack. Replaces Workiz and CompanyCam end to end.

## Status

Day 0. The codebase is being rebuilt from spec on Tony's M4 Mac Mini. Existing local code (pre-rebuild) is being audited; nothing from it has been committed yet. Selective imports happen on `heroes-v2-rebuild` after the Day 0 audit is approved.

## Specs

- `SDP_HEROES_BUILD.md` — master build spec (stack, schema, execution order, acceptance criteria)
- `SDP_HEROES_PLAYWRIGHT_QA.md` — headless QA addendum (smoke, regression, migration, failover)
- `AUDIT.md` — Day 0 audit (KEEP / REWRITE / DELETE / GAPS) — see `audit-day-0` branch

## Stack

- **iOS** — SwiftUI, iOS 17+, Supabase Swift SDK
- **Admin panel** — Next.js 14 App Router, Tailwind, shadcn/ui, TanStack Query
- **Backend** — Node + TypeScript, Fastify or Express, BullMQ + Redis
- **Data** — Supabase (cloud Postgres + Auth + Storage + Realtime)
- **AI** — Claude Sonnet for customer-facing output, Haiku for batch
- **Hosting** — local M4 primary, Railway warm standby, Cloudflare Tunnel for ingress

## Working rules

1. Audit first. No new code on `main` until `AUDIT.md` is reviewed.
2. One PR per spec module. Tests required.
3. No copying from Workiz or CompanyCam (UI, code, copy, layout).
4. No em dashes anywhere in code, copy, UI, SMS, email, or PDFs.
5. Secrets via env vars only, never committed.
