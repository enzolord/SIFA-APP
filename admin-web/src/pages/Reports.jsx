import { useState } from 'react';
import { WithStats } from '../stats.jsx';
import { Card, useToast } from '../ui.jsx';
import { L, downloadCsv, fdate, lab, must, nf, pct, ratio, sb } from '../lib.js';

const SAMPLE_MIN = 30;
function model(s) {
  const u = s.utilisateurs, q = s.qualite, a = s.analyses, sc = s.scans, f = s.fonctionnalites, r = s.retention;
  const topD = Object.entries(a.par_maladie).sort((x, y) => y[1] - x[1])[0];
  const topS = f.ecrans.filter(x => !['Accueil', 'Historique', 'Scanner', 'Communaute', 'Profil'].includes(x.nom))[0];
  const rejected = Object.entries(sc.par_issue).filter(([k]) => k !== 'ok').reduce((x, [, v]) => x + v, 0);
  const okRate = ratio(q.justes, q.retours);
  const facts = [
    `${nf(u.actifs_periode)} éleveurs actifs sur ${s.periode_jours} jours, dont ${nf(u.nouveaux_periode)} nouveaux. ${nf(u.actifs_7j)} actifs sur les 7 derniers jours.`,
    `${nf(a.total)} analyses réalisées par ${nf(a.appareils)} éleveurs${topD ? `. Résultat le plus fréquent : ${lab(L.maladie, topD[0])} (${pct(topD[1], a.total)})` : ''}.`,
    q.retours ? `${pct(q.justes, q.retours)} de bonnes réponses et ${pct(q.faux, q.retours)} de mauvaises, sur ${nf(q.retours)} avis (${pct(q.retours, a.total)} des analyses).` : 'Aucun avis reçu sur la qualité des réponses.',
    `${nf(sc.total)} photos prises, dont ${pct(rejected, sc.total)} refusées.`,
    topS ? `Écran le plus utilisé (hors onglets) : ${lab(L.ecran, topS.nom)}, ${nf(topS.vues)} vues.` : 'Pas encore de données d’usage détaillées.',
    r.cohorte_7j ? `${pct(r.revenus_7j, r.cohorte_7j)} des éleveurs reviennent après 7 jours.` : 'Rétention à 7 jours : pas encore assez d’ancienneté.',
    `${nf(a.alertes)} alerte(s) grave(s) (signes nerveux ou mortalité brutale).`,
    `Communauté : ${nf(s.communaute.publications)} publications, ${nf(s.communaute.commentaires)} commentaires, ${nf(s.communaute.signalements_periode)} signalement(s).`,
  ];
  const recs = [];
  if (q.retours < SAMPLE_MIN) recs.push('Collecter davantage d’avis : moins de 30 réponses, impossible de juger la fiabilité du modèle.');
  else if (okRate < .7) recs.push('Taux de bonnes réponses sous 70 % : rassembler les cas faux, les faire valider par le vétérinaire et ré-entraîner le modèle.');
  if (sc.total && rejected / sc.total > .3) recs.push('Plus de 30 % des photos sont refusées : renforcer les conseils de cadrage dans l’écran de scan.');
  if (a.total && a.photo_seule / a.total > .5) recs.push('Plus de la moitié des analyses se font sans répondre aux questions : rendre les questions plus visibles.');
  if (r.cohorte_7j >= 20 && r.revenus_7j / r.cohorte_7j < .2) recs.push('Moins de 20 % des éleveurs reviennent après 7 jours : prévoir des rappels (calendrier de vaccination) et du contenu régulier.');
  if (s.pharmacies.perimees > 0) recs.push(`Mettre à jour le stock de ${s.pharmacies.perimees} pharmacie(s).`);
  if (s.communaute.signalements_periode > 0) recs.push('Traiter les publications signalées dans la page Communauté.');
  if (!recs.length) recs.push('Aucune action urgente. Continuer à collecter des avis pour suivre la fiabilité.');
  return { facts, recs };
}

function Exp({ label, fn }) {
  const [busy, setBusy] = useState(false);
  const toast = useToast();
  return <button className="btn sec small" type="button" disabled={busy} onClick={async () => { setBusy(true); try { await fn(); } catch (e) { toast('Export : ' + e.message, true); } setBusy(false); }}>{label}</button>;
}

export default function Reports() {
  const toast = useToast();
  return <WithStats>{s => {
    const m = model(s);
    const text = `Rapport SIFA – ${s.periode_jours} derniers jours\n\n` + m.facts.map(x => '• ' + x).join('\n') + '\n\nActions conseillées\n' + m.recs.map(x => '• ' + x).join('\n');
    const since = new Date(Date.now() - s.periode_jours * 864e5).toISOString();
    const out = (name, rows) => rows.length ? downloadCsv(name, rows) : toast('Rien à exporter.', true);
    return <Card className="report">
      <div className="actions noprint" style={{ marginTop: 0 }}>
        <button className="btn" type="button" onClick={() => window.print()}>Imprimer / PDF</button>
        <button className="btn sec" type="button" onClick={async () => { try { await navigator.clipboard.writeText(text); toast('Rapport copié, prêt à coller dans WhatsApp ou un e-mail.'); } catch { toast('Copie impossible.', true); } }}>Copier le texte</button>
      </div>
      <h1 style={{ marginTop: 16 }}>Rapport SIFA</h1>
      <p className="muted">Période : {s.periode_jours} derniers jours · généré le {fdate(s.genere_le)}</p>
      <h2>Chiffres clés</h2><ul>{m.facts.map((x, i) => <li key={i}>{x}</li>)}</ul>
      <h2>Actions conseillées</h2><ul>{m.recs.map((x, i) => <li key={i}>{x}</li>)}</ul>
      <div className="noprint">
        <h2>Exports (CSV, ouvrable dans Excel)</h2>
        <div className="actions" style={{ marginTop: 8 }}>
          <Exp label="Activité par jour" fn={async () => out('sifa_activite_par_jour.csv', s.serie)} />
          <Exp label="Événements bruts (10 000 max)" fn={async () => out('sifa_evenements.csv', await must(sb.from('evenements').select('cree_le,appareil,nom,props,langue,version_app').gte('cree_le', since).order('cree_le', { ascending: false }).limit(10000)))} />
          <Exp label="Utilisateurs" fn={async () => out('sifa_utilisateurs.csv', await must(sb.from('profiles').select('nom,email,telephone,ville,ferme,type_elevage,role,langue,created_at').limit(5000)))} />
          <Exp label="Pharmacies" fn={async () => out('sifa_pharmacies.csv', await must(sb.from('pharmacies').select('*')))} />
          <Exp label="Photos partagées (liste)" fn={async () => out('sifa_photos.csv', await must(sb.from('echantillons').select('cree_le,appareil,ref,maladie_app,confiance,fiabilite,statut,classe_validee,notes').order('cree_le', { ascending: false }).limit(5000)))} />
        </div>
        <p className="muted">Les événements bruts ne contiennent ni photo, ni nom : seulement un identifiant aléatoire par téléphone.</p>
      </div>
    </Card>;
  }}</WithStats>;
}
