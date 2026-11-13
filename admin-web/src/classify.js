import * as tf from '@tensorflow/tfjs-core';
import '@tensorflow/tfjs-backend-cpu';
import * as tflite from '@tensorflow/tfjs-tflite';
import { KEY, URL_ } from './lib.js';

/** Même logique que l'application (lib/services/classifier.dart) : 224x224, valeurs 0..255, trois vues moyennées. */
tflite.setWasmPath('/tflite/');
const SIZE = 224, MIN_CONFIDENCE = 0.55;
export const DISEASES = ['healthy', 'coccidiosis', 'salmonella', 'newcastle'];

export function diseaseForLabel(label) {
  const l = label.toLowerCase();
  if (l.includes('cocci')) return 'coccidiosis';
  if (l.includes('salmo')) return 'salmonella';
  if (l.includes('castle') || l.includes('ncd')) return 'newcastle';
  if (l.includes('health') || l.includes('sain')) return 'healthy';
  return null; // « Autre »
}

let loaded = null;
/** Modèle publié dans Supabase s'il existe (version > 1), sinon celui livré avec l'application (version 1). */
export async function loadModel() {
  if (loaded) return loaded;
  let url = '/modele/sifa_v1.tflite', labels = null, version = 1;
  try {
    const r = await fetch(`${URL_}/storage/v1/object/public/modeles/manifest.json?t=${Date.now()}`, { cache: 'no-store' });
    if (r.ok) {
      const m = await r.json();
      if (m.version > 1 && Array.isArray(m.labels) && m.fichier) { url = `${URL_}/storage/v1/object/public/modeles/${m.fichier}`; labels = m.labels; version = m.version; }
    }
  } catch { /* hors ligne ou aucun modèle publié : on garde le modèle intégré */ }
  if (!labels) labels = await (await fetch('/modele/labels_v1.json')).json();
  const model = await tflite.loadTFLiteModel(url);
  loaded = { model, labels, outputs: labels.map(diseaseForLabel), version };
  return loaded;
}
export function forgetModel() { loaded = null; }

function checkQuality(rgba) {
  const n = rgba.length / 4; let s = 0, s2 = 0;
  for (let i = 0; i < rgba.length; i += 4) { const y = .299 * rgba[i] + .587 * rgba[i + 1] + .114 * rgba[i + 2]; s += y; s2 += y * y; }
  const mean = s / n, std = Math.sqrt(Math.max(0, s2 / n - mean * mean));
  if (mean < 28) return 'tooDark';
  if (std < 10) return 'tooPlain';
  return null;
}

function toInput(rgba, view) {
  const out = new Float32Array(SIZE * SIZE * 3); let j = 0;
  for (let y = 0; y < SIZE; y++) { const sy = view === 2 ? SIZE - 1 - y : y;
    for (let x = 0; x < SIZE; x++) { const sx = view === 1 ? SIZE - 1 - x : x, i = (sy * SIZE + sx) * 4; out[j++] = rgba[i]; out[j++] = rgba[i + 1]; out[j++] = rgba[i + 2]; } }
  return out;
}

/** source : image ou canvas. Renvoie { issue } si refusée, sinon { probs, top, raw }. */
export async function analyze(source) {
  const m = await loadModel();
  const c = document.createElement('canvas'); c.width = c.height = SIZE;
  const ctx = c.getContext('2d', { willReadFrequently: true }); ctx.imageSmoothingQuality = 'high';
  ctx.drawImage(source, 0, 0, SIZE, SIZE);
  const rgba = ctx.getImageData(0, 0, SIZE, SIZE).data;
  const issue = checkQuality(rgba);
  if (issue) return { issue, version: m.version };
  const n = m.labels.length, sum = new Array(n).fill(0), tops = [];
  for (const view of [0, 1, 2]) {
    const input = tf.tensor(toInput(rgba, view), [1, SIZE, SIZE, 3], 'float32');
    const out = m.model.predict(input); const p = Array.from(await out.data());
    input.dispose(); out.dispose();
    let best = 0; for (let k = 0; k < n; k++) { sum[k] += p[k] / 3; if (p[k] > p[best]) best = k; }
    tops.push(best);
  }
  const raw = m.labels.map((l, k) => ({ label: l, p: sum[k] }));
  let other = 0; const probs = Object.fromEntries(DISEASES.map(d => [d, 0]));
  sum.forEach((v, k) => { const d = m.outputs[k]; if (d) probs[d] += v; else other += v; });
  const base = { raw, other, version: m.version };
  if (other >= .5) return { ...base, issue: 'notDropping' };
  const total = Object.values(probs).reduce((a, b) => a + b, 0);
  if (total <= 0) return { ...base, issue: 'unclear' };
  for (const d of DISEASES) probs[d] /= total;
  const top = DISEASES.reduce((a, b) => probs[b] > probs[a] ? b : a);
  if (probs[top] < MIN_CONFIDENCE) return { ...base, issue: 'unclear', probs, top };
  if (new Set(tops).size !== 1 && probs[top] < .75) return { ...base, issue: 'unclear', probs, top };
  return { ...base, probs, top };
}

/** Avis de Gemini (fonction Supabase verifier-fiente). Ne bloque jamais : renvoie 'unknown' en cas de problème. */
export async function askGemini(jpegBase64) {
  const t0 = performance.now();
  try {
    const r = await fetch(`${URL_}/functions/v1/verifier-fiente`, { method: 'POST', headers: { 'Content-Type': 'application/json', apikey: KEY, Authorization: `Bearer ${KEY}` }, body: JSON.stringify({ image: jpegBase64 }) });
    const ms = Math.round(performance.now() - t0);
    const j = await r.json().catch(() => ({}));
    if (!r.ok) return { verdict: 'unknown', status: r.status, erreur: j.erreur, ms };
    if (j.fiente === true) return { verdict: 'dropping', confiance: j.confiance, ms };
    if (j.fiente === false) return { verdict: 'notDropping', confiance: j.confiance, objet: j.objet_fr, ms };
    return { verdict: 'unknown', ms };
  } catch (e) { return { verdict: 'unknown', erreur: e.message, ms: Math.round(performance.now() - t0) }; }
}
