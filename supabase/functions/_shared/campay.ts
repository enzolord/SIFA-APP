// Appels à l'API Campay. Secrets à définir dans Supabase (Edge Functions > Secrets) :
//   CAMPAY_USERNAME, CAMPAY_PASSWORD  identifiants de l'application Campay (« API Credentials »)
//   CAMPAY_BASE_URL                   démo : https://demo.campay.net/api   production : https://www.campay.net/api
const BASE = (Deno.env.get("CAMPAY_BASE_URL") ?? "https://demo.campay.net/api").replace(/\/+$/, "");

let cached: { token: string; until: number } | null = null;

async function token(): Promise<string> {
  if (cached && cached.until > Date.now() + 30_000) return cached.token;
  const r = await fetch(`${BASE}/token/`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ username: Deno.env.get("CAMPAY_USERNAME"), password: Deno.env.get("CAMPAY_PASSWORD") }),
    signal: AbortSignal.timeout(15_000),
  });
  const j = await r.json().catch(() => ({}));
  if (!r.ok || !j.token) throw new Error("campay-token " + r.status);
  cached = { token: j.token, until: Date.now() + (Number(j.expires_in) || 3000) * 1000 };
  return j.token;
}

export async function collect(p: { amount: number; from: string; description: string; externalReference: string }) {
  const r = await fetch(`${BASE}/collect/`, {
    method: "POST",
    headers: { "Content-Type": "application/json", Authorization: `Token ${await token()}` },
    body: JSON.stringify({ amount: String(Math.round(p.amount)), currency: "XAF", from: p.from, description: p.description, external_reference: p.externalReference }),
    signal: AbortSignal.timeout(20_000),
  });
  const j = await r.json().catch(() => ({}));
  if (!r.ok || !j.reference) throw new Error("campay-collect " + r.status + " " + JSON.stringify(j).slice(0, 200));
  return { reference: String(j.reference), ussd: j.ussd_code ? String(j.ussd_code) : null, operateur: j.operator ? String(j.operator) : null };
}

export type CampayStatus = { status: "PENDING" | "SUCCESSFUL" | "FAILED"; amount: number; operateur: string | null; raison: string | null; externalReference: string | null };

export async function status(reference: string): Promise<CampayStatus> {
  const r = await fetch(`${BASE}/transaction/${encodeURIComponent(reference)}/`, {
    headers: { Authorization: `Token ${await token()}` },
    signal: AbortSignal.timeout(15_000),
  });
  const j = await r.json().catch(() => ({}));
  if (!r.ok) throw new Error("campay-status " + r.status);
  const s = String(j.status ?? "PENDING").toUpperCase();
  return {
    status: s === "SUCCESSFUL" ? "SUCCESSFUL" : s === "FAILED" ? "FAILED" : "PENDING",
    amount: Number(j.amount) || 0,
    operateur: j.operator ? String(j.operator) : null,
    raison: j.reason ? String(j.reason).slice(0, 120) : null,
    externalReference: j.external_reference ? String(j.external_reference) : null,
  };
}
