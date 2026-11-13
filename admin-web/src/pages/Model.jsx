import { useRef, useState } from 'react';
import { Armed, Async, Card, Pill, useAsync, useToast } from '../ui.jsx';
import { URL_, must, sb } from '../lib.js';

const pubUrl = f => `${URL_}/storage/v1/object/public/modeles/${f}?t=${Date.now()}`;
const sha = async buf => [...new Uint8Array(await crypto.subtle.digest('SHA-256', buf))].map(b => b.toString(16).padStart(2, '0')).join('');
const up = async (path, body, type) => { const { error } = await sb.storage.from('modeles').upload(path, body, { upsert: true, contentType: type, cacheControl: '0' }); if (error) throw new Error(path + ' : ' + error.message); };
const publish = async m => { const txt = JSON.stringify(m, null, 2); await up(`manifest_v${m.version}.json`, new Blob([txt]), 'application/json'); await up('manifest.json', new Blob([txt]), 'application/json'); };

export default function Model() {
  const st = useAsync(async () => {
    let cur = null;
    try { const r = await fetch(pubUrl('manifest.json')); if (r.ok) cur = await r.json(); } catch { /* aucun modèle publié */ }
    const { data: files } = await sb.storage.from('modeles').list('', { limit: 200 });
    const versions = (files || []).map(f => /^manifest_v(\d+)\.json$/.exec(f.name)).filter(Boolean).map(m => +m[1]).sort((a, b) => b - a);
    return { cur, versions };
  }, []);
  return <Async state={st}>{({ cur, versions }) => <Publisher cur={cur} versions={versions} reload={st.reload} />}</Async>;
}

function Publisher({ cur, versions, reload }) {
  const toast = useToast();
  const [model, setModel] = useState(null); const [labels, setLabels] = useState(null);
  const [check, setCheck] = useState({ tone: '', lines: [] }); const [busy, setBusy] = useState(false);
  const fM = useRef(), fL = useRef();
  const next = (cur ? cur.version : 1) + 1;
  async function validate() {
    const lines = []; let m = null, l = null;
    try {
      if (fL.current.files[0]) {
        l = JSON.parse(await fL.current.files[0].text());
        if (!Array.isArray(l) || !l.every(x => typeof x === 'string')) throw new Error('labels.json doit être une liste de textes.');
        const low = l.join(' ').toLowerCase(), miss = ['cocci', 'salmo', 'castle', 'health'].filter(k => !low.includes(k));
        if (miss.length) throw new Error('Étiquettes manquantes : ' + miss.join(', '));
        lines.push('✔ Étiquettes : ' + l.join(', '));
      }
      if (fM.current.files[0]) {
        m = await fM.current.files[0].arrayBuffer();
        if (m.byteLength < 1e5 || m.byteLength > 6e7) throw new Error('Taille de modèle inattendue.');
        lines.push(`✔ Modèle : ${(m.byteLength / 1e6).toFixed(1)} Mo`);
      }
      if (m && l) lines.push(`→ sera publié en version ${next}`);
      setCheck({ tone: '', lines }); setModel(m); setLabels(l);
    } catch (e) { setCheck({ tone: 'bad', lines: ['✖ ' + e.message] }); setModel(null); setLabels(null); }
  }
  return <>
    <Card title="Publier un nouveau modèle" sub="Choisissez les deux fichiers sortis de l’entraînement Colab. Version, empreinte et manifeste sont gérés automatiquement ; les téléphones le récupèrent au prochain lancement en ligne.">
      {cur ? <p>Version publiée : <b>{cur.version}</b> · {(cur.taille / 1e6).toFixed(1)} Mo · étiquettes : {cur.labels.join(', ')}</p> : <p className="muted">Aucun modèle publié : les téléphones utilisent celui livré dans l’application (version 1).</p>}
      <label className="f">Fichier modèle (sifa_fp16.tflite)</label><input ref={fM} type="file" accept=".tflite" onChange={validate} />
      <label className="f">Fichier étiquettes (labels.json)</label><input ref={fL} type="file" accept=".json" onChange={validate} />
      <div className={check.tone ? 'note ' + check.tone : 'muted'} style={{ marginTop: 8 }}>{check.lines.map((x, i) => <div key={i}>{x}</div>)}</div>
      <div className="actions"><button className="btn" type="button" disabled={!model || !labels || busy} onClick={async () => {
        setBusy(true);
        try { const name = `sifa_v${next}.tflite`; await up(name, new Blob([model]), 'application/octet-stream');
          await publish({ version: next, fichier: name, labels, sha256: await sha(model), taille: model.byteLength });
          toast(`Version ${next} publiée.`); setModel(null); setLabels(null); setCheck({ tone: '', lines: [] }); fM.current.value = ''; fL.current.value = ''; reload();
        } catch (e) { toast('Publication : ' + e.message, true); }
        setBusy(false);
      }}>Publier pour tous les téléphones</button></div>
    </Card>
    <Card title="Anciennes versions">
      {versions.length ? versions.map(v => <div className="todo" style={{ alignItems: 'center' }} key={v}>
        <div style={{ flex: 1 }}>Version {v} {cur && cur.version === v && <Pill tone="ok">en ligne</Pill>}</div>
        <Armed className="btn small sec" label="Remettre en ligne" onConfirm={async () => {
          try { const old = await (await fetch(pubUrl(`manifest_v${v}.json`))).json(); await publish({ ...old, version: next }); toast(`Contenu de la version ${v} republié.`); reload(); }
          catch (e) { toast('Retour arrière : ' + e.message, true); }
        }} /></div>) : <p className="muted">Aucune version archivée.</p>}
    </Card>
  </>;
}
