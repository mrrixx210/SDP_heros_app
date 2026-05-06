/**
 * Shared types + Zod schemas mirroring the Heroes DB schema (see
 * apps/api/src/db/migrations/0001_initial_schema.sql).
 *
 * Contract: every table in the migration has a Zod schema here. The
 * api, admin, and the agent-sdk all depend on this package so a
 * schema change ripples through every consumer at typecheck time.
 *
 * Step 1 ships the identity + customer + job + estimate types.
 * Remaining types fill in as their endpoints get wired in steps 2-7.
 */
import { z } from "zod";

// ── Enums (mirror DB CHECK constraints) ──────────────────────────────────

export const TechRole = z.enum(["plumbing", "hvac", "demo", "lead", "foreman", "apprentice"]);
export type TechRole = z.infer<typeof TechRole>;

export const AdminRole = z.enum(["owner", "dispatcher", "accounting", "ops"]);
export type AdminRole = z.infer<typeof AdminRole>;

export const AgentType = z.enum(["tony", "vinny", "anna", "claude_code", "other"]);
export type AgentType = z.infer<typeof AgentType>;

export const JobStatus = z.enum([
  "unscheduled",
  "scheduled",
  "enroute",
  "onsite",
  "completed",
  "invoiced",
  "paid",
  "canceled",
]);
export type JobStatus = z.infer<typeof JobStatus>;

export const JobType = z.enum(["plumbing", "hvac", "demo", "plumbing_hvac", "other"]);
export type JobType = z.infer<typeof JobType>;

export const Priority = z.enum(["low", "normal", "high", "urgent"]);
export type Priority = z.infer<typeof Priority>;

export const EstimateStatus = z.enum([
  "draft", "sent", "approved", "rejected", "expired", "superseded",
]);
export type EstimateStatus = z.infer<typeof EstimateStatus>;

export const InvoiceStatus = z.enum(["draft", "sent", "partial", "paid", "overdue", "void"]);
export type InvoiceStatus = z.infer<typeof InvoiceStatus>;

export const PaymentMethod = z.enum(["stripe", "cash", "check", "ach", "mercury", "zelle", "other"]);
export type PaymentMethod = z.infer<typeof PaymentMethod>;

export const AiPageType = z.enum([
  "walkthrough", "summary", "daily_log", "adjuster_packet", "photo_to_estimate", "anomaly",
]);
export type AiPageType = z.infer<typeof AiPageType>;

// ── Identity ─────────────────────────────────────────────────────────────

export const TechUser = z.object({
  id: z.string().uuid(),
  name: z.string(),
  phone: z.string().nullable(),
  email: z.string().email().nullable(),
  role: TechRole,
  active: z.boolean(),
  created_at: z.string(),
});
export type TechUser = z.infer<typeof TechUser>;

export const AdminUser = z.object({
  id: z.string().uuid(),
  name: z.string(),
  email: z.string().email(),
  role: AdminRole,
  active: z.boolean(),
  created_at: z.string(),
});
export type AdminUser = z.infer<typeof AdminUser>;

export const AgentUser = z.object({
  id: z.string().uuid(),
  name: z.string(),
  agent_type: AgentType,
  api_key_hash: z.string(),
  active: z.boolean(),
  created_at: z.string(),
});
export type AgentUser = z.infer<typeof AgentUser>;

// ── Customers ────────────────────────────────────────────────────────────

export const Customer = z.object({
  id: z.string().uuid(),
  name: z.string(),
  phone: z.string().nullable(),
  email: z.string().email().nullable(),
  address_line1: z.string().nullable(),
  address_line2: z.string().nullable(),
  city: z.string().nullable(),
  state: z.string().nullable(),
  zip: z.string().nullable(),
  lat: z.number().nullable(),
  lng: z.number().nullable(),
  notes: z.string().nullable(),
  source: z.string().nullable(),
  created_at: z.string(),
  updated_at: z.string(),
});
export type Customer = z.infer<typeof Customer>;

// ── Jobs ─────────────────────────────────────────────────────────────────

export const Job = z.object({
  id: z.string().uuid(),
  customer_id: z.string().uuid(),
  status: JobStatus,
  type: JobType,
  source: z.string().nullable(),
  priority: Priority,
  scheduled_start: z.string().nullable(),
  scheduled_end: z.string().nullable(),
  actual_start: z.string().nullable(),
  actual_end: z.string().nullable(),
  assigned_tech_id: z.string().uuid().nullable(),
  scope: z.string().nullable(),
  internal_notes: z.string().nullable(),
  gross_total: z.number().nullable(),
  gp_estimate: z.number().nullable(),
  created_by: z.string().uuid().nullable(),
  created_at: z.string(),
  updated_at: z.string(),
});
export type Job = z.infer<typeof Job>;

// ── Estimates / Invoices / Payments (Step 2 fills in endpoints) ─────────

export const EstimateLineItem = z.object({
  description: z.string(),
  quantity: z.number(),
  unit_price: z.number(),
  total: z.number(),
});
export type EstimateLineItem = z.infer<typeof EstimateLineItem>;

export const Estimate = z.object({
  id: z.string().uuid(),
  job_id: z.string().uuid(),
  line_items: z.array(EstimateLineItem),
  subtotal: z.number(),
  tax: z.number(),
  total: z.number(),
  status: EstimateStatus,
  sent_at: z.string().nullable(),
  approved_at: z.string().nullable(),
  created_at: z.string(),
});
export type Estimate = z.infer<typeof Estimate>;
