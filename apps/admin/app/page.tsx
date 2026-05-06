/**
 * Step 1: minimal landing page so `pnpm dev:admin` serves something
 * green when the team verifies the scaffold. Real dashboard lands in
 * Step 4 (admin panel).
 */
export default function HomePage() {
  return (
    <main className="flex min-h-screen flex-col items-center justify-center gap-6 p-8">
      <h1 className="text-4xl font-bold tracking-tight text-zinc-900">
        SDP Heroes
      </h1>
      <p className="text-zinc-600 max-w-md text-center">
        Super Duper Pros field-service admin. Step 1 scaffold is up.
        Real dashboard ships in Step 4.
      </p>
      <div className="rounded-md bg-white border border-zinc-200 px-4 py-3 text-sm text-zinc-700 shadow-sm">
        Build: <code className="font-mono">heroes-v2-rebuild</code>
      </div>
    </main>
  );
}
