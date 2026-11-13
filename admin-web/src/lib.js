import { createClient } from '@supabase/supabase-js';

export const URL_ = import.meta.env.VITE_SUPABASE_URL || 'https://qprgpmmvdjrmslfsraae.supabase.co';
export const KEY = import.meta.env.VITE_SUPABASE_KEY || 'sb_publishable_HfgFOYXWuyNAWrjDGWJjiA_7jSssFOK';
export const sb = createClient(URL_, KEY, { auth: { persistSession: true, autoRefreshToken: true } });

export async function must(promise) {
  const { data, error } = await promise;
  if (error) throw error;
  return data;
}

export const nf = n => (n == null ? '—' : Number(n).toLocaleString('fr-FR'));
export const pct = (a, b, d = 0) => (b > 0 ? (100 * a / b).toFixed(d).replace('.', ',') + ' %' : '—');
export const ratio = (a, b) => (b > 0 ? a / b : null);
export const fdate = s => (s ? new Date(s).toLocaleString('fr-FR', { dateStyle: 'short', timeStyle: 'short' }) : '—');
export const fday = s => (s ? new Date(s).toLocaleDateString('fr-FR') : '—');

export const MALADIES = ['healthy', 'coccidiosis', 'salmonella', 'newcastle'];
export const CLASSES = [
  { id: 'Healthy', label: 'Fiente saine', app: 'healthy', key: '1' },
  { id: 'Coccidiosis', label: 'Coccidiose', app: 'coccidiosis', key: '2' },
  { id: 'Salmonella', label: 'Salmonellose', app: 'salmonella', key: '3' },
  { id: 'New_Castle_Disease', label: 'Newcastle', app: 'newcastle', key: '4' },
  { id: 'Autre', label: 'Autre (pas une fiente)', app: null, key: '5' },
];
export const classOfApp = app => CLASSES.find(c => c.app === app)?.id ?? null;
export const classLabel = id => CLASSES.find(c => c.id === id)?.label ?? id ?? '—';

export const L = {
  maladie: { healthy: 'Fiente saine', coccidiosis: 'Coccidiose', salmonella: 'Salmonellose', newcastle: 'Newcastle', autre: 'Autre maladie', inconnue: 'Inconnue', inconnu: 'Inconnue' },
  issue: { ok: 'Photo acceptée', notDropping: 'Pas une fiente', tooDark: 'Trop sombre', tooPlain: 'Surface unie', unclear: 'Photo peu claire', modelError: 'Erreur du modèle', inconnu: '—' },
  gemini: { dropping: 'Gemini : fiente', notDropping: 'Gemini : autre chose', unknown: 'Gemini : sans réponse', absent: 'Non interrogé' },
  fiab: { high: 'Forte', medium: 'Moyenne', low: 'Faible', inconnu: '—' },
  ecran: {
    Accueil: 'Accueil', Historique: 'Historique', Scanner: 'Scanner', Communaute: 'Communauté', Profil: 'Profil',
    SignsScreen: 'Questions sur les signes', ResultScreen: 'Résultat', RemedesScreen: 'Remèdes et conseils', AbonnementScreen: 'Formules',
    NewPostScreen: 'Nouvelle publication', PostDetailScreen: 'Détail d’une publication', GroupDetailScreen: 'Groupe de discussion',
    BandsScreen: 'Mes bandes', StocksScreen: 'Stocks', FinancesScreen: 'Finances', TasksScreen: 'Tâches', PerformanceScreen: 'Performances', HealthScreen: 'Santé et traitements', ClientsScreen: 'Clients', ProfitScreen: 'Rentabilité par bande', ReportScreen: 'Rapport de bande', BandDetailScreen: 'Détail d’une bande', EntryScreen: 'Saisie journalière',
  },
  action: {
    appel_pharmacie: 'Appel d’une pharmacie', itineraire_maps: 'Itinéraire (Google Maps)', itineraire_carte: 'Itinéraire sur la carte',
    'ferme:sante_ajout': 'Ferme : soin ajouté', 'ferme:vente': 'Ferme : vente saisie', 'ferme:depense': 'Ferme : dépense saisie', 'ferme:client_ajout': 'Ferme : client ajouté', 'ferme:rapport_copie': 'Ferme : rapport copié', 'ferme:verrouille': 'Ferme : accès verrouillé (formule)',
    connexion_google: 'Connexion Google', code_active: 'Code d’activation utilisé', photo_partagee: 'Photo partagée pour améliorer SIFA',
  },
};
export const lab = (dict, k) => dict[k] ?? (k && String(k).startsWith('tuile:') ? 'Accueil › ' + String(k).slice(6) : k ?? '—');

export const css = n => getComputedStyle(document.documentElement).getPropertyValue(n).trim();

export function genCode() {
  const al = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789', r = crypto.getRandomValues(new Uint8Array(8));
  const c = [...r].map(x => al[x % al.length]).join('');
  return `SIFA-${c.slice(0, 4)}-${c.slice(4)}`;
}

export function download(name, blob) {
  const a = document.createElement('a');
  a.href = URL.createObjectURL(blob); a.download = name;
  document.body.append(a); a.click(); a.remove();
  setTimeout(() => URL.revokeObjectURL(a.href), 4000);
}

export function toCsv(rows) {
  const cols = [...new Set(rows.flatMap(r => Object.keys(r)))];
  const esc = v => { v = v == null ? '' : typeof v === 'object' ? JSON.stringify(v) : String(v); return /[",\n;]/.test(v) ? '"' + v.replace(/"/g, '""') + '"' : v; };
  return '﻿' + [cols.join(';'), ...rows.map(r => cols.map(c => esc(r[c])).join(';'))].join('\n');
}
export const downloadCsv = (name, rows) => download(name, new Blob([toCsv(rows)], { type: 'text/csv;charset=utf-8' }));

/** Charge les événements bruts de la période par tranches de 1000 (limite Supabase). */
export async function fetchEvents(days, names, max = 10000) {
  const since = new Date(Date.now() - days * 864e5).toISOString();
  const out = [];
  for (let from = 0; from < max; from += 1000) {
    let q = sb.from('evenements').select('cree_le,appareil,nom,props').gte('cree_le', since).order('cree_le', { ascending: false }).range(from, from + 999);
    if (names) q = q.in('nom', names);
    const rows = await must(q);
    out.push(...rows);
    if (rows.length < 1000) return { rows: out, truncated: false };
  }
  return { rows: out, truncated: true };
}

/** Hash stable (FNV-1a) pour répartir les photos train/val/test de façon reproductible. */
export function hash01(s) {
  let h = 2166136261;
  for (let i = 0; i < s.length; i++) { h ^= s.charCodeAt(i); h = Math.imul(h, 16777619); }
  return ((h >>> 0) % 10000) / 10000;
}

export const getC = async key => (await must(sb.from('contenu').select('valeur').eq('cle', key).maybeSingle()))?.valeur ?? {};
export const setC = (key, valeur) => must(sb.from('contenu').upsert({ cle: key, valeur }));
