import { useMemo, useState } from 'react';
import { Route, Routes } from 'react-router-dom';
import { useStats, WithStats } from '../stats.jsx';
import { Async, Card, ChartBox, Grid, Kpi, Kpis, Note, Pill, SimpleList, SubTabs, col, useAsync, useToast } from '../ui.jsx';
import { fday, fdate, fetchEvents, must, nf, pct, ratio, sb } from '../lib.js';
import { useSession } from '../session.jsx';

const TABS = [['/utilisateurs', 'Vue générale', true], ['/utilisateurs/fidelite', 'Fidélité'], ['/utilisateurs/profils', 'Profils d’usage'], ['/utilisateurs/abonnes', 'Abonnés'], ['/utilisateurs/liste', 'Liste et fiches']];
const TYPE = { chair: 'Poulets de chair', pondeuse: 'Poules pondeuses', mixte: 'Mixte' };

function General() {
  return <WithStats>{s => {
    const u = s.utilisateurs;
    const labels = s.serie.map(r => r.jour.slice(5).split('-').reverse().join('/'));
    return <>
      <Kpis>
        <Kpi label="Téléphones (total)" value={nf(u.appareils_total)} detail="Chaque téléphone = un éleveur anonyme" />
        <Kpi label="Actifs sur la période" value={nf(u.actifs_periode)} />
        <Kpi label="Actifs aujourd’hui" value={nf(u.actifs_24h)} />
        <Kpi label="Actifs 7 jours" value={nf(u.actifs_7j)} />
        <Kpi label="Actifs 30 jours" value={nf(u.actifs_30j)} />
        <Kpi label="Nouveaux (période)" value={nf(u.nouveaux_periode)} />
        <Kpi label="Comptes Google" value={nf(u.comptes)} detail={`+${nf(u.comptes_periode)} sur la période`} />
        <Kpi label="Part avec un compte" value={pct(u.comptes, u.appareils_total)} />
      </Kpis>
      <Card title="Arrivées et activité" sub="Nouveaux téléphones et téléphones actifs, jour par jour.">
        <ChartBox config={() => ({ type: 'line', data: { labels, datasets: [
          { label: 'Actifs', data: s.serie.map(r => r.actifs), borderColor: col('--c1'), backgroundColor: col('--c1'), tension: .3, pointRadius: 0, borderWidth: 2.5 },
          { label: 'Nouveaux', data: s.serie.map(r => r.nouveaux), borderColor: col('--c3'), backgroundColor: col('--c3'), tension: .3, pointRadius: 0, borderWidth: 2 }] },
          options: { scales: { y: { beginAtZero: true }, x: { ticks: { maxTicksLimit: 8 } } }, plugins: { legend: { position: 'bottom' } } } })} />
      </Card>
      <Grid n={3}>
        <Card title="Langues"><SimpleList pairs={Object.entries(u.par_langue).map(([k, v]) => [k === 'fr' ? 'Français' : k === 'en' ? 'Anglais' : k, v])} /></Card>
        <Card title="Versions de l’application"><SimpleList pairs={Object.entries(u.par_version)} /></Card>
        <Card title="Type d’élevage (comptes)"><SimpleList pairs={Object.entries(u.par_type_elevage).map(([k, v]) => [TYPE[k] || k, v])} /></Card>
      </Grid>
      <Card title="Villes des comptes"><SimpleList pairs={u.par_ville.map(x => [x.ville, x.n])} empty="Aucune ville renseignée." /></Card>
    </>;
  }}</WithStats>;
}

