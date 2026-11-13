import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { Route, Routes } from 'react-router-dom';
import { Armed, Async, Card, ChartBox, Grid, Kpi, Kpis, Note, Pill, SubTabs, col, useAsync, useToast } from '../ui.jsx';
import { CLASSES, L, classLabel, fdate, must, nf, pct, sb } from '../lib.js';
import { buildZip, countByClassSplit, guess, loadSamples, pickDataset, removeSamples, setLabel, signedUrls } from '../samples.js';
import { useSession } from '../session.jsx';
import Model from './Model.jsx';

const TABS = [['/entrainement', 'Galerie', true], ['/entrainement/etiquetage', 'Étiquetage'], ['/entrainement/jeu', 'Jeu de données (ZIP)'], ['/entrainement/historique', 'Entraînements'], ['/entrainement/modele', 'Publier le modèle']];
const STATUT = { a_valider: ['À valider', 'warn'], valide: ['Validée', 'ok'], rejete: ['Rejetée', 'bad'] };
const MIN_PER_CLASS = 50;

function useSamples() {
  const st = useAsync(loadSamples, []);
  useEffect(() => { const f = () => st.reload(); window.addEventListener('sifa-refresh', f); return () => window.removeEventListener('sifa-refresh', f); }, [st.reload]); // eslint-disable-line
  return st;
}

function useUrls(paths) {
  const [urls, setUrls] = useState({});
  const key = paths.join('|');
  useEffect(() => {
    let alive = true;
    if (paths.length) signedUrls(paths).then(u => alive && setUrls(u)).catch(e => console.warn(e));
    return () => { alive = false; };
  }, [key]); // eslint-disable-line
  return urls;
}

function ClassButtons({ onPick, current, withKeys }) {
  return <div className="classbtns">{CLASSES.map(c => (
    <button key={c.id} type="button" className={'btn small ' + (current === c.id ? '' : 'sec')} onClick={() => onPick(c.id)}>
      {withKeys && <span className="kbd" style={{ marginRight: 6 }}>{c.key}</span>}{c.label}</button>))}</div>;
}

function Info({ r }) {
  return <div style={{ display: 'grid', gap: 6 }}>
    <div><Pill tone={STATUT[r.statut][1]}>{STATUT[r.statut][0]}</Pill> {r.classe_validee && <Pill tone="ok">{classLabel(r.classe_validee)}</Pill>}</div>
    <div><b>SIFA a annoncé</b> : {L.maladie[r.maladie_app] || '—'} {r.confiance != null && <span className="muted">({pct(r.confiance, 1)} · fiabilité {(L.fiab[r.fiabilite] || '—').toLowerCase()})</span>}</div>
    <div><b>Avis de l’éleveur</b> : {r.avis === 'juste' ? 'a jugé le résultat juste' : r.avis === 'faux' ? `a jugé le résultat faux${r.reelle ? ` (selon lui : ${L.maladie[r.reelle] || r.reelle})` : ''}` : 'aucun avis'}</div>
    {Array.isArray(r.signes) && r.signes.length > 0 && <div><b>Signes déclarés</b> : {r.signes.join(', ')}</div>}
    <div className="muted">Reçue le {fdate(r.cree_le)} · version {r.version_app || '—'} · langue {r.langue || '—'}</div>
  </div>;
}

