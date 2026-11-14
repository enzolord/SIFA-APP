import { Async, Card, Kpi, Kpis, Note, Pill, useAsync } from '../ui.jsx';
import { fdate, getC, must, sb } from '../lib.js';
import { fcfa, legacyLabel, offers } from '../pricing.js';

const STATE = { reussi: ['ok', 'Réussi'], echoue: ['bad', 'Échoué'], en_attente: ['', 'En attente'] };

export default function Paiements() {
  const st = useAsync(async () => {
    const [rows, tarifs] = await Promise.all([
      must(sb.from('paiements').select('*').order('cree_le', { ascending: false }).limit(200)),
      getC('tarifs'),
    ]);
    const ids = [...new Set(rows.map(r => r.user_id))];
    const people = ids.length ? await must(sb.from('profiles').select('id,nom,email').in('id', ids)) : [];
    return { rows, tarifs, who: Object.fromEntries(people.map(p => [p.id, p.nom || p.email || p.id.slice(0, 8)])) };
  }, []);
  return <>
    <Note style={{ marginBottom: 14 }}>Les paiements passent par <b>Campay</b> (MTN Mobile Money et Orange Money). La formule de l’éleveur s’active toute seule dès que Campay confirme le paiement : rien à valider à la main.</Note>
    <Async state={st}>{({ rows, tarifs, who }) => {
      const catalog = offers(tarifs), label = id => legacyLabel[id] || catalog.find(o => o.id === id)?.label || id;
      const ok = rows.filter(r => r.statut === 'reussi');
      const since = Date.now() - 30 * 864e5;
      const sum = a => a.reduce((s, r) => s + r.montant, 0);
      return <>
        <Kpis>
          <Kpi label="Encaissé (30 jours)" value={fcfa(sum(ok.filter(r => new Date(r.maj_le) > since)))} detail={`${ok.filter(r => new Date(r.maj_le) > since).length} paiements réussis`} tone="good" />
          <Kpi label="Encaissé (total)" value={fcfa(sum(ok))} detail={`${ok.length} paiements réussis`} />
          <Kpi label="En attente" value={rows.filter(r => r.statut === 'en_attente' && Date.now() - new Date(r.cree_le) < 36e5).length} detail="Demandes de moins d’une heure" />
          <Kpi label="Échoués" value={rows.filter(r => r.statut === 'echoue').length} detail="Refusés, annulés ou expirés" />
        </Kpis>
        <Card title="Derniers paiements" sub="200 derniers, du plus récent au plus ancien.">
          {rows.length ? <div className="tablewrap"><table><thead><tr>{['Date', 'Éleveur', 'Formule', 'Durée', 'Montant', 'Réduction', 'Téléphone', 'État'].map(t => <th key={t}>{t}</th>)}</tr></thead>
            <tbody>{rows.map(r => <tr key={r.id}><td>{fdate(r.cree_le)}</td><td>{who[r.user_id] || '—'}</td><td>{label(r.offre)}</td><td>{r.mois} mois</td><td className="num">{fcfa(r.montant)}</td>
              <td>{r.reduction ? `−${r.reduction} %${r.code_promo ? ' · ' + r.code_promo : ''}` : '—'}</td><td className="mono">{r.telephone || '—'}</td>
              <td><Pill tone={STATE[r.statut]?.[0]}>{STATE[r.statut]?.[1] || r.statut}</Pill>{r.raison && <div className="muted">{r.raison}</div>}</td></tr>)}</tbody></table></div>
            : <p className="muted">Aucun paiement pour le moment.</p>}
        </Card>
      </>;
    }}</Async>
  </>;
}
