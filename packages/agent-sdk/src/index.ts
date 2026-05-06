/**
 * @sdp/agent-sdk ... thin client for the SDP Heroes agent API surface.
 *
 * Step 7 fills in the actual endpoint contracts. This is a stub now so
 * Tony's repo can `npm install @sdp/agent-sdk` (eventually published)
 * and have a typed client ready when the endpoints land.
 *
 * Usage (Step 7+):
 *   import { createAgentClient } from "@sdp/agent-sdk";
 *   const client = createAgentClient({
 *     baseUrl: "https://api.superduperpros.com",
 *     bearer: process.env.AGENT_API_BEARER!,
 *   });
 *   const job = await client.jobs.create({ customer_id, type, scope });
 */
import type { Job } from "@sdp/shared-types";

export type AgentClientOptions = {
  baseUrl: string;
  bearer: string;
  fetch?: typeof globalThis.fetch;
};

export type AgentClient = {
  jobs: {
    create: (input: Partial<Job>) => Promise<Job>;
  };
  // ... estimates, photos, etc fill in at Step 7
};

export function createAgentClient(opts: AgentClientOptions): AgentClient {
  const f = opts.fetch ?? globalThis.fetch;
  const baseUrl = opts.baseUrl.replace(/\/$/, "");

  async function call<T>(path: string, init?: RequestInit): Promise<T> {
    const res = await f(`${baseUrl}${path}`, {
      ...init,
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${opts.bearer}`,
        ...(init?.headers ?? {}),
      },
    });
    if (!res.ok) {
      const body = await res.text().catch(() => "");
      throw new Error(`agent-sdk ${path} ${res.status}: ${body.slice(0, 300)}`);
    }
    return (await res.json()) as T;
  }

  return {
    jobs: {
      create: async (input) =>
        call<Job>("/api/agent/jobs", {
          method: "POST",
          body: JSON.stringify(input),
        }),
    },
  };
}