/* ───────── Galerie ───────── */
function Gallery() {
  const st = useSamples();
  return <Async state={st}>{rows => <GalleryView rows={rows} reload={st.reload} />}</Async>;
}
function GalleryView({ rows, reload }) {
  const toast = useToast(); const { me } = useSession();
  const [f, setF] = useState({ statut: 'tous', classe: 'toutes', avis: 'tous' });
  const [page, setPage] = useState(0); const [sel, setSel] = useState(new Set()); const [open, setOpen] = useState(null);
  const [zip, setZip] = useState(null);
  const filtered = useMemo(() => rows.filter(r =>
    (f.statut === 'tous' || r.statut === f.statut) && (f.classe === 'toutes' || guess(r) === f.classe || (f.classe === 'sans' && !guess(r))) &&
    (f.avis === 'tous' || (f.avis === 'aucun' ? !r.avis : r.avis === f.avis))), [rows, f]);
  useEffect(() => setPage(0), [f]);
  const PER = 60, pageRows = filtered.slice(page * PER, (page + 1) * PER);
  const urls = useUrls(pageRows.map(r => r.photo_path));
  const toggle = id => setSel(s => { const n = new Set(s); n.has(id) ? n.delete(id) : n.add(id); return n; });
  const chosen = rows.filter(r => sel.has(r.id));
  const act = async (fn, ok) => { try { await fn(); toast(ok); setSel(new Set()); setOpen(null); reload(); } catch (e) { toast('Action impossible : ' + e.message, true); } };
  const cur = open && rows.find(r => r.id === open);
  const counts = { a_valider: rows.filter(r => r.statut === 'a_valider').length, valide: rows.filter(r => r.statut === 'valide').length, rejete: rows.filter(r => r.statut === 'rejete').length };
  const chip = (k, v, label) => <button key={v} className="chip" type="button" aria-pressed={f[k] === v} onClick={() => setF({ ...f, [k]: v })}>{label}</button>;
  return <>
    <Kpis>
      <Kpi label="Photos reçues" value={nf(rows.length)} detail="Partagées avec l’accord des éleveurs" />
      <Kpi label="À valider" value={nf(counts.a_valider)} tone={counts.a_valider ? 'bad' : ''} />
      <Kpi label="Validées" value={nf(counts.valide)} tone="good" />
      <Kpi label="Rejetées" value={nf(counts.rejete)} />
    </Kpis>
    {!rows.length && <Note tone="warn">Aucune photo reçue pour le moment. Les éleveurs peuvent partager une photo depuis l’écran de résultat, ou activer le partage automatique dans Profil (nouvelle version de l’application nécessaire).</Note>}
    <Card title="Toutes les photos de fientes" sub="Cliquez sur une photo pour la voir en grand, l’étiqueter ou la supprimer. Cochez plusieurs photos pour agir en une fois.">
      <div className="field-inline" style={{ marginBottom: 8 }}><b>Statut</b>{chip('statut', 'tous', 'Toutes')}{chip('statut', 'a_valider', 'À valider')}{chip('statut', 'valide', 'Validées')}{chip('statut', 'rejete', 'Rejetées')}</div>
      <div className="field-inline" style={{ marginBottom: 8 }}><b>Classe</b>{chip('classe', 'toutes', 'Toutes')}{CLASSES.map(c => chip('classe', c.id, c.label))}{chip('classe', 'sans', 'Sans classe')}</div>
      <div className="field-inline" style={{ marginBottom: 14 }}><b>Avis éleveur</b>{chip('avis', 'tous', 'Tous')}{chip('avis', 'juste', 'Juste')}{chip('avis', 'faux', 'Faux')}{chip('avis', 'aucun', 'Aucun')}</div>
      <div className="field-inline" style={{ marginBottom: 14 }}>
        <span className="muted">{nf(filtered.length)} photo(s) · {sel.size} sélectionnée(s)</span>
        <button className="btn small sec" type="button" onClick={() => setSel(new Set(pageRows.map(r => r.id)))}>Cocher cette page</button>
        <button className="btn small sec" type="button" onClick={() => setSel(new Set(filtered.map(r => r.id)))}>Tout cocher ({nf(filtered.length)})</button>
        {sel.size > 0 && <button className="btn small sec" type="button" onClick={() => setSel(new Set())}>Décocher</button>}
      </div>
      {sel.size > 0 && <div className="note" style={{ marginBottom: 14 }}>
        <b>{sel.size} photo(s) cochée(s)</b> : valider comme
        <ClassButtons onPick={c => act(() => setLabel([...sel], { statut: 'valide', classe: c }, me.id), 'Photos validées.')} />
        <div className="actions">
          <button className="btn small sec" type="button" onClick={() => act(() => setLabel([...sel], { statut: 'rejete' }, me.id), 'Photos rejetées.')}>Rejeter</button>
          <button className="btn small sec" type="button" onClick={() => act(() => setLabel([...sel], { statut: 'a_valider' }, me.id), 'Remises à valider.')}>Remettre à valider</button>
          <button className="btn small" type="button" disabled={!!zip} onClick={async () => {
            const usable = chosen.map(r => ({ ...r, classe: guess(r) || 'Sans_classe' }));
            setZip({ n: 0, total: usable.length });
            try { const res = await buildZip(usable, { flat: true, onProgress: (n, total) => setZip({ n, total }) }); toast(`ZIP téléchargé : ${res.count} photo(s).`); } catch (e) { toast('ZIP impossible : ' + e.message, true); }
            setZip(null);
          }}>{zip ? `ZIP ${zip.n}/${zip.total}…` : 'Télécharger la sélection (ZIP)'}</button>
          <Armed label="Supprimer" onConfirm={() => act(() => removeSamples(chosen), 'Photos supprimées.')} />
        </div></div>}
      {pageRows.length ? <div className="gallery">{pageRows.map(r => (
        <div key={r.id} className={'thumb' + (sel.has(r.id) ? ' sel' : '')} onClick={() => setOpen(r.id)} role="button" tabIndex={0} onKeyDown={e => e.key === 'Enter' && setOpen(r.id)}>
          {urls[r.photo_path] ? <img src={urls[r.photo_path]} alt="Fiente" loading="lazy" /> : null}
          <input className="chk" type="checkbox" checked={sel.has(r.id)} onClick={e => e.stopPropagation()} onChange={() => toggle(r.id)} aria-label="Sélectionner" />
          <div className="tag"><Pill tone={STATUT[r.statut][1]}>{r.classe_validee ? classLabel(r.classe_validee) : STATUT[r.statut][0]}</Pill>{r.avis === 'faux' && <Pill tone="bad">Éleveur : faux</Pill>}</div>
        </div>))}</div> : <div className="empty">Aucune photo avec ces filtres.</div>}
      {filtered.length > PER && <div className="actions" style={{ justifyContent: 'center' }}>
        <button className="btn sec small" type="button" disabled={page === 0} onClick={() => setPage(page - 1)}>← Précédent</button>
        <span className="muted">Page {page + 1} / {Math.ceil(filtered.length / PER)}</span>
        <button className="btn sec small" type="button" disabled={(page + 1) * PER >= filtered.length} onClick={() => setPage(page + 1)}>Suivant →</button></div>}
    </Card>
    {cur && <Lightbox r={cur} url={urls[cur.photo_path]} onClose={() => setOpen(null)}
      onLabel={c => act(() => setLabel([cur.id], { statut: 'valide', classe: c }, me.id), 'Photo validée.')}
      onReject={() => act(() => setLabel([cur.id], { statut: 'rejete' }, me.id), 'Photo rejetée.')}
      onReset={() => act(() => setLabel([cur.id], { statut: 'a_valider' }, me.id), 'Remise à valider.')}
      onDelete={() => act(() => removeSamples([cur]), 'Photo supprimée.')} />}
  </>;
}
function Lightbox({ r, url, onClose, onLabel, onReject, onReset, onDelete }) {
  useEffect(() => { const k = e => e.key === 'Escape' && onClose(); window.addEventListener('keydown', k); return () => window.removeEventListener('keydown', k); }, [onClose]);
  return <div className="lightbox" onClick={onClose} role="dialog" aria-modal="true"><div className="box" onClick={e => e.stopPropagation()}>
    <div>{url ? <img src={url} alt="Fiente en grand" /> : <div className="empty">Chargement…</div>}</div>
    <div><Info r={r} /><h3 style={{ marginTop: 14 }}>Étiqueter</h3><ClassButtons current={r.classe_validee} onPick={onLabel} />
      <div className="actions"><button className="btn small sec" type="button" onClick={onReject}>Rejeter (photo inutilisable)</button>
        {r.statut !== 'a_valider' && <button className="btn small sec" type="button" onClick={onReset}>Remettre à valider</button>}
        <Armed label="Supprimer" onConfirm={onDelete} /><button className="btn small sec" type="button" onClick={onClose}>Fermer</button></div></div>
  </div></div>;
}

