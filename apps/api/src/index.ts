/**
 * SDP Heroes API ... Fastify bootstrap.
 *
 * Step 1 deliverable: minimal /health + /version endpoints, env-loaded
 * Supabase client wired (used in later steps), graceful shutdown.
 *
 * Routes / services / integrations / workers will fill in over the
 * remaining 7 spec steps. This file is the entry point only.
 */
import "dotenv/config";

import Fastify from "fastify";
import cors from "@fastify/cors";
import helmet from "@fastify/helmet";
import { createClient, type SupabaseClient } from "@supabase/supabase-js";

const PORT = Number(process.env.API_PORT ?? 3000);
const HOST = process.env.API_HOST ?? "0.0.0.0";
const NODE_ENV = process.env.NODE_ENV ?? "development";

const SUPABASE_URL = process.env.SUPABASE_URL ?? "";
const SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY ?? "";

if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
  // Don't crash on boot; log and continue. Routes that need Supabase
  // will surface a clear 503 via dependency-injection guard. This
  // lets us run /health green even before Supabase is provisioned.
  console.warn(
    "[boot] SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY missing ... DB-backed routes will return 503 until env is set"
  );
}

let supabaseAdmin: SupabaseClient | null = null;
if (SUPABASE_URL && SUPABASE_SERVICE_ROLE_KEY) {
  supabaseAdmin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
}

const app = Fastify({
  logger: {
    transport:
      NODE_ENV === "development"
        ? { target: "pino-pretty", options: { colorize: true, translateTime: "SYS:HH:MM:ss" } }
        : undefined,
  },
});

await app.register(helmet);
await app.register(cors, {
  origin: process.env.NEXT_PUBLIC_API_BASE_URL?.replace(/\/$/, "") ?? true,
});

app.get("/health", async () => {
  let dbOk = false;
  if (supabaseAdmin) {
    try {
      const { error } = await supabaseAdmin
        .from("sync_state")
        .select("id", { count: "exact", head: true });
      dbOk = !error;
    } catch {
      dbOk = false;
    }
  }
  return {
    ok: true,
    db: dbOk,
    env: NODE_ENV,
    version: process.env.npm_package_version ?? "0.0.0",
    ts: new Date().toISOString(),
  };
});

app.get("/version", async () => ({
  name: "@sdp/api",
  version: process.env.npm_package_version ?? "0.0.0",
}));

const shutdown = async (signal: string) => {
  app.log.info({ signal }, "shutting down");
  await app.close();
  process.exit(0);
};
process.on("SIGINT", () => void shutdown("SIGINT"));
process.on("SIGTERM", () => void shutdown("SIGTERM"));

try {
  await app.listen({ port: PORT, host: HOST });
  app.log.info(`SDP Heroes API listening on http://${HOST}:${PORT}`);
} catch (err) {
  app.log.error(err);
  process.exit(1);
}

export { app, supabaseAdmin };
