import { createClient } from "npm:@supabase/supabase-js@2";
import { status as campayStatus } from "./campay.ts";

export const admin = () => createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, { auth: { persistSession: false } });

/** Interroge Campay (jamais le contenu d'un appel entrant) et met à jour le paiement. Active la formule si le paiement est réussi. */
export async function settle(db: ReturnType<typeof admin>, p: { id: string; statut: string; campay_reference: string | null; montant: number }) {
  if (p.statut !== "en_attente" || !p.campay_reference) return p.statut;
  const s = await campayStatus(p.campay_reference);
  if (s.status === "SUCCESSFUL") {
    if (s.amount < p.montant) {
      await db.from("paiements").update({ statut: "echoue", raison: "montant reçu inférieur au montant dû", maj_le: new Date().toISOString() }).eq("id", p.id);
      return "echoue";
    }
    await db.from("paiements").update({ operateur: s.operateur }).eq("id", p.id);
    const { error } = await db.rpc("activer_paiement", { p_id: p.id });
    if (error) throw new Error("activation " + error.message);
    return "reussi";
  }
  if (s.status === "FAILED") {
    await db.from("paiements").update({ statut: "echoue", raison: s.raison, operateur: s.operateur, maj_le: new Date().toISOString() }).eq("id", p.id);
    return "echoue";
  }
  return "en_attente";
}