/* ───────── Étiquetage ───────── */
function Labeling() {
  const st = useSamples();
  return <Async state={st}>{rows => <LabelingView rows={rows} reload={st.reload} />}</Async>;
}
function LabelingView({ rows }) {
  const toast = useToast(); const { me } = useSession();
  const queue = useMemo(() => rows.filter(r => r.statut === 'a_valider').sort((a, b) =>
    (b.avis === 'faux') - (a.avis === 'faux') || (a.confiance ?? 1) - (b.confiance ?? 1)), []); // eslint-disable-line
  const [i, setI] = useState(0); const [done, setDone] = useState(0); const [busy, setBusy] = useState(false);
  const r = queue[i];
  const urls = useUrls(queue.slice(i, i + 4).map(x => x.photo_path));
  const doLabel = useCallback(async patch => {
    if (!r || busy) return; setBusy(true);
    try { await setLabel([r.id], patch, me.id); setDone(d => d + 1); setI(n => n + 1); } catch (e) { toast('Enregistrement impossible : ' + e.message, true); }
    setBusy(false);
  }, [r, busy, me.id, toast]);
  const ref = useRef(); ref.current = { doLabel, skip: () => setI(n => n + 1) };
  useEffect(() => {
    const k = e => {
      if (/input|textarea|select/i.test(e.target.tagName)) return;
      const c = CLASSES.find(x => x.key === e.key);
      if (c) ref.current.doLabel({ statut: 'valide', classe: c.id });
      else if (e.key === 'r' || e.key === 'R') ref.current.doLabel({ statut: 'rejete' });
      else if (e.key === 's' || e.key === 'S' || e.key === ' ') { e.preventDefault(); ref.current.skip(); }
    };
    window.addEventListener('keydown', k); return () => window.removeEventListener('keydown', k);
  }, []);
  if (!queue.length) return <Card title="Rien à étiqueter"><p className="muted">Toutes les photos reçues sont validées ou rejetées. Les nouvelles photos apparaîtront ici.</p></Card>;
  if (!r) return <Card title="File terminée"><p>Vous avez traité {done} photo(s). Actualisez pour voir les nouvelles photos.</p></Card>;
  return <>
    <Note tone="warn" style={{ marginBottom: 14 }}>L’étiquette doit venir d’un vétérinaire ou de quelqu’un qui connaît les fientes de poulets. Une mauvaise étiquette abîme le modèle. En cas de doute, rejetez la photo.</Note>
    <Card title={`Photo ${i + 1} sur ${queue.length}`} sub="Les photos jugées fausses par l’éleveur et celles où SIFA doutait le plus passent en premier.">
      <div className="progress" style={{ marginBottom: 14 }}><i style={{ width: (100 * i / queue.length) + '%' }} /></div>
      <Grid>
        <div>{urls[r.photo_path] ? <img src={urls[r.photo_path]} alt="Fiente à étiqueter" style={{ width: '100%', borderRadius: 12, maxHeight: '60vh', objectFit: 'contain', background: 'var(--sunken)' }} /> : <div className="empty">Chargement…</div>}</div>
        <div><Info r={r} /><h3 style={{ marginTop: 14 }}>Que voyez-vous ?</h3><ClassButtons onPick={c => doLabel({ statut: 'valide', classe: c })} withKeys />
          <div className="actions"><button className="btn sec small" type="button" onClick={() => doLabel({ statut: 'rejete' })}><span className="kbd">R</span>&nbsp;Rejeter</button>
            <button className="btn sec small" type="button" onClick={() => setI(i + 1)}><span className="kbd">S</span>&nbsp;Passer</button></div>
          <p className="muted" style={{ marginTop: 12 }}>Raccourcis : touches 1 à 5 pour la classe, R pour rejeter, S ou espace pour passer.</p></div>
      </Grid>
    </Card>
  </>;
}