function Loyalty() {
  const { days } = useStats();
  const ev = useAsync(() => fetchEvents(Math.max(days, 90), ['ouverture', 'analyse']), [days]);
  return <WithStats>{(s) => {
    const u = s.utilisateurs, r = s.retention;
    return <>
      <Kpis>
        <Kpi label="Reviennent après 1 jour" value={pct(r.revenus_1j, r.cohorte_1j)} detail={`${nf(r.revenus_1j)} sur ${nf(r.cohorte_1j)}`} />
        <Kpi label="Reviennent après 7 jours" value={pct(r.revenus_7j, r.cohorte_7j)} detail={`${nf(r.revenus_7j)} sur ${nf(r.cohorte_7j)}`} />
        <Kpi label="Fidélité du jour" value={pct(u.actifs_24h, u.actifs_30j)} detail="Actifs du jour / actifs du mois" />
        <Kpi label="Ouvertures par actif" value={String(u.moyenne_ouvertures_par_actif ?? '—').replace('.', ',')} detail="Sur la période" />
      </Kpis>
      <Card title="Cohortes par semaine d’arrivée" sub="Pour chaque semaine d’arrivée : part des téléphones qui sont revenus au moins un autre jour. Calculé sur les événements récents.">
        <Async state={ev}>{({ rows, truncated }) => {
          const first = new Map(), days_ = new Map();
          for (const e of rows) { const d = e.cree_le.slice(0, 10); (days_.get(e.appareil) || days_.set(e.appareil, new Set()).get(e.appareil)).add(d); }
          for (const [a, set] of days_) first.set(a, [...set].sort()[0]);
          const weeks = new Map();
          for (const [a, set] of days_) {
            const d0 = new Date(first.get(a)); const monday = new Date(d0); monday.setDate(d0.getDate() - ((d0.getDay() + 6) % 7));
            const k = monday.toISOString().slice(0, 10);
            const w = weeks.get(k) || { n: 0, back: 0 }; w.n++; if (set.size > 1) w.back++; weeks.set(k, w);
          }
          const list = [...weeks.entries()].sort();
          return <>
            {truncated && <Note tone="warn" style={{ marginBottom: 12 }}>Seuls les 10 000 événements les plus récents sont analysés : les semaines anciennes sont incomplètes.</Note>}
            {list.length ? <div className="tablewrap"><table><thead><tr><th>Semaine du</th><th className="num">Arrivés</th><th className="num">Revenus</th><th /></tr></thead>
              <tbody>{list.map(([k, w]) => <tr key={k}><td>{fday(k)}</td><td className="num">{w.n}</td><td className="num">{pct(w.back, w.n)}</td><td style={{ width: '35%' }}><div className="bar"><i style={{ width: (100 * w.back / w.n) + '%' }} /></div></td></tr>)}</tbody></table></div>
              : <p className="muted">Pas encore assez de données.</p>}</>;
        }}</Async>
      </Card>
    </>;
  }}</WithStats>;
}

