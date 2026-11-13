import { Link } from 'react-router-dom';
import { Route, Routes } from 'react-router-dom';
import { useStats, WithStats } from '../stats.jsx';
import { Async, Card, ChartBox, Grid, Kpi, Kpis, Note, Pill, RateTable, SimpleList, SubTabs, col, useAsync } from '../ui.jsx';
import { L, MALADIES, fdate, fetchEvents, lab, nf, pct, ratio, sb, must } from '../lib.js';

const TABS = [['/qualite', 'Vue globale', true], ['/qualite/maladies', 'Par maladie'], ['/qualite/fiabilite', 'Par fiabilité'], ['/qualite/confusions', 'Confusions'], ['/qualite/signes', 'Questions sur les signes'], ['/qualite/avis', 'Cas à vérifier']];
const MIN = 30;
const zero = { retours: 0, justes: 0 };

function Small({ q }) {
  return q.retours < MIN ? <Note tone="warn" style={{ marginBottom: 16 }}>Seulement {q.retours} avis : les pourcentages ne sont pas encore fiables (il faut au moins {MIN} avis). Le bouton « Ce résultat était-il juste ? » apparaît sous chaque résultat dans l’application.</Note> : null;
}

function Global() {
  return <WithStats>{s => {
    const q = s.qualite, a = s.analyses, sc = s.scans;
    const rejTotal = Object.entries(sc.par_issue).filter(([k]) => k !== 'ok').reduce((x, [, v]) => x + v, 0);
    return <>
      <Small q={q} />
      <Kpis>
        <Kpi label="Bonnes réponses" value={pct(q.justes, q.retours)} detail={`${nf(q.justes)} avis « juste »`} />
        <Kpi label="Mauvaises réponses" value={pct(q.faux, q.retours)} detail={`${nf(q.faux)} avis « faux »`} />
        <Kpi label="Avis reçus" value={nf(q.retours)} detail={`${pct(q.retours, a.total)} des analyses`} />
        <Kpi label="Confiance moyenne du modèle" value={a.confiance_moyenne != null ? pct(Number(a.confiance_moyenne), 1) : '—'} detail="Sur toutes les analyses" />
        <Kpi label="Photos refusées" value={pct(rejTotal, sc.total)} detail={`${nf(rejTotal)} sur ${nf(sc.total)} photos`} />
        <Kpi label="Analyses sans question" value={pct(a.photo_seule, a.total)} detail="Photo seule, moins fiable" />
      </Kpis>
      <Grid>
        <Card title="Bonnes et mauvaises réponses" sub="D’après l’avis des éleveurs.">
          <ChartBox empty={!q.retours && 'Aucun avis pour le moment.'} config={() => ({ type: 'doughnut', data: { labels: ['Bonnes réponses', 'Mauvaises réponses'], datasets: [{ data: [q.justes, q.faux], backgroundColor: [col('--ok'), col('--bad')], borderColor: col('--surface'), borderWidth: 2 }] }, options: { cutout: '65%', plugins: { legend: { position: 'bottom' } } } })} />
        </Card>
        <Card title="Photos acceptées et refusées" sub="Raison du refus quand ce n’est pas une fiente exploitable.">
          <ChartBox empty={!sc.total && 'Aucun scan sur la période.'} config={() => ({ type: 'bar', data: { labels: Object.keys(sc.par_issue).map(k => lab(L.issue, k)), datasets: [{ data: Object.values(sc.par_issue), backgroundColor: Object.keys(sc.par_issue).map(k => k === 'ok' ? col('--c1') : col('--c4')), borderRadius: 6 }] }, options: { indexAxis: 'y', plugins: { legend: { display: false } }, scales: { x: { beginAtZero: true } } } })} />
        </Card>
      </Grid>
    </>;
  }}</WithStats>;
}