/* ───────── Jeu de données ───────── */
function Dataset() {
  const st = useSamples();
  return <Async state={st}>{rows => <DatasetView rows={rows} />}</Async>;
}
function DatasetView({ rows }) {
  const toast = useToast();
  const [juste, setJuste] = useState(false); const [prog, setProg] = useState(null);
  const data = useMemo(() => pickDataset(rows, { includeUnvalidatedJuste: juste }), [rows, juste]);
  const t = countByClassSplit(data);
  const weak = CLASSES.filter(c => c.id !== 'Autre' && t[c.id].total < MIN_PER_CLASS);
  const maxN = Math.max(1, ...CLASSES.map(c => t[c.id].total));
  const pendingJuste = rows.filter(r => r.statut === 'a_valider' && r.avis === 'juste').length;
  return <>
    <Kpis>
      <Kpi label="Photos dans le jeu" value={nf(data.length)} detail={juste ? 'Validées + jugées justes par l’éleveur' : 'Validées par un vétérinaire'} />
      <Kpi label="À valider" value={nf(rows.filter(r => r.statut === 'a_valider').length)} detail="Pas encore utilisables" />
      <Kpi label="Test terrain" value={nf(data.filter(r => countByClassSplit([r]) && true).length && Object.values(t).reduce((s, x) => s + x.test_terrain, 0))} detail="Réservées à la mesure, jamais à l’entraînement" />
    </Kpis>
    {weak.length > 0 && <Note tone="warn" style={{ marginBottom: 16 }}>Pas assez de photos validées pour : {weak.map(c => c.label).join(', ')} (minimum conseillé : {MIN_PER_CLASS} par classe). Avec trop peu de photos, le ré-entraînement risque de dégrader le modèle plutôt que de l’améliorer.</Note>}
    <Card title="Répartition par classe" sub="Un bon jeu est équilibré : évitez qu’une classe domine.">
      <div className="tablewrap"><table><thead><tr><th>Classe</th><th className="num">Entraînement</th><th className="num">Validation</th><th className="num">Test terrain</th><th className="num">Total</th><th /></tr></thead>
        <tbody>{CLASSES.map(c => <tr key={c.id}><td><b>{c.label}</b></td><td className="num">{t[c.id].train}</td><td className="num">{t[c.id].val}</td><td className="num">{t[c.id].test_terrain}</td><td className="num">{t[c.id].total}</td>
          <td style={{ width: '25%' }}><div className={'bar' + (c.id !== 'Autre' && t[c.id].total < MIN_PER_CLASS ? ' bad' : '')}><i style={{ width: (100 * t[c.id].total / maxN) + '%' }} /></div></td></tr>)}</tbody></table></div>
    </Card>
    <Card title="Télécharger le jeu de données" sub="Un fichier ZIP prêt pour l’entraînement : dossiers train / val / test_terrain, une sous-dossier par classe, un manifest.csv et un LISEZMOI.">
      <label className="switch"><input type="checkbox" checked={juste} onChange={e => setJuste(e.target.checked)} />Ajouter les photos non validées que l’éleveur a jugées « justes » ({nf(pendingJuste)}). Moins sûr : l’éleveur peut se tromper.</label>
      <div className="actions">
        <button className="btn" type="button" disabled={!data.length || !!prog} onClick={async () => {
          setProg({ n: 0, total: Math.min(data.length, 2500) });
          try { const res = await buildZip(data, { onProgress: (n, total) => setProg({ n, total }) }); toast(`ZIP téléchargé : ${res.count} photo(s), ${(res.bytes / 1e6).toFixed(0)} Mo.` + (res.skipped ? ` ${res.skipped} photo(s) au-delà de la limite de 2 500 ont été laissées de côté.` : '')); }
          catch (e) { toast('ZIP impossible : ' + e.message, true); }
          setProg(null);
        }}>{prog ? `Préparation ${prog.n}/${prog.total}…` : 'Télécharger le ZIP'}</button>
        {!data.length && <span className="muted">Validez d’abord quelques photos dans l’onglet Étiquetage.</span>}
      </div>
      {prog && <div className="progress" style={{ marginTop: 12 }}><i style={{ width: (100 * prog.n / prog.total) + '%' }} /></div>}
      <p className="muted" style={{ marginTop: 12 }}>Limite de 2 500 photos par archive (mémoire du navigateur). Gardez cet onglet ouvert pendant la préparation.</p>
    </Card>
    <Card title="Ensuite : ré-entraîner" sub="L’entraînement se fait sur Google Colab (carte graphique gratuite), pas dans cette page.">
      <ol style={{ paddingLeft: 20, margin: 0 }}>
        <li>Ouvrez le carnet <b>SIFA_entrainement_v2.ipynb</b> dans Colab.</li>
        <li>Envoyez le ZIP téléchargé et décompressez-le.</li>
        <li>Lancez l’entraînement avec l’option <span className="mono">--terrain</span> pointant vers le dossier décompressé.</li>
        <li>Récupérez <span className="mono">sifa_fp16.tflite</span>, <span className="mono">labels.json</span> et <span className="mono">rapport_test.txt</span>.</li>
        <li>Enregistrez le rapport dans l’onglet <b>Entraînements</b>, puis publiez le modèle dans l’onglet <b>Publier le modèle</b>.</li>
      </ol>
    </Card>
  </>;
}

