/**
 * Google Chat reporter ... posts test outcomes to #sdp-approvals.
 *
 * Step 1: STUB. Logs to stdout. Real webhook delivery lands in Step 6
 * when the AI pipeline + approval queue come online.
 *
 * Behavior per SDP_HEROES_PLAYWRIGHT_QA.md section 9:
 *   - All-green runs: silent (no post)
 *   - Failures: post a card to GOOGLE_CHAT_WEBHOOK_APPROVAL_QUEUE with
 *     test name + error excerpt + Tony's recommended action +
 *     [Approve plan] / [Investigate] / [Block] buttons
 *   - Migration mismatches > 1%: blocking escalation to Rick
 *   - AI quality < 90%: Tony retunes prompt, only escalates on second fail
 */
import type { Reporter, TestCase, TestResult } from "@playwright/test/reporter";

class GoogleChatReporter implements Reporter {
  private failures: Array<{ test: string; error: string }> = [];

  onTestEnd(test: TestCase, result: TestResult): void {
    if (result.status === "failed" || result.status === "timedOut") {
      this.failures.push({
        test: test.titlePath().join(" > "),
        error: (result.error?.message ?? "(no message)").slice(0, 300),
      });
    }
  }

  onEnd(): void {
    if (this.failures.length === 0) {
      // Silent on green per spec.
      return;
    }
    // STUB: print what would post; actual webhook in Step 6.
    const webhook = process.env.GOOGLE_CHAT_WEBHOOK_APPROVAL_QUEUE ?? "";
    console.log(
      `[google-chat-reporter] ${this.failures.length} failure(s) ... would post to ${webhook ? "#sdp-approvals" : "(no webhook configured)"}.`
    );
    for (const f of this.failures.slice(0, 5)) {
      console.log(`  - ${f.test}: ${f.error}`);
    }
  }
}

export default GoogleChatReporter;