function ByDisease() {
  return <WithStats>{s => {
    const q = s.qualite, a = s.analyses;
    const rows = MALADIES.map(k => [L.maladie[k], q.par_maladie[k] || zero, k]);
    return <>
      <Small q={q} />
      <Grid>
        <Card title="Quand SIFA annonce cette maladie…" sub="…combien de fois a-t-elle raison, selon l’éleveur ?"><RateTable rows={rows.map(([l, o]) => [l, o])} /></Card>
        <Card title="Taux de bonnes réponses" sub="Une barre courte = maladie à travailler en priorité.">
          <ChartBox empty={!q.retours && 'Aucun avis.'} config={() => ({ type: 'bar', data: { labels: rows.map(r => r[0]), datasets: [{ data: rows.map(r => r[1].retours ? Math.round(100 * r[1].justes / r[1].retours) : 0), backgroundColor: rows.map(r => r[1].retours && r[1].justes / r[1].retours < .6 ? col('--bad') : col('--c1')), borderRadius: 6 }] }, options: { plugins: { legend: { display: false } }, scales: { y: { beginAtZero: true, max: 100 } } } })} />
        </Card>
      </Grid>
      <Card title="Fréquence des résultats" sub="Part de chaque résultat parmi les analyses de la période."><SimpleList pairs={MALADIES.map(k => [L.maladie[k], a.par_maladie[k] || 0])} /></Card>
    </>;
  }}</WithStats>;
}

function Reliability() {
  return <WithStats>{s => {
    const q = s.qualite, hi = q.par_fiabilite.high, lo = q.par_fiabilite.low;
    const calib = hi && lo && hi.retours >= 10 && lo.retours >= 10 && hi.justes / hi.retours < lo.justes / lo.retours;
    return <>
      <Small q={q} />
      <Card title="Par niveau de fiabilité" sub="Une fiabilité « forte » doit se tromper moins qu’une fiabilité « faible ». Sinon, les poids des signes sont à revoir.">
        <RateTable rows={['high', 'medium', 'low'].map(k => ['Fiabilité ' + L.fiab[k].toLowerCase(), q.par_fiabilite[k] || zero])} />
        {calib && <Note tone="bad" style={{ marginTop: 12 }}>La fiabilité « forte » se trompe plus que la « faible » : les poids des signes dans triage.dart sont à revoir avec le vétérinaire.</Note>}
        {!calib && (hi?.retours >= 10 && lo?.retours >= 10) && <Note tone="ok" style={{ marginTop: 12 }}>La fiabilité annoncée est cohérente avec les résultats.</Note>}
      </Card>
      <Kpis><Kpi label="Confiance moyenne du modèle" value={s.analyses.confiance_moyenne != null ? pct(Number(s.analyses.confiance_moyenne), 1) : '—'} detail="Probabilité moyenne donnée par le modèle" /></Kpis>
    </>;
  }}</WithStats>;
}

function Confusions() {
  return <WithStats>{s => {
    const q = s.qualite, conf = q.confusions;
    const cells = {}; conf.forEach(c => { cells[c.predit + '>' + c.reel] = c.n; });
    const reals = [...new Set([...MALADIES, ...conf.map(c => c.reel)])];
    const max = Math.max(1, ...conf.map(c => c.n));
    return <>
      <Small q={q} />
      <Card title="Matrice des confusions" sub="Lignes : ce que SIFA a annoncé. Colonnes : ce que c’était vraiment selon l’éleveur. Seuls les cas jugés faux sont comptés.">
        {conf.length ? <div className="tablewrap"><table><thead><tr><th>SIFA a dit ↓ / réalité →</th>{reals.map(r => <th key={r} className="num">{lab(L.maladie, r)}</th>)}</tr></thead>
          <tbody>{MALADIES.map(p => <tr key={p}><td><b>{L.maladie[p]}</b></td>{reals.map(r => { const n = cells[p + '>' + r] || 0; return <td key={r} className="num" style={{ background: n ? `color-mix(in srgb, var(--bad) ${Math.round(8 + 50 * n / max)}%, transparent)` : undefined }}>{n || ''}</td>; })}</tr>)}</tbody></table></div>
          : <p className="muted">Aucune confusion signalée.</p>}
      </Card>
      <Card title="Classement des confusions"><SimpleList pairs={[...conf].sort((a, b) => b.n - a.n).map(c => [`${lab(L.maladie, c.predit)} → en réalité ${lab(L.maladie, c.reel)}`, c.n])} empty="Aucune confusion signalée." /></Card>
    </>;
  }}</WithStats>;
}