function Profiles() {
  const { days } = useStats();
  const ev = useAsync(() => fetchEvents(days, ['ouverture', 'analyse', 'scan', 'retour']), [days]);
  return <Card title="Profils d’usage" sub="Chaque téléphone est classé selon ce qu’il fait. Calculé sur la période choisie (10 000 événements au plus).">
    <Async state={ev}>{({ rows, truncated }) => {
      const per = new Map();
      for (const e of rows) {
        const p = per.get(e.appareil) || { days: new Set(), analyses: 0, avis: 0 };
        p.days.add(e.cree_le.slice(0, 10));
        if (e.nom === 'analyse') p.analyses++; if (e.nom === 'retour') p.avis++;
        per.set(e.appareil, p);
      }
      const seg = { 'Visiteurs (n’ont rien analysé)': 0, 'Curieux (1 analyse ou plus, un seul jour)': 0, 'Réguliers (3 jours ou plus)': 0, 'Très actifs (7 jours ou 10 analyses)': 0 };
      let avis = 0;
      for (const p of per.values()) {
        if (p.avis) avis++;
        if (p.days.size >= 7 || p.analyses >= 10) seg['Très actifs (7 jours ou 10 analyses)']++;
        else if (p.days.size >= 3) seg['Réguliers (3 jours ou plus)']++;
        else if (p.analyses >= 1) seg['Curieux (1 analyse ou plus, un seul jour)']++;
        else seg['Visiteurs (n’ont rien analysé)']++;
      }
      const dist = Array.from({ length: 8 }, (_, i) => 0); for (const p of per.values()) dist[Math.min(7, p.days.size - 1)]++;
      return <>
        {truncated && <Note tone="warn" style={{ marginBottom: 12 }}>Les 10 000 événements les plus récents seulement : certains téléphones peuvent sembler moins actifs.</Note>}
        <Kpis><Kpi label="Téléphones étudiés" value={nf(per.size)} /><Kpi label="Ont donné un avis" value={pct(avis, per.size)} detail={`${nf(avis)} téléphones`} /></Kpis>
        <Grid>
          <Card title="Segments"><SimpleList pairs={Object.entries(seg)} empty="Pas encore de données." /></Card>
          <Card title="Jours d’activité par téléphone" sub="Combien de jours différents chacun est venu.">
            <ChartBox empty={!per.size} config={() => ({ type: 'bar', data: { labels: dist.map((_, i) => i === 7 ? '8 j et +' : (i + 1) + ' j'), datasets: [{ data: dist, backgroundColor: col('--c1'), borderRadius: 4 }] }, options: { plugins: { legend: { display: false } }, scales: { y: { beginAtZero: true } } } })} />
          </Card>
        </Grid>
      </>;
    }}</Async>
  </Card>;
}

function Subscribers() {
  const st = useAsync(async () => {
    const [subs, codes] = await Promise.all([
      must(sb.from('abonnements').select('user_id,formule,debut,fin,statut').order('fin', { ascending: true }).limit(2000)),
      must(sb.from('codes_activation').select('formule,utilise_par,cree_le,utilise_le').limit(5000)),
    ]);
    return { subs, codes };
  }, []);
  return <Async state={st}>{({ subs, codes }) => {
    const actifs = subs.filter(x => x.statut === 'actif');
    const by = {}; actifs.forEach(x => { by[x.formule] = (by[x.formule] || 0) + 1; });
    const soon = actifs.filter(x => x.fin && new Date(x.fin) - Date.now() < 7 * 864e5 && new Date(x.fin) > Date.now()).length;
    const used = codes.filter(c => c.utilise_par).length;
    return <>
      <Kpis>
        <Kpi label="Abonnés actifs" value={nf(actifs.length)} />
        {Object.entries(by).map(([k, v]) => <Kpi key={k} label={'Formule ' + k} value={nf(v)} />)}
        <Kpi label="Expirent sous 7 jours" value={nf(soon)} tone={soon ? 'bad' : ''} />
        <Kpi label="Codes créés" value={nf(codes.length)} detail={`${nf(used)} utilisés`} />
      </Kpis>
      <Card title="Abonnements actifs" sub="Classés par date de fin.">
        {actifs.length ? <div className="tablewrap"><table><thead><tr><th>Formule</th><th>Début</th><th>Fin</th></tr></thead>
          <tbody>{actifs.slice(0, 200).map((x, i) => <tr key={i}><td>{x.formule}</td><td>{fday(x.debut)}</td><td>{fday(x.fin)}</td></tr>)}</tbody></table></div> : <p className="muted">Aucun abonnement actif.</p>}
      </Card>
    </>;
  }}</Async>;
}

