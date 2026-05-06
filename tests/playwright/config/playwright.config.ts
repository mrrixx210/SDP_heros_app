import { defineConfig, devices } from "@playwright/test";

/**
 * SDP Heroes Playwright config ... source: SDP_HEROES_PLAYWRIGHT_QA.md section 11.
 *
 * Five projects:
 *   - chromium / webkit / mobile-safari (general suites)
 *   - smoke-prod (hits the live Cloudflare Tunnel URL)
 *   - smoke-failover (hits Railway URL only when promoted as primary)
 *
 * Two custom reporters write to Google Chat (#sdp-approvals) and Hermes
 * memory so the system gets smarter over time. Stubs land in Step 1;
 * Step 6+ wires the real Chat + Hermes integrations.
 */
export default defineConfig({
  testDir: "../",
  fullyParallel: true,
  forbidOnly: Boolean(process.env.CI),
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 4 : undefined,
  reporter: [
    ["html", { outputFolder: "../../../playwright-report" }],
    ["json", { outputFile: "../../../test-results.json" }],
    ["./reporters/google-chat-reporter.ts"],
    ["./reporters/hermes-memory-reporter.ts"],
  ],
  use: {
    baseURL: process.env.SDP_ADMIN_URL ?? "http://localhost:3001",
    trace: "on-first-retry",
    screenshot: "only-on-failure",
    video: "retain-on-failure",
    headless: true,
  },
  projects: [
    { name: "chromium", use: { ...devices["Desktop Chrome"] } },
    { name: "webkit", use: { ...devices["Desktop Safari"] } },
    { name: "mobile-safari", use: { ...devices["iPhone 15"] } },
    {
      name: "smoke-prod",
      testDir: "../smoke",
      use: { baseURL: "https://admin.superduperpros.com" },
    },
    {
      name: "smoke-failover",
      testDir: "../smoke",
      use: { baseURL: process.env.RAILWAY_URL ?? "https://admin.superduperpros.com" },
    },
  ],
  webServer: process.env.CI
    ? undefined
    : {
        command: "pnpm dev:admin",
        port: 3001,
        reuseExistingServer: true,
        cwd: "../../..",
      },
});