function Signs() {
  return <WithStats>{s => {
    const q = s.qualite, a = s.analyses;
    const better = q.avec_questions?.retours >= 10 && q.photo_seule?.retours >= 10 ? (q.avec_questions.justes / q.avec_questions.retours) - (q.photo_seule.justes / q.photo_seule.retours) : null;
    return <>
      <Small q={q} />
      <Grid>
        <Card title="Les questions sur les signes aident-elles ?" sub="Compare les analyses avec réponses aux questions et celles avec la photo seule."><RateTable rows={[['Avec réponses aux questions', q.avec_questions], ['Photo seule', q.photo_seule]]} />
          {better != null && <Note tone={better > 0 ? 'ok' : 'warn'} style={{ marginTop: 12 }}>{better > 0 ? `Les questions améliorent le taux de bonnes réponses de ${(100 * better).toFixed(0)} points.` : 'Les questions n’améliorent pas (encore) le taux de bonnes réponses : à surveiller.'}</Note>}</Card>
        <Card title="Usage des questions"><Kpis><Kpi label="Photo seule" value={pct(a.photo_seule, a.total)} detail={`${nf(a.photo_seule)} analyses`} /><Kpi label="Alertes graves" value={nf(a.alertes)} detail="Signes nerveux ou mortalité brutale" /></Kpis></Card>
      </Grid>
    </>;
  }}</WithStats>;
}

function Cases() {
  const { days } = useStats();
  const st = useAsync(async () => {
    const { rows, truncated } = await fetchEvents(days, ['retour', 'analyse']);
    const an = new Map(); rows.filter(r => r.nom === 'analyse').forEach(r => an.set(r.appareil + ':' + r.props?.ref, r));
    const faux = rows.filter(r => r.nom === 'retour' && r.props?.juste === false).slice(0, 100).map(r => ({ ...r, analyse: an.get(r.appareil + ':' + r.props?.ref) }));
    const refs = faux.map(f => f.props?.ref).filter(Boolean);
    const photos = refs.length ? await must(sb.from('echantillons').select('appareil,ref,id').in('ref', refs)) : [];
    return { faux, truncated, photoKeys: new Set(photos.map(p => p.appareil + ':' + p.ref)) };
  }, [days]);
  return <Card title="Résultats jugés faux par les éleveurs" sub="À examiner avec le vétérinaire. Quand l’éleveur a partagé la photo, elle est disponible dans Photos et entraînement.">
    <Async state={st}>{({ faux, truncated, photoKeys }) => <>
      {truncated && <Note tone="warn" style={{ marginBottom: 12 }}>Seuls les événements les plus récents sont affichés.</Note>}
      {faux.length ? <div className="tablewrap"><table><thead><tr><th>Date</th><th>SIFA a dit</th><th>Réalité (éleveur)</th><th>Fiabilité</th><th className="num">Confiance</th><th>Photo</th></tr></thead>
        <tbody>{faux.map((f, i) => <tr key={i}><td>{fdate(f.cree_le)}</td><td>{lab(L.maladie, f.analyse?.props?.maladie)}</td><td>{lab(L.maladie, f.props?.reelle)}</td>
          <td>{L.fiab[f.analyse?.props?.fiabilite] || '—'}</td><td className="num">{f.analyse?.props?.confiance != null ? pct(Number(f.analyse.props.confiance), 1) : '—'}</td>
          <td>{photoKeys.has(f.appareil + ':' + f.props?.ref) ? <Link to="/entrainement/etiquetage"><Pill tone="ok">Partagée</Pill></Link> : <span className="muted">Non</span>}</td></tr>)}</tbody></table></div>
        : <p className="muted">Aucun résultat jugé faux sur la période.</p>}</>}</Async>
  </Card>;
}

export default function Quality() {
  return <><SubTabs items={TABS} /><Routes>
    <Route index element={<Global />} /><Route path="maladies" element={<ByDisease />} /><Route path="fiabilite" element={<Reliability />} />
    <Route path="confusions" element={<Confusions />} /><Route path="signes" element={<Signs />} /><Route path="avis" element={<Cases />} />
  </Routes></>;
}