function List() {
  const toast = useToast();
  const { me } = useSession();
  const [q, setQ] = useState(''); const [open, setOpen] = useState(null);
  const st = useAsync(async () => {
    const [users, subs] = await Promise.all([
      must(sb.from('profiles').select('id,nom,email,telephone,ville,ferme,type_elevage,role,created_at').order('created_at', { ascending: false }).limit(1000)),
      must(sb.from('abonnements').select('user_id,formule,fin,statut').eq('statut', 'actif')),
    ]);
    return { users, sub: Object.fromEntries(subs.map(x => [x.user_id, x])) };
  }, []);
  const rows = useMemo(() => {
    const t = q.trim().toLowerCase();
    return (st.data?.users || []).filter(u => !t || [u.nom, u.email, u.telephone, u.ville, u.ferme].some(x => (x || '').toLowerCase().includes(t)));
  }, [st.data, q]);
  return <Async state={st}>{({ sub }) => {
    const detail = open && rows.find(u => u.id === open) || (open && st.data.users.find(u => u.id === open));
    return <>
      <Card title="Comptes connectés" sub="Les éleveurs connectés avec Google. Les autres utilisateurs sont comptés anonymement dans les statistiques.">
        <input type="search" placeholder="Rechercher un nom, un e-mail, une ville…" value={q} onChange={e => setQ(e.target.value)} />
        <p className="muted">{nf(rows.length)} compte(s)</p>
        <div className="tablewrap"><table><thead><tr>{['Nom', 'Contact', 'Ville / ferme', 'Élevage', 'Formule', 'Rôle', 'Inscrit'].map(x => <th key={x}>{x}</th>)}</tr></thead>
          <tbody>{rows.length ? rows.slice(0, 300).map(u => (
            <tr key={u.id} style={{ cursor: 'pointer' }} onClick={() => setOpen(u.id)}>
              <td><b>{u.nom || '—'}</b></td><td><div>{u.email}</div><div className="muted">{u.telephone}</div></td>
              <td>{[u.ville, u.ferme].filter(Boolean).join(' · ') || '—'}</td><td>{TYPE[u.type_elevage] || 'Mixte'}</td>
              <td>{sub[u.id] ? <Pill tone="ok">{sub[u.id].formule}</Pill> : <Pill>Essai</Pill>}</td>
              <td onClick={e => e.stopPropagation()}>
                <select value={u.role} onChange={async e => {
                  if (u.id === me.id) return toast('Vous ne pouvez pas changer votre propre rôle.', true);
                  try { await must(sb.from('profiles').update({ role: e.target.value }).eq('id', u.id)); u.role = e.target.value; toast('Rôle modifié.'); st.reload(); } catch (x) { toast('Modification : ' + x.message, true); }
                }}>{[['eleveur', 'Éleveur'], ['veterinaire', 'Vétérinaire'], ['admin', 'Administrateur']].map(([v, t]) => <option key={v} value={v}>{t}</option>)}</select>
              </td><td>{fdate(u.created_at)}</td></tr>)) : <tr><td colSpan={7} className="empty">Aucun compte.</td></tr>}</tbody></table></div>
      </Card>
      {detail && <Card title={detail.nom || detail.email} sub="Fiche éleveur">
        <div className="row2"><div><b>E-mail</b><div>{detail.email || '—'}</div></div><div><b>Téléphone</b><div>{detail.telephone || '—'}</div></div>
          <div><b>Ville</b><div>{detail.ville || '—'}</div></div><div><b>Ferme</b><div>{detail.ferme || '—'}</div></div>
          <div><b>Élevage</b><div>{TYPE[detail.type_elevage] || 'Mixte'}</div></div><div><b>Inscrit</b><div>{fdate(detail.created_at)}</div></div>
          <div><b>Formule</b><div>{sub[detail.id] ? `${sub[detail.id].formule} jusqu’au ${fday(sub[detail.id].fin)}` : 'Essai gratuit'}</div></div></div>
        <div className="actions"><button className="btn sec small" type="button" onClick={() => setOpen(null)}>Fermer</button></div>
      </Card>}
    </>;
  }}</Async>;
}

export default function Users() {
  return <><SubTabs items={TABS} /><Routes>
    <Route index element={<General />} /><Route path="fidelite" element={<Loyalty />} /><Route path="profils" element={<Profiles />} />
    <Route path="abonnes" element={<Subscribers />} /><Route path="liste" element={<List />} />
  </Routes></>;
}
