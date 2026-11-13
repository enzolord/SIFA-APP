import { Link } from 'react-router-dom';
import { WithStats } from '../stats.jsx';
import { Card, ChartBox, Grid, Kpi, Kpis, Note, Pill, col, useAsync } from '../ui.jsx';
import { L, MALADIES, getC, nf, pct, ratio, sb } from '../lib.js';

function useTodos(s) {
  return useAsync(async () => {
    const [annonce, maint] = await Promise.all([getC('annonce').catch(() => ({})), getC('maintenance').catch(() => ({}))]);
    const items = [];
    const add = (level, title, text, to) => items.push({ level, title, text, to });
    if (maint.actif) add('bad', 'Maintenance activée', 'Les éleveurs voient un écran de maintenance à la place de l’application.', '/contenu');
    if (annonce.actif) add('ok', 'Une annonce est affichée', 'Elle apparaît en haut de l’accueil de l’application.', '/contenu');
    const q = s.qualite, okRate = ratio(q.justes, q.retours);
    if (q.retours < 30) add('warn', 'Peu d’avis reçus', `${q.retours} avis pour ${s.analyses.total} analyses : trop peu pour juger la fiabilité. Il faut au moins 30 avis.`, '/qualite');
    else if (okRate < .7) add('bad', 'Taux de bonnes réponses bas', `${pct(q.justes, q.retours)} de bonnes réponses. Voir les maladies confondues et ré-entraîner le modèle.`, '/qualite/confusions');
    else add('ok', 'Taux de bonnes réponses correct', `${pct(q.justes, q.retours)} sur ${q.retours} avis.`, '/qualite');
    if (s.communaute.signalements_periode > 0) add('warn', 'Publications signalées', `${s.communaute.signalements_periode} signalement(s) sur la période.`, '/communaute');
    if (s.pharmacies.perimees > 0) add('warn', 'Stocks de pharmacies anciens', `${s.pharmacies.perimees} pharmacie(s) dont le stock n’a pas été mis à jour depuis 30 jours.`, '/contenu/pharmacies');
    if (s.pharmacies.actives === 0) add('warn', 'Aucune pharmacie enregistrée', 'L’application affiche encore l’exemple intégré (non réel) tant que la liste est vide.', '/contenu/pharmacies');
    const gem = s.scans.gemini || {}, totalG = Object.values(gem).reduce((x, y) => x + y, 0);
    if (totalG >= 20 && (gem.unknown || 0) + (gem.absent || 0) > .5 * totalG) add('warn', 'Gemini répond rarement', 'Plus de la moitié des photos n’ont pas été vérifiées en ligne : vérifiez la clé et le quota.', '/gemini/disponibilite');
    const { count } = await sb.from('echantillons').select('id', { count: 'exact', head: true }).eq('statut', 'a_valider');
    if (count > 0) add('warn', 'Photos à étiqueter', `${count} photo(s) partagée(s) attendent la validation d’un vétérinaire.`, '/entrainement/etiquetage');
    if (!items.length) add('ok', 'Rien à signaler', 'Tout est en ordre.');
    return items;
  }, [s.genere_le]);
}

function Todos({ s }) {
  const st = useTodos(s);
  if (st.error) return <Note tone="bad">{st.error.message}</Note>;
  if (!st.data) return <p className="muted">Chargement…</p>;
  return st.data.map((i, k) => (
    <div className="todo" key={k}>
      <Pill tone={i.level}>{i.level === 'ok' ? 'OK' : i.level === 'warn' ? 'À voir' : 'Urgent'}</Pill>
      <div><b>{i.title}</b><div className="muted">{i.text}</div>{i.to && <Link className="btn small sec" style={{ marginTop: 6, display: 'inline-block', textDecoration: 'none' }} to={i.to}>Ouvrir</Link>}</div>
    </div>));
}

