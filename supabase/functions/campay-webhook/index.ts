// Fonction Supabase « campay-webhook » : appelée par Campay quand un paiement est réussi ou échoué.
//
// Dans le tableau de bord Campay (votre application > Webhook URL), saisissez :
//   https://<votre-projet>.supabase.co/functions/v1/campay-webhook      (méthode GET ou POST)
// Déploiement : supabase functions deploy campay-webhook --no-verify-jwt
//
// Le contenu de l'appel n'est JAMAIS cru : on s'en sert seulement pour retrouver le paiement,
// puis on demande son état réel à Campay avant d'activer quoi que ce soit.
import { admin, settle } from "../_shared/paiement.ts";

Deno.serve(async (req) => {
  const url = new URL(req.url);
  const get = (k: string) => url.searchParams.get(k);
  let ref = get("reference"), ext = get("external_reference");
  if (req.method === "POST") {
    try {
      const ct = req.headers.get("content-type") ?? "";
      const b = ct.includes("json") ? await req.json() : Object.fromEntries(await req.formData());
      ref = ref ?? (b.reference ? String(b.reference) : null);
      ext = ext ?? (b.external_reference ? String(b.external_reference) : null);
    } catch (_) { /* corps illisible : on s'appuie sur l'adresse */ }
  }
  const uuid = /^[0-9a-f-]{36}$/i;
  const db = admin();
  let q = db.from("paiements").select("id,statut,campay_reference,montant");
  if (ext && uuid.test(ext)) q = q.eq("id", ext);
  else if (ref && uuid.test(ref)) q = q.eq("campay_reference", ref);
  else return new Response("ignoré", { status: 200 });
  const { data: p } = await q.maybeSingle();
  if (!p) return new Response("inconnu", { status: 200 });
  try {
    await settle(db, p);
  } catch (e) {
    console.error("campay-webhook", e);
    return new Response("erreur", { status: 500 }); // Campay réessaiera
  }
  return new Response("ok", { status: 200 });
});
