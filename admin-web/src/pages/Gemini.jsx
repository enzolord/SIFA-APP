import { useState } from 'react';
import { Route, Routes } from 'react-router-dom';
import { useStats, WithStats } from '../stats.jsx';
import { Async, Card, ChartBox, Grid, Kpi, Kpis, Note, SimpleList, SubTabs, col, useAsync } from '../ui.jsx';
import { KEY, L, URL_, fetchEvents, lab, nf, pct } from '../lib.js';

const TABS = [['/gemini', 'Photos reçues', true], ['/gemini/verdicts', 'Réponses de Gemini'], ['/gemini/accord', 'Accord Gemini / modèle'], ['/gemini/disponibilite', 'Disponibilité et test']];

function Photos() {
  return <WithStats>{s => {
    const sc = s.scans, ok = sc.par_issue.ok || 0, rej = sc.total - ok;
    return <>
      <Kpis>
        <Kpi label="Photos prises" value={nf(sc.total)} />
        <Kpi label="Acceptées" value={pct(ok, sc.total)} detail={`${nf(ok)} photos`} tone="good" />
        <Kpi label="Refusées" value={pct(rej, sc.total)} detail={`${nf(rej)} photos`} tone={sc.total && rej / sc.total > .3 ? 'bad' : ''} />
      </Kpis>
      <Grid>
        <Card title="Résultat du contrôle de la photo" sub="Raison du refus : trop sombre, surface unie, pas une fiente…">
          <ChartBox empty={!sc.total && 'Aucun scan sur la période.'} config={() => ({ type: 'bar', data: { labels: Object.keys(sc.par_issue).map(k => lab(L.issue, k)), datasets: [{ data: Object.values(sc.par_issue), backgroundColor: Object.keys(sc.par_issue).map(k => k === 'ok' ? col('--c1') : col('--c4')), borderRadius: 6 }] }, options: { indexAxis: 'y', plugins: { legend: { display: false } }, scales: { x: { beginAtZero: true } } } })} />
        </Card>
        <Card title="Détail"><SimpleList pairs={Object.entries(sc.par_issue).map(([k, v]) => [lab(L.issue, k), v])} empty="Aucun scan." />
          {sc.total && rej / sc.total > .3 ? <Note tone="warn" style={{ marginTop: 12 }}>Plus de 30 % des photos sont refusées : renforcez les conseils de cadrage dans l’écran de scan.</Note> : null}</Card>
      </Grid>
    </>;
  }}</WithStats>;
}

function Verdicts() {
  return <WithStats>{s => {
    const g = s.scans.gemini || {}, total = Object.values(g).reduce((x, y) => x + y, 0);
    const answered = (g.dropping || 0) + (g.notDropping || 0);
    return <>
      <Kpis>
        <Kpi label="Photos soumises" value={nf(total)} />
        <Kpi label="Gemini a répondu" value={pct(answered, total)} detail={`${nf(answered)} réponses`} />
        <Kpi label="Gemini : fiente" value={pct(g.dropping || 0, answered)} />
        <Kpi label="Gemini : autre chose" value={pct(g.notDropping || 0, answered)} detail="Photos refusées grâce à Gemini" />
      </Kpis>
      <Grid>
        <Card title="Répartition des réponses">
          <ChartBox empty={!total && 'Aucun scan.'} config={() => ({ type: 'doughnut', data: { labels: Object.keys(g).map(k => lab(L.gemini, k)), datasets: [{ data: Object.values(g), backgroundColor: [col('--c1'), col('--c4'), col('--c2'), col('--c3'), col('--c5')], borderColor: col('--surface'), borderWidth: 2 }] }, options: { cutout: '60%', plugins: { legend: { position: 'bottom' } } } })} />
        </Card>
        <Card title="Détail"><SimpleList pairs={Object.entries(g).map(([k, v]) => [lab(L.gemini, k), v])} empty="Aucun scan." /></Card>
      </Grid>
    </>;
  }}</WithStats>;
}