export default function Overview() {
  return <WithStats>{s => {
    const u = s.utilisateurs, q = s.qualite, a = s.analyses, qt = s.quota || { bloques_periode: 0, bloques_total: 0 };
    const okRate = ratio(q.justes, q.retours), stick = ratio(u.actifs_24h, u.actifs_30j);
    const labels = s.serie.map(r => r.jour.slice(5).split('-').reverse().join('/'));
    const keys = MALADIES.filter(k => a.par_maladie[k]);
    return <>
      <Kpis>
        <Kpi label="Utilisateurs actifs" value={nf(u.actifs_periode)} detail={`${nf(u.actifs_24h)} aujourd’hui · ${nf(u.actifs_7j)} sur 7 j`} />
        <Kpi label="Nouveaux utilisateurs" value={nf(u.nouveaux_periode)} detail={`${nf(u.appareils_total)} téléphones au total`} />
        <Kpi label="Comptes connectés" value={nf(u.comptes)} detail={`+${nf(u.comptes_periode)} sur la période`} />
        <Kpi label="Analyses réalisées" value={nf(a.total)} detail={`${nf(a.appareils)} éleveurs ont analysé`} />
        <Kpi label="Bonnes réponses" value={okRate == null ? '—' : pct(q.justes, q.retours)} detail={`${nf(q.retours)} avis reçus`} tone={okRate == null ? '' : okRate >= .8 ? 'good' : okRate < .6 ? 'bad' : ''} />
        <Kpi label="Mauvaises réponses" value={okRate == null ? '—' : pct(q.faux, q.retours)} detail={`${nf(q.faux)} résultats jugés faux`} tone={okRate != null && okRate < .6 ? 'bad' : ''} />
        <Kpi label="Alertes graves" value={nf(a.alertes)} detail="Signes nerveux ou mortalité brutale" />
        <Kpi label="Bloqués par le quota" value={nf(qt.bloques_periode)} detail={`${nf(qt.bloques_total)} au total · ont atteint leur limite d’analyses`} tone={qt.bloques_periode > 0 ? 'warn' : ''} />
        <Kpi label="Fidélité" value={stick == null ? '—' : pct(u.actifs_24h, u.actifs_30j)} detail="Actifs du jour / actifs du mois" />
      </Kpis>
      <Grid>
        <Card title="Activité par jour" sub="Utilisateurs actifs, nouveaux et analyses.">
          <ChartBox config={() => ({ data: { labels, datasets: [
            { type: 'bar', label: 'Analyses', data: s.serie.map(r => r.analyses), backgroundColor: col('--c2'), order: 3 },
            { type: 'line', label: 'Actifs', data: s.serie.map(r => r.actifs), borderColor: col('--c1'), backgroundColor: col('--c1'), tension: .3, pointRadius: 0, borderWidth: 2.5, order: 1 },
            { type: 'line', label: 'Nouveaux', data: s.serie.map(r => r.nouveaux), borderColor: col('--c3'), backgroundColor: col('--c3'), tension: .3, pointRadius: 0, borderWidth: 2, order: 2 },
          ] }, options: { scales: { y: { beginAtZero: true }, x: { ticks: { maxTicksLimit: 8 } } }, plugins: { legend: { position: 'bottom' } } } })} />
        </Card>
        <Card title="Ce que SIFA a trouvé" sub="Répartition des résultats d’analyse.">
          <ChartBox empty={!keys.length && 'Aucune analyse sur la période.'} config={() => ({ type: 'doughnut', data: { labels: keys.map(k => L.maladie[k]), datasets: [{ data: keys.map(k => a.par_maladie[k]), backgroundColor: [col('--c1'), col('--c2'), col('--c4'), col('--c5')], borderColor: col('--surface'), borderWidth: 2 }] }, options: { cutout: '62%', plugins: { legend: { position: 'bottom' } } } })} />
        </Card>
      </Grid>
      <Card title="À surveiller" sub="Ce qui demande une action de votre part."><Todos s={s} /></Card>
    </>;
  }}</WithStats>;
}
