# tests/playwright/ai-quality

Source: `SDP_HEROES_PLAYWRIGHT_QA.md` section 3.

Suite stub for Step 1. Real specs land in the relevant build step:
- `smoke` and `critical-path` get filled in alongside the Step 2 jobs API.
- `regression` lands with Step 4 admin panel + Step 6 AI pipeline.
- `migration` lands with Step 8.
- `pre-cutover` and `failover` land with Step 9.
- `ai-quality` lands with Step 6.
- `fixtures` (auth, seed-data, stripe-test-cards, twilio-mock) land in Step 2.
