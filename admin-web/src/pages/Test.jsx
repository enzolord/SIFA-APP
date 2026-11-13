import { useCallback, useEffect, useRef, useState } from 'react';
import { Armed, Bar, Card, Grid, Note, Pill, useToast } from '../ui.jsx';
import { CLASSES, L, classLabel, lab, must, pct, sb } from '../lib.js';
import { analyze, askGemini, loadModel } from '../classify.js';
import { useSession } from '../session.jsx';

const MAX_W = 1280;
const ISSUE_TXT = {
  notDropping: 'Le modèle pense que ce n’est pas une fiente.', tooDark: 'Photo trop sombre.', tooPlain: 'Surface trop unie : pas de détail visible.',
  unclear: 'Photo peu claire : le modèle hésite trop.',
};

/** Photo (image ou vidéo) -> JPEG réduit à 1280 px, comme dans l'application. */
function toJpeg(source, w, h) {
  const k = Math.min(1, MAX_W / w), c = document.createElement('canvas');
  c.width = Math.round(w * k); c.height = Math.round(h * k);
  c.getContext('2d').drawImage(source, 0, 0, c.width, c.height);
  return new Promise(res => c.toBlob(b => res({ blob: b, canvas: c }), 'image/jpeg', .9));
}
const b64 = blob => new Promise(res => { const r = new FileReader(); r.onload = () => res(String(r.result).split(',')[1]); r.readAsDataURL(blob); });

