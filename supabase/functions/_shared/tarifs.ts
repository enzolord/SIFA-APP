// Grille tarifaire SIFA côté serveur (identique à lib/data/pricing.dart et admin-web/src/pricing.js).
// Le prix d'un paiement est TOUJOURS recalculé ici : l'application ne choisit jamais le montant.

export const PACKS: Record<string, { name: string; price: number }> = {
  solo: { name: "Analyse SOLO", price: 2000 },
  equipe: { name: "Analyse ÉQUIPE", price: 4500 },
  pro: { name: "Analyse PRO", price: 12000 },
  entreprise: { name: "Analyse ENTREPRISE", price: 30000 },
};
export const TIERS: Record<number, number | null> = { 1: 5000, 2: 6000, 3: 8000, 4: 11000, 5: 15000, 6: 22000, 7: null };

export type Tarifs = {
  prix?: Record<string, number | null>;
  reduction_pack?: number;
  gestion_disponible?: boolean;
};

const valid = (v: unknown): v is number => typeof v === "number" && v > 0;
const up50 = (x: number) => Math.ceil(x / 50) * 50;

/** Prix par mois d'une offre, son libellé, ou une erreur lisible. */
export function priceOf(offre: string, t: Tarifs): { label: string; price: number } | { erreur: string } {
  const prix = t.prix ?? {};
  const get = (id: string, d: number | null) => (id in prix ? (prix[id] === null ? null : valid(prix[id]) ? Math.round(prix[id] as number) : d) : d);
  const discount = typeof t.reduction_pack === "number" && t.reduction_pack >= 0 && t.reduction_pack <= 90 ? t.reduction_pack : 15;

  let m = /^analyse_([a-z]+)$/.exec(offre);
  if (m && PACKS[m[1]]) {
    const p = get(offre, PACKS[m[1]].price);
    return p ? { label: PACKS[m[1]].name, price: p } : { erreur: "offre indisponible" };
  }
  m = /^gestion_(\d)$/.exec(offre);
  if (m && Number(m[1]) in TIERS) {
    if (t.gestion_disponible !== true) return { erreur: "La gestion de ferme n'est pas encore en vente." };
    const p = get(offre, TIERS[Number(m[1])]);
    return p ? { label: `Gestion ${m[1]}`, price: p } : { erreur: "Cette formule est sur devis." };
  }
  m = /^pack_([a-z]+)_(\d)$/.exec(offre);
  if (m && PACKS[m[1]] && Number(m[2]) in TIERS) {
    if (t.gestion_disponible !== true) return { erreur: "La gestion de ferme n'est pas encore en vente." };
    const a = get("analyse_" + m[1], PACKS[m[1]].price);
    const g = get("gestion_" + m[2], TIERS[Number(m[2])]);
    if (!a || !g) return { erreur: "Cette formule est sur devis." };
    return { label: `Pack ${PACKS[m[1]].name.replace("Analyse ", "")} + Gestion ${m[2]}`, price: up50((a + g) * (100 - discount) / 100) };
  }
  return { erreur: "offre inconnue" };
}

/** Réduction en % (arrondi aux 50 FCFA au-dessus). */
export const discounted = (price: number, pct: number) => (pct <= 0 ? price : up50(price * (100 - Math.min(100, pct)) / 100));

/** Numéro camerounais saisi par l'éleveur -> format Campay (237 + 9 chiffres), ou null. */
export function phoneOf(raw: string): string | null {
  let d = String(raw ?? "").replace(/[^0-9]/g, "");
  if (d.startsWith("237") && d.length === 12) d = d.slice(3);
  return /^6[5-9]\d{7}$/.test(d) ? "237" + d : null;
}
