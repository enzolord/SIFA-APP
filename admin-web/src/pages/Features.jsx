import { WithStats } from '../stats.jsx';
import { BarTable, Card, ChartBox, Grid, Kpi, Kpis, SimpleList, col } from '../ui.jsx';
import { L, lab, nf, pct } from '../lib.js';

export default function Features() {
  return <WithStats>{s => {
    const f = s.fonctionnalites, e = s.entonnoir;
    const qt = s.quota || { bloques_periode: 0, bloques_total: 0, blocages: 0, ferme_verrouillee: 0 }, fm = s.ferme || { utilisateurs: 0, modules: [], actions: {} };
    const screens = f.ecrans.map(x => ({ label: lab(L.ecran, x.nom), value: x.vues, cells: [nf(x.vues), nf(x.appareils)] }));
    const actions = f.actions.map(x => ({ label: lab(L.action, x.nom), value: x.n, cells: [nf(x.n), nf(x.appareils)] }));
    const tiles = f.actions.filter(x => x.nom.startsWith('tuile:')).map(x => [lab(L.action, x.nom), x.n]);
    const funnel = [['Ouvert l’application', e.ouverture], ['Pris une photo', e.scan], ['Obtenu une analyse', e.analyse], ['Donné son avis', e.retour]];
    const top = screens[0];
    return <>
      <Kpis>
        <Kpi label="Écran le plus vu" value={top ? top.label : '—'} detail={top ? `${top.cells[0]} vues` : 'Pas encore de données'} />
        <Kpi label="Ont pris une photo" value={pct(e.scan, e.ouverture)} detail={`${nf(e.scan)} sur ${nf(e.ouverture)} éleveurs`} />
        <Kpi label="Ont une analyse" value={pct(e.analyse, e.ouverture)} detail={`${nf(e.analyse)} éleveurs`} />
        <Kpi label="Donnent leur avis" value={pct(e.retour, e.analyse)} detail="Parmi ceux qui ont une analyse" />
      </Kpis>
      <Grid>
        <Card title="Écrans les plus utilisés" sub="Nombre de vues et d’éleveurs différents."><BarTable rows={screens} cols={['Écran', 'Vues', 'Éleveurs']} /></Card>
        <Card title="Actions les plus faites" sub="Appels, itinéraires, connexions, partages de photos."><BarTable rows={actions.filter(a => !a.label.startsWith('Accueil ›'))} cols={['Action', 'Fois', 'Éleveurs']} /></Card>
      </Grid>
      <Grid>
        <Card title="Parcours des utilisateurs" sub="Combien d’éleveurs arrivent à chaque étape.">
          <ChartBox config={() => ({ type: 'bar', data: { labels: funnel.map(x => x[0]), datasets: [{ data: funnel.map(x => x[1]), backgroundColor: col('--c1'), borderRadius: 6 }] }, options: { indexAxis: 'y', plugins: { legend: { display: false } }, scales: { x: { beginAtZero: true } } } })} />
        </Card>
        <Card title="Tuiles de l’accueil" sub="Ce que les éleveurs touchent depuis la page d’accueil."><SimpleList pairs={tiles} /></Card>
      </Grid>
      <Grid>
        <Card title="Gestion de ferme" sub={`${nf(fm.utilisateurs)} éleveurs ont ouvert au moins un module.`}>
          <BarTable rows={fm.modules.map(x => ({ label: lab(L.ecran, x.nom), value: x.vues, cells: [nf(x.vues), nf(x.appareils)] }))} cols={['Module', 'Vues', 'Éleveurs']} />
        </Card>
        <Card title="Quotas et accès" sub="Ce qui pousse vers un abonnement.">
          <SimpleList pairs={[
            ['Appareils bloqués (période)', qt.bloques_periode],
            ['Appareils bloqués (au total)', qt.bloques_total],
            ['Écrans de blocage affichés', qt.blocages],
            ['Ont touché la gestion de ferme verrouillée', qt.ferme_verrouillee],
            ...Object.entries(fm.actions).filter(([k]) => k !== 'ferme:verrouille').map(([k, v]) => [lab(L.action, k), v]),
          ]} />
        </Card>
      </Grid>
      <Card title="Heure des analyses" sub="Heure locale de Douala.">
        <ChartBox config={() => ({ type: 'bar', data: { labels: s.analyses.par_heure.map((_, i) => i + ' h'), datasets: [{ label: 'Analyses', data: s.analyses.par_heure, backgroundColor: col('--c2'), borderRadius: 3 }] }, options: { plugins: { legend: { display: false } }, scales: { y: { beginAtZero: true }, x: { ticks: { maxTicksLimit: 12 } } } } })} />
      </Card>
    </>;
  }}</WithStats>;
}