export default function Test() {
  const toast = useToast(); const { me } = useSession();
  const video = useRef(); const stream = useRef(); const fileIn = useRef();
  const [cam, setCam] = useState({ on: false, err: '', facing: 'environment' });
  const [photo, setPhoto] = useState(null);   // { url, blob, canvas }
  const [res, setRes] = useState(null);       // { model, gemini }
  const [busy, setBusy] = useState(false);
  const [saved, setSaved] = useState(null);
  const [history, setHistory] = useState([]);
  const [modelInfo, setModelInfo] = useState('Chargement du modèle…');

  useEffect(() => { loadModel().then(m => setModelInfo(`Modèle version ${m.version} · ${m.labels.join(', ')}`)).catch(e => setModelInfo('Modèle indisponible : ' + e.message)); }, []);
  const stop = useCallback(() => { stream.current?.getTracks().forEach(t => t.stop()); stream.current = null; setCam(c => ({ ...c, on: false })); }, []);
  useEffect(() => stop, [stop]);

  async function start(facing = cam.facing) {
    stop();
    if (!navigator.mediaDevices?.getUserMedia) return setCam({ on: false, err: 'La caméra n’est pas disponible ici (il faut une adresse https). Utilisez « Choisir une photo ».', facing });
    try {
      const s = await navigator.mediaDevices.getUserMedia({ video: { facingMode: { ideal: facing }, width: { ideal: 1920 }, height: { ideal: 1080 } }, audio: false });
      stream.current = s; setCam({ on: true, err: '', facing });
      requestAnimationFrame(() => { if (video.current) { video.current.srcObject = s; video.current.play().catch(() => {}); } });
    } catch (e) { setCam({ on: false, err: e.name === 'NotAllowedError' ? 'Accès à la caméra refusé : autorisez-la dans le navigateur.' : 'Caméra impossible : ' + e.message, facing }); }
  }

  async function run(source, w, h) {
    setBusy(true); setRes(null); setSaved(null);
    try {
      const { blob, canvas } = await toJpeg(source, w, h);
      const url = URL.createObjectURL(blob);
      setPhoto({ url, blob, canvas });
      const [model, gemini] = await Promise.all([analyze(canvas).catch(e => ({ error: e.message })), b64(blob).then(askGemini)]);
      const r = { model, gemini, at: Date.now(), url };
      setRes(r); setHistory(h => [r, ...h].slice(0, 8));
    } catch (e) { toast('Analyse impossible : ' + e.message, true); }
    setBusy(false);
  }
  const snap = () => { const v = video.current; if (v?.videoWidth) run(v, v.videoWidth, v.videoHeight); };
  const onFile = async e => {
    const f = e.target.files?.[0]; e.target.value = ''; if (!f) return;
    try { const bmp = await createImageBitmap(f); await run(bmp, bmp.width, bmp.height); } catch { toast('Image illisible.', true); }
  };

  async function save(classe) {
    if (!photo || !res) return;
    try {
      const id = crypto.randomUUID().replace(/-/g, '').slice(0, 16), ref = String(Date.now());
      const appareil = 'admin-test-' + id, path = `${appareil}/${ref}.jpg`;
      const up = await sb.storage.from('echantillons').upload(path, photo.blob, { contentType: 'image/jpeg' });
      if (up.error) throw up.error;
      const m = res.model || {};
      await must(sb.from('echantillons').insert({
        appareil, ref, photo_path: path, maladie_app: m.top || null, confiance: m.probs && m.top ? +m.probs[m.top].toFixed(3) : null, fiabilite: null, signes: [], langue: 'fr', version_app: 'admin-test',
        ...(classe ? { statut: 'valide', classe_validee: classe, valide_par: me.id, valide_le: new Date().toISOString() } : {}),
      }));
      setSaved(classe ? classLabel(classe) : 'à valider'); toast(classe ? `Ajoutée à la galerie : ${classLabel(classe)}.` : 'Ajoutée à la galerie (à valider).');
    } catch (e) { toast('Ajout impossible : ' + e.message, true); }
  }

  const m = res?.model, g = res?.gemini;
  return <>
    <Note style={{ marginBottom: 14 }}>Testez le modèle de SIFA avec la caméra de cet appareil ou une photo. Le résultat est celui de l’application (même modèle, mêmes contrôles) ; l’avis de Gemini est ajouté pour comparer. Rien n’est envoyé à la galerie sans votre clic.</Note>
    <Grid>
      <Card title="Photographier une fiente" sub={modelInfo}>
        <div style={{ position: 'relative', background: 'var(--sunken)', borderRadius: 12, overflow: 'hidden', aspectRatio: '4/3', display: 'grid', placeItems: 'center' }}>
          {cam.on ? <video ref={video} playsInline muted style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
            : photo ? <img src={photo.url} alt="Dernière photo" style={{ width: '100%', height: '100%', objectFit: 'contain' }} />
            : <span className="muted" style={{ padding: 20, textAlign: 'center' }}>Démarrez la caméra ou choisissez une photo.</span>}
        </div>
        {cam.err && <Note tone="bad" style={{ marginTop: 10 }}>{cam.err}</Note>}
        <div className="actions">
          {!cam.on ? <button className="btn" type="button" onClick={() => start()}>Démarrer la caméra</button>
            : <><button className="btn" type="button" disabled={busy} onClick={snap}>Prendre la photo</button>
              <button className="btn sec" type="button" onClick={() => start(cam.facing === 'environment' ? 'user' : 'environment')}>Changer de caméra</button>
              <button className="btn sec" type="button" onClick={stop}>Arrêter</button></>}
          <button className="btn sec" type="button" onClick={() => fileIn.current.click()}>Choisir une photo</button>
          <input ref={fileIn} type="file" accept="image/*" capture="environment" hidden onChange={onFile} />
        </div>
        {busy && <p className="muted" style={{ marginTop: 10 }}>Analyse en cours…</p>}
      </Card>
      <Card title="Résultat" sub="Modèle embarqué + avis de Gemini.">
        {!res ? <p className="muted">Aucune analyse pour le moment.</p> : <>
          {m?.error ? <Note tone="bad">Modèle : {m.error}</Note>
            : m?.issue && !m.probs ? <Note tone="warn"><b>Photo refusée.</b> {ISSUE_TXT[m.issue]}</Note>
            : <>
              {m.issue && <Note tone="warn" style={{ marginBottom: 10 }}><b>L’application refuserait cette photo.</b> {ISSUE_TXT[m.issue]} Voici quand même les probabilités :</Note>}
              <p style={{ margin: '0 0 8px' }}>Le modèle annonce <b>{L.maladie[m.top]}</b> ({pct(m.probs[m.top], 1, 0)}).</p>
              {Object.entries(m.probs).sort((a, b) => b[1] - a[1]).map(([k, v]) => <div className="todo" style={{ alignItems: 'center', padding: '6px 0' }} key={k}><div style={{ width: 120 }}>{L.maladie[k]}</div><div style={{ flex: 1 }}><Bar value={v} max={1} /></div><b style={{ width: 52, textAlign: 'right' }}>{pct(v, 1, 0)}</b></div>)}
            </>}
          {m?.raw && <details style={{ marginTop: 8 }}><summary className="muted">Sorties brutes du modèle (version {m.version})</summary>
            <div className="mono" style={{ marginTop: 6 }}>{m.raw.map(r => `${r.label} : ${(100 * r.p).toFixed(1)} %`).join('\n').split('\n').map((x, i) => <div key={i}>{x}</div>)}</div></details>}
          <h3 style={{ margin: '16px 0 6px' }}>Avis de Gemini</h3>
          {g.verdict === 'dropping' ? <Pill tone="ok">Gemini : c’est une fiente</Pill>
            : g.verdict === 'notDropping' ? <Pill tone="bad">Gemini : autre chose{g.objet ? ` (${g.objet})` : ''}</Pill>
            : <Pill tone="warn">{lab(L.gemini, 'unknown')}{g.status ? ` · erreur ${g.status}` : ''}</Pill>}
          <span className="muted" style={{ marginLeft: 8 }}>{g.ms} ms{g.confiance != null ? ` · certitude ${pct(g.confiance, 1, 0)}` : ''}</span>
          {g.verdict === 'unknown' && g.erreur && <div className="muted" style={{ marginTop: 4 }}>{g.erreur}</div>}
          <h3 style={{ margin: '16px 0 6px' }}>Ajouter à la galerie d’entraînement</h3>
          {saved ? <Pill tone="ok">Ajoutée : {saved}</Pill> : <>
            <p className="muted" style={{ margin: '0 0 6px' }}>Si vous savez ce que c’est (ou si un vétérinaire l’a confirmé), choisissez la classe. Sinon, ajoutez-la « à valider ».</p>
            <div className="classbtns">{CLASSES.map(c => <button key={c.id} className="btn small sec" type="button" onClick={() => save(c.id)}>{c.label}</button>)}</div>
            <div className="actions"><button className="btn small" type="button" onClick={() => save(null)}>Ajouter à valider</button></div></>}
        </>}
      </Card>
    </Grid>
    {history.length > 1 && <Card title="Derniers essais"><div className="gallery">{history.map((h, i) => (
      <div className="thumb" key={h.at} style={{ cursor: 'default' }}><img src={h.url} alt={`Essai ${i + 1}`} />
        <div className="tag"><Pill tone={h.model?.probs && !h.model.issue ? 'ok' : 'warn'}>{h.model?.top ? L.maladie[h.model.top] : 'Refusée'}</Pill></div></div>))}</div></Card>}
  </>;
}
