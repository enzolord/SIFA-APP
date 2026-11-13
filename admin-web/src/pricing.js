/** Grille tarifaire SIFA (identique à lib/data/pricing.dart). Les corrections faites dans l'admin
 *  sont enregistrées dans contenu.tarifs et appliquées par l'application sans mise à jour. */
export const PACKS = [
  { key: 'solo', name: 'Analyse SOLO', accounts: 1, analyses: 20, price: 2000 },
  { key: 'equipe', name: 'Analyse ÉQUIPE', accounts: 3, analyses: 60, price: 4500 },
  { key: 'pro', name: 'Analyse PRO', accounts: 10, analyses: 200, price: 12000 },
  { key: 'entreprise', name: 'Analyse ENTREPRISE', accounts: 25, analyses: 600, price: 30000 },
];
export const TIERS = [
  { n: 1, min: 200, max: 500, price: 5000 }, { n: 2, min: 501, max: 1500, price: 6000 }, { n: 3, min: 1501, max: 3500, price: 8000 },
  { n: 4, min: 3501, max: 6500, price: 11000 }, { n: 5, min: 6501, max: 10500, price: 15000 }, { n: 6, min: 10501, max: 20500, price: 22000 },
  { n: 7, min: 20501, max: null, price: null },
];
export const DEFAULT_TARIFS = { prix: {}, reduction_pack: 15, compte_supplementaire: 500, analyses_supplementaires: 1000, gestion_disponible: false };

const ok = v => typeof v === 'number' && v > 0;
export function catalogue(tarifs = {}) {
  const prix = tarifs.prix || {};
  const price = (id, d) => (id in prix ? (prix[id] === null ? null : ok(prix[id]) ? Math.round(prix[id]) : d) : d);
  const packs = PACKS.map(p => ({ ...p, id: 'analyse_' + p.key, price: price('analyse_' + p.key, p.price) }));
  const tiers = TIERS.map(t => ({ ...t, id: 'gestion_' + t.n, name: 'Gestion ' + t.n, price: price('gestion_' + t.n, t.price) }));
  const discount = typeof tarifs.reduction_pack === 'number' && tarifs.reduction_pack >= 0 && tarifs.reduction_pack <= 90 ? tarifs.reduction_pack : 15;
  return { packs, tiers, discount };
}
/** Pack complet : somme moins la réduction, arrondie à 50 FCFA au-dessus. */
export const packPrice = (a, t, discount) => (a.price != null && t.price != null ? Math.ceil(((a.price + t.price) * (100 - discount) / 100) / 50) * 50 : null);

/** Toutes les offres vendables : { id, label, price (par mois) }. */
export function offers(tarifs) {
  const { packs, tiers, discount } = catalogue(tarifs);
  const out = [...packs.map(p => ({ id: p.id, label: p.name, price: p.price })), ...tiers.filter(t => t.price != null).map(t => ({ id: t.id, label: t.name, price: t.price }))];
  for (const p of packs) for (const t of tiers) { const pr = packPrice(p, t, discount); if (pr != null) out.push({ id: `pack_${p.key}_${t.n}`, label: `Pack ${p.name.replace('Analyse ', '')} + ${t.name}`, price: pr }); }
  return out;
}
export const legacyLabel = { mensuelle: 'Mensuelle (ancienne)', annuelle: 'Annuelle (ancienne)', essai: 'Essai' };
export const fcfa = n => (n == null ? 'Sur devis' : Math.round(n).toLocaleString('fr-FR') + ' FCFA');
