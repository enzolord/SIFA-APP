// Quotas de l'assistant vocal par formule (côté serveur : l'application ne décide jamais de son quota).
// Réglables depuis l'administration (Contenu > Tarifs) dans la section « assistant » de la ligne « tarifs ».

export type AssistantCfg = {
  gratuit?: number;
  analyse?: Record<string, number>;
  gestion_bas?: number;
  gestion_haut?: number;
  bonus_pack?: number;
};

export const DEFAUT: Required<AssistantCfg> = {
  gratuit: 10,
  analyse: { solo: 30, equipe: 100, pro: 300, entreprise: 1000 },
  gestion_bas: 50, // paliers de gestion 1 à 3
  gestion_haut: 150, // paliers 4 à 7
  bonus_pack: 15, // % de questions en plus dans un pack complet
};

const nb = (v: unknown, d: number) => (typeof v === "number" && Number.isFinite(v) && v >= 0 && v <= 100000 ? Math.round(v) : d);

/** Nombre de questions par période pour une offre. `limite: null` = illimité. `gratuit` : quota à vie, sans formule. */
export function assistantLimit(offre: string | null, cfg: AssistantCfg = {}): { limite: number | null; gratuit: boolean } {
  const free = { limite: nb(cfg.gratuit, DEFAUT.gratuit), gratuit: true };
  if (!offre) return free;
  if (["mensuelle", "annuelle", "promo_analyse", "promo_complet"].includes(offre)) return { limite: null, gratuit: false };
  const analyse = (k: string): number | null => {
    if (!(k in DEFAUT.analyse)) return null;
    return nb(cfg.analyse?.[k], DEFAUT.analyse[k]);
  };
  const gestion = (n: number) => (n <= 3 ? nb(cfg.gestion_bas, DEFAUT.gestion_bas) : nb(cfg.gestion_haut, DEFAUT.gestion_haut));

  if (offre === "promo_gestion") return { limite: gestion(1), gratuit: false };
  let m = /^analyse_([a-z]+)$/.exec(offre);
  if (m) {
    const a = analyse(m[1]);
    return a === null ? free : { limite: a, gratuit: false };
  }
  m = /^gestion_(\d)$/.exec(offre);
  if (m) return { limite: gestion(Number(m[1])), gratuit: false };
  m = /^pack_([a-z]+)_(\d)$/.exec(offre);
  if (m) {
    const a = analyse(m[1]);
    if (a === null) return free;
    const bonus = nb(cfg.bonus_pack, DEFAUT.bonus_pack);
    return { limite: Math.round((a + gestion(Number(m[2]))) * (100 + bonus) / 100), gratuit: false };
  }
  return free;
}

/** Début de la période de 30 jours en cours (comme les analyses : à partir de l'activation de la formule). */
export function windowStart(debut: Date, now: Date): Date {
  const jours = Math.max(0, Math.floor((now.getTime() - debut.getTime()) / 86_400_000));
  return new Date(debut.getTime() + Math.floor(jours / 30) * 30 * 86_400_000);
}