function Agreement() {
  const { days } = useStats();
  const st = useAsync(() => fetchEvents(days, ['scan']), [days]);
  return <Card title="Gemini et le contrôle de la photo" sub="Croise le contrôle intégré à l’application avec la réponse de Gemini, pour chaque photo.">
    <Async state={st}>{({ rows, truncated }) => {
      const issues = ['ok', 'notDropping', 'tooDark', 'tooPlain', 'unclear'], gems = ['dropping', 'notDropping', 'unknown', 'absent'];
      const m = {}; rows.forEach(r => { const i = r.props?.issue ?? 'inconnu', g = r.props?.gemini ?? 'absent'; m[i + '>' + g] = (m[i + '>' + g] || 0) + 1; });
      const both = rows.filter(r => ['dropping', 'notDropping'].includes(r.props?.gemini));
      const agree = both.filter(r => (r.props?.issue === 'ok') === (r.props?.gemini === 'dropping')).length;
      return <>
        {truncated && <Note tone="warn" style={{ marginBottom: 12 }}>Les 10 000 événements les plus récents seulement.</Note>}
        <Kpis><Kpi label="Photos comparées" value={nf(both.length)} detail="Gemini a répondu" /><Kpi label="Accord" value={pct(agree, both.length)} detail="Même décision : photo acceptable ou non" /></Kpis>
        {rows.length ? <div className="tablewrap"><table><thead><tr><th>Contrôle intégré ↓ / Gemini →</th>{gems.map(g => <th key={g} className="num">{lab(L.gemini, g)}</th>)}</tr></thead>
          <tbody>{issues.map(i => <tr key={i}><td><b>{lab(L.issue, i)}</b></td>{gems.map(g => <td key={g} className="num">{m[i + '>' + g] || ''}</td>)}</tr>)}</tbody></table></div> : <p className="muted">Aucun scan sur la période.</p>}
        <p className="muted" style={{ marginTop: 10 }}>Un désaccord fréquent « modèle accepte / Gemini refuse » montre que le contrôle intégré laisse passer des photos qui ne sont pas des fientes.</p>
      </>;
    }}</Async>
  </Card>;
}

function Availability() {
  const { days } = useStats();
  const st = useAsync(() => fetchEvents(days, ['scan']), [days]);
  const [res, setRes] = useState(null);
  async function test() {
    setRes({ tone: '', text: 'Test en cours…' });
    try {
      const c = document.createElement('canvas'); c.width = c.height = 64; const x = c.getContext('2d'); x.fillStyle = '#888'; x.fillRect(0, 0, 64, 64);
      const img = c.toDataURL('image/jpeg', .9).split(',')[1].padEnd(200, 'A');
      const r = await fetch(`${URL_}/functions/v1/verifier-fiente`, { method: 'POST', headers: { 'Content-Type': 'application/json', apikey: KEY }, body: JSON.stringify({ image: img }) });
      const j = await r.json().catch(() => ({}));
      setRes(r.ok ? { tone: 'ok', text: '✔ Gemini répond : la fonction et la clé sont en place.' }
        : r.status === 404 ? { tone: 'bad', text: '✖ La fonction verifier-fiente n’est pas déployée.' }
        : r.status === 503 ? { tone: 'bad', text: '✖ GEMINI_API_KEY est absente des secrets Supabase.' }
        : r.status === 401 ? { tone: 'bad', text: '✖ SIFA_APP_KEY ne correspond pas à la clé publishable.' }
        : r.status === 429 ? { tone: 'warn', text: 'Quota gratuit Gemini atteint : l’app utilise le modèle embarqué seul.' }
        : { tone: 'bad', text: `✖ Erreur ${r.status} : ${j.erreur || 'voir les logs de la fonction'}` });
    } catch (e) { setRes({ tone: 'bad', text: '✖ ' + e.message }); }
  }
  return <>
    <Card title="Disponibilité de Gemini" sub="Part des photos pour lesquelles Gemini a répondu, jour par jour.">
      <Async state={st}>{({ rows }) => {
        const byDay = {}; rows.forEach(r => { const d = r.cree_le.slice(0, 10), o = byDay[d] ||= { ok: 0, n: 0 }; o.n++; if (['dropping', 'notDropping'].includes(r.props?.gemini)) o.ok++; });
        const ds = Object.keys(byDay).sort();
        return <ChartBox empty={!ds.length && 'Aucun scan sur la période.'} config={() => ({ type: 'line', data: { labels: ds.map(d => d.slice(5).split('-').reverse().join('/')), datasets: [{ label: 'Réponses de Gemini (%)', data: ds.map(d => Math.round(100 * byDay[d].ok / byDay[d].n)), borderColor: col('--c1'), backgroundColor: col('--c1'), tension: .3 }] }, options: { scales: { y: { min: 0, max: 100 }, x: { ticks: { maxTicksLimit: 8 } } }, plugins: { legend: { display: false } } } })} />;
      }}</Async>
      <p className="muted" style={{ marginTop: 10 }}>Le délai de réponse n’est pas encore mesuré : il sera ajouté dans une prochaine version de l’application.</p>
    </Card>
    <Card title="Tester la connexion à Gemini" sub="Vérifie que la fonction verifier-fiente est déployée et que la clé est enregistrée dans les secrets Supabase.">
      <button className="btn sec" type="button" onClick={test}>Tester Gemini</button>
      {res && <div className={'note ' + res.tone} style={{ marginTop: 10 }}>{res.text}</div>}
    </Card>
  </>;
}

export default function Gemini() {
  return <><SubTabs items={TABS} /><Routes>
    <Route index element={<Photos />} /><Route path="verdicts" element={<Verdicts />} /><Route path="accord" element={<Agreement />} /><Route path="disponibilite" element={<Availability />} />
  </Routes></>;
}
