// Fonction Supabase « campay-paiement » : paiement d'une formule par Mobile Money via Campay.
//
// Appelée par l'application (éleveur connecté) :
//   { "action": "payer",  "offre": "analyse_pro", "mois": 1, "telephone": "677000000", "code_promo": "RENTREE20" }
//   { "action": "statut", "paiement_id": "<uuid>" }
//
// Déploiement : supabase functions deploy campay-paiement --no-verify-jwt   (le jeton de l'éleveur est vérifié ici)
// Secrets : CAMPAY_USERNAME, CAMPAY_PASSWORD, CAMPAY_BASE_URL (voir _shared/campay.ts).
import { createClient } from "npm:@supabase/supabase-js@2";
import { collect } from "../_shared/campay.ts";
import { admin, settle } from "../_shared/paiement.ts";
import { discounted, phoneOf, priceOf, type Tarifs } from "../_shared/tarifs.ts";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-client-info",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (b: unknown, s = 200) => new Response(JSON.stringify(b), { status: s, headers: { ...CORS, "Content-Type": "application/json; charset=utf-8" } });

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return json({ erreur: "POST attendu" }, 405);

  const jwt = (req.headers.get("authorization") ?? "").replace(/^Bearer\s+/i, "");
  const anon = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_ANON_KEY")!, { auth: { persistSession: false } });
  const { data: u } = await anon.auth.getUser(jwt);
  const user = u?.user;
  if (!user) return json({ erreur: "Connectez-vous avec Google pour payer." }, 401);

  let body: Record<string, unknown>;
  try { body = await req.json(); } catch { return json({ erreur: "JSON invalide" }, 400); }
  const db = admin();

  try {
    if (body.action === "statut") {
      const { data: p } = await db.from("paiements").select("id,statut,campay_reference,montant,raison,user_id").eq("id", String(body.paiement_id ?? "")).maybeSingle();
      if (!p || p.user_id !== user.id) return json({ erreur: "paiement introuvable" }, 404);
      const statut = await settle(db, p);
      return json({ statut, raison: statut === "echoue" ? p.raison : null });
    }

    if (body.action !== "payer") return json({ erreur: "action inconnue" }, 400);
    const offre = String(body.offre ?? "");
    const mois = Math.max(1, Math.min(12, Math.round(Number(body.mois) || 1)));
    const tel = phoneOf(String(body.telephone ?? ""));
    if (!tel) return json({ erreur: "Numéro invalide : entrez un numéro MTN ou Orange à 9 chiffres (6XXXXXXXX)." }, 400);

    const { data: tc } = await db.from("contenu").select("valeur").eq("cle", "tarifs").maybeSingle();
    const t = (tc?.valeur ?? {}) as Tarifs;
    const o = priceOf(offre, t);
    if ("erreur" in o) return json({ erreur: o.erreur }, 400);

    let reduction = 0, promo: string | null = null;
    const code = String(body.code_promo ?? "").trim().toUpperCase();
    if (code) {
      const { data: r } = await db.rpc("verifier_promo", { p_code: code });
      if (Array.isArray(r) && r.length) { reduction = Number(r[0].reduction) || 0; promo = code; }
    }
    const montant = discounted(o.price, reduction) * mois;

    // Pas plus de 3 demandes en attente en 10 minutes par éleveur.
    const since = new Date(Date.now() - 10 * 60_000).toISOString();
    const { count } = await db.from("paiements").select("id", { count: "exact", head: true }).eq("user_id", user.id).eq("statut", "en_attente").gte("cree_le", since);
    if ((count ?? 0) >= 3) return json({ erreur: "Trop de demandes en cours. Patientez quelques minutes." }, 429);

    const { data: row, error } = await db.from("paiements").insert({
      user_id: user.id, offre, mois, montant, prix_base: o.price, reduction, code_promo: promo, telephone: tel,
    }).select("id").single();
    if (error || !row) throw new Error("enregistrement " + error?.message);

    if (montant <= 0) { // réduction de 100 % : rien à payer
      await db.rpc("activer_paiement", { p_id: row.id });
      return json({ paiement_id: row.id, statut: "reussi", montant: 0 });
    }

    try {
      const c = await collect({ amount: montant, from: tel, description: `SIFA ${o.label}${mois > 1 ? ` (${mois} mois)` : ""}`, externalReference: row.id });
      await db.from("paiements").update({ campay_reference: c.reference, operateur: c.operateur }).eq("id", row.id);
      return json({ paiement_id: row.id, statut: "en_attente", montant, ussd: c.ussd, operateur: c.operateur });
    } catch (e) {
      console.error("campay", e);
      await db.from("paiements").update({ statut: "echoue", raison: "Campay indisponible", maj_le: new Date().toISOString() }).eq("id", row.id);
      return json({ erreur: "Le paiement n'a pas pu démarrer. Réessayez dans un instant." }, 502);
    }
  } catch (e) {
    console.error("campay-paiement", e);
    return json({ erreur: "indisponible" }, 500);
  }
});
