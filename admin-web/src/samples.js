import { CLASSES, classOfApp, fetchEvents, hash01, must, sb, download } from './lib.js';

/** Photos partagées + avis des éleveurs correspondants. */
export async function loadSamples() {
  const rows = [];
  for (let from = 0; from < 5000; from += 1000) {
    const part = await must(sb.from('echantillons').select('*').order('cree_le', { ascending: false }).range(from, from + 999));
    rows.push(...part);
    if (part.length < 1000) break;
  }
  let feedback = new Map();
  try {
    const { rows: ev } = await fetchEvents(365, ['retour']);
    for (const e of ev) if (e.props?.ref != null && !feedback.has(e.appareil + ':' + e.props.ref)) feedback.set(e.appareil + ':' + e.props.ref, e.props);
  } catch (e) { console.warn('avis éleveurs indisponibles', e); }
  return rows.map(r => {
    const fb = feedback.get(r.appareil + ':' + r.ref);
    return { ...r, avis: fb ? (fb.juste ? 'juste' : 'faux') : null, reelle: fb && !fb.juste ? fb.reelle : null };
  });
}

/** Classe probable : celle validée, sinon celle de l'éleveur (s'il a corrigé), sinon celle annoncée par SIFA. */
export function guess(r) {
  if (r.classe_validee) return r.classe_validee;
  if (r.avis === 'faux' && r.reelle) return classOfApp(r.reelle);
  return classOfApp(r.maladie_app);
}

const cache = new Map();
export async function signedUrls(paths) {
  const need = paths.filter(p => !cache.has(p) || cache.get(p).exp < Date.now());
  for (let i = 0; i < need.length; i += 100) {
    const batch = need.slice(i, i + 100);
    const { data, error } = await sb.storage.from('echantillons').createSignedUrls(batch, 3600);
    if (error) throw error;
    data.forEach(d => { if (d.signedUrl) cache.set(d.path, { url: d.signedUrl, exp: Date.now() + 3300e3 }); });
  }
  return Object.fromEntries(paths.map(p => [p, cache.get(p)?.url]));
}

export async function setLabel(ids, patch, adminId) {
  const upd = patch.statut === 'valide'
    ? { statut: 'valide', classe_validee: patch.classe, valide_par: adminId, valide_le: new Date().toISOString() }
    : patch.statut === 'rejete' ? { statut: 'rejete', classe_validee: null, valide_par: adminId, valide_le: new Date().toISOString() }
    : { statut: 'a_valider', classe_validee: null, valide_par: null, valide_le: null };
  if (patch.notes !== undefined) upd.notes = patch.notes;
  await must(sb.from('echantillons').update(upd).in('id', ids));
}

export async function removeSamples(rows) {
  const paths = rows.map(r => r.photo_path);
  for (let i = 0; i < paths.length; i += 100) await sb.storage.from('echantillons').remove(paths.slice(i, i + 100));
  await must(sb.from('echantillons').delete().in('id', rows.map(r => r.id)));
}

export const SPLITS = { train: 0.70, val: 0.85 };
export const splitOf = id => { const h = hash01(id); return h < SPLITS.train ? 'train' : h < SPLITS.val ? 'val' : 'test_terrain'; };

/** Rangées retenues pour le jeu d'entraînement. */
export function pickDataset(rows, { includeUnvalidatedJuste }) {
  return rows.filter(r => r.statut === 'valide' || (includeUnvalidatedJuste && r.statut === 'a_valider' && r.avis === 'juste' && classOfApp(r.maladie_app)))
    .map(r => ({ ...r, classe: r.classe_validee || classOfApp(r.maladie_app) }));
}

export function countByClassSplit(rows) {
  const t = {}; for (const c of CLASSES) t[c.id] = { train: 0, val: 0, test_terrain: 0, total: 0 };
  for (const r of rows) { const s = splitOf(r.id); t[r.classe][s]++; t[r.classe].total++; }
  return t;
}

/** Construit l'archive ZIP : <dossier>/{train,val,test_terrain}/<Classe>/*.jpg + manifest.csv + LISEZMOI.txt */
export async function buildZip(rows, { flat = false, onProgress, max = 2500 } = {}) {
  const JSZip = (await import('jszip')).default;
  const date = new Date().toISOString().slice(0, 10);
  const root = `sifa_terrain_${date}`;
  const zip = new JSZip();
  const list = rows.slice(0, max);
  const urls = await signedUrls(list.map(r => r.photo_path));
  const manifest = ['fichier;classe;ensemble;maladie_sifa;confiance;fiabilite;avis_eleveur;date'];
  let done = 0;
  const queue = [...list];
  async function worker() {
    while (queue.length) {
      const r = queue.shift();
      try {
        const res = await fetch(urls[r.photo_path]);
        if (!res.ok) throw new Error('HTTP ' + res.status);
        const blob = await res.blob();
        const set = flat ? 'photos' : splitOf(r.id);
        const name = `${r.id.slice(0, 8)}_${r.ref}.jpg`;
        const path = `${root}/${set}/${r.classe}/${name}`;
        zip.file(path, blob);
        manifest.push([path.slice(root.length + 1), r.classe, set, r.maladie_app || '', r.confiance ?? '', r.fiabilite || '', r.avis || '', r.cree_le.slice(0, 10)].join(';'));
      } catch (e) { console.warn('photo ignorée', r.id, e); }
      onProgress?.(++done, list.length);
    }
  }
  await Promise.all(Array.from({ length: 6 }, worker));
  zip.file(`${root}/manifest.csv`, '﻿' + manifest.join('\n'));
  zip.file(`${root}/LISEZMOI.txt`, [
    'Jeu de photos terrain SIFA (photos partagées par des éleveurs, étiquetées par un vétérinaire).',
    '',
    'Structure : train/ (70 %), val/ (15 %) et test_terrain/ (15 %), puis un dossier par classe.',
    'test_terrain/ ne sert JAMAIS à entraîner : il mesure la qualité sur de vraies photos de terrain.',
    '',
    'Utilisation dans Colab (voir le carnet SIFA_entrainement_v2) :',
    '  1. Envoyer ce ZIP dans Colab et le décompresser.',
    `  2. Lancer l'entraînement avec : --terrain /content/${root}`,
    '',
    `Généré le ${date} : ${list.length} photo(s).`,
  ].join('\n'));
  const blob = await zip.generateAsync({ type: 'blob', compression: 'STORE', streamFiles: true });
  download(`${root}${flat ? '_selection' : ''}.zip`, blob);
  return { count: list.length, skipped: rows.length - list.length, bytes: blob.size };
}