/* ───────── Historique des entraînements ───────── */
function History() {
  const toast = useToast();
  const st = useAsync(() => must(sb.from('entrainements').select('*').order('cree_le', { ascending: true }).limit(200)), []);
  const [f, setF] = useState({ nom: '', version: '', rapport: '', notes: '', nb_train: '', nb_val: '', nb_test: '', nb_terrain: '' });
  const parsed = useMemo(() => {
    const t = f.rapport; const num = re => { const m = t.match(re); return m ? parseFloat(m[1]) : null; };
    return {
      exactitude: num(/EXACTITUDE TEST[^:]*:\s*([0-9.]+)/i), f1: num(/F1 macro\s*:\s*([0-9.]+)/i), exactitude_terrain: num(/EXACTITUDE TERRAIN[^:]*:\s*([0-9.]+)/i),
    };
  }, [f.rapport]);
  const set = (k, v) => setF(x => ({ ...x, [k]: v }));
  const int = v => (v === '' ? null : Math.max(0, parseInt(v, 10) || 0));
  return <Async state={st}>{rows => <>
    <Grid>
      <Card title="Exactitude au fil des entraînements" sub="La courbe « terrain » mesure les vraies photos d’éleveurs : c’est elle qui compte.">
        <ChartBox empty={!rows.length && 'Aucun entraînement enregistré.'} config={() => ({ type: 'line', data: { labels: rows.map(r => r.nom), datasets: [
          { label: 'Test (jeu public)', data: rows.map(r => r.exactitude != null ? +(100 * r.exactitude).toFixed(1) : null), borderColor: col('--c3'), backgroundColor: col('--c3'), tension: .25, spanGaps: true },
          { label: 'Terrain', data: rows.map(r => r.exactitude_terrain != null ? +(100 * r.exactitude_terrain).toFixed(1) : null), borderColor: col('--c1'), backgroundColor: col('--c1'), tension: .25, spanGaps: true }] },
          options: { scales: { y: { min: 0, max: 100, ticks: { callback: v => v + ' %' } } }, plugins: { legend: { position: 'bottom' } } } })} />
      </Card>
      <Card title="Enregistrer un entraînement" sub="Collez le contenu de rapport_test.txt : les chiffres sont lus automatiquement.">
        <label className="f">Nom</label><input type="text" value={f.nom} onChange={e => set('nom', e.target.value)} placeholder="ex. v2 + 120 photos terrain" />
        <div className="row2"><div><label className="f">Version publiée dans l’app (si publié)</label><input type="text" inputMode="numeric" value={f.version} onChange={e => set('version', e.target.value)} /></div>
          <div><label className="f">Photos terrain utilisées</label><input type="text" inputMode="numeric" value={f.nb_terrain} onChange={e => set('nb_terrain', e.target.value)} /></div></div>
        <label className="f">Rapport (rapport_test.txt)</label><textarea value={f.rapport} onChange={e => set('rapport', e.target.value)} style={{ minHeight: 120, fontFamily: 'ui-monospace,monospace', fontSize: 12.5 }} />
        <p className="muted">Lu : exactitude {parsed.exactitude != null ? pct(parsed.exactitude, 1, 1) : '—'} · F1 {parsed.f1 != null ? parsed.f1.toFixed(3) : '—'} · terrain {parsed.exactitude_terrain != null ? pct(parsed.exactitude_terrain, 1, 1) : '—'}</p>
        <div className="actions"><button className="btn" type="button" onClick={async () => {
          try {
            if (!f.nom.trim()) throw new Error('Donnez un nom à cet entraînement.');
            await must(sb.from('entrainements').insert({ nom: f.nom.trim(), version_modele: int(f.version), nb_terrain: int(f.nb_terrain), ...parsed, rapport: f.rapport.slice(0, 20000) || null, notes: f.notes || null }));
            toast('Entraînement enregistré.'); setF({ nom: '', version: '', rapport: '', notes: '', nb_train: '', nb_val: '', nb_test: '', nb_terrain: '' }); st.reload();
          } catch (e) { toast('Enregistrement : ' + e.message, true); }
        }}>Enregistrer</button></div>
      </Card>
    </Grid>
    <Card title="Historique">
      {rows.length ? <div className="tablewrap"><table><thead><tr><th>Date</th><th>Nom</th><th className="num">Version app</th><th className="num">Photos terrain</th><th className="num">Exactitude test</th><th className="num">F1</th><th className="num">Exactitude terrain</th><th /></tr></thead>
        <tbody>{[...rows].reverse().map(r => <tr key={r.id}><td>{fdate(r.cree_le)}</td><td>{r.nom}</td><td className="num">{r.version_modele ?? '—'}</td><td className="num">{r.nb_terrain ?? '—'}</td>
          <td className="num">{r.exactitude != null ? pct(r.exactitude, 1, 1) : '—'}</td><td className="num">{r.f1 != null ? r.f1.toFixed(3) : '—'}</td><td className="num">{r.exactitude_terrain != null ? pct(r.exactitude_terrain, 1, 1) : '—'}</td>
          <td><Armed label="Supprimer" onConfirm={async () => { try { await must(sb.from('entrainements').delete().eq('id', r.id)); st.reload(); } catch (e) { toast('Suppression : ' + e.message, true); } }} /></td></tr>)}</tbody></table></div> : <p className="muted">Rien d’enregistré.</p>}
    </Card>
  </>}</Async>;
}

export default function Training() {
  return <><SubTabs items={TABS} /><Routes>
    <Route index element={<Gallery />} /><Route path="etiquetage" element={<Labeling />} /><Route path="jeu" element={<Dataset />} />
    <Route path="historique" element={<History />} /><Route path="modele" element={<Model />} />
  </Routes></>;
}
