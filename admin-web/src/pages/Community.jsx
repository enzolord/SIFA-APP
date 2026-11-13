import { useState } from 'react';
import { Armed, Async, Card, Pill, useAsync, useToast } from '../ui.jsx';
import { fdate, must, sb } from '../lib.js';

export default function Community() {
  const toast = useToast();
  const [hidden, setHidden] = useState({}); const [gone, setGone] = useState({});
  const st = useAsync(async () => {
    const [pubs, sigs, groups] = await Promise.all([
      must(sb.from('publications').select('id,groupe_id,auteur_id,titre,texte,masque,cree_le').order('cree_le', { ascending: false }).limit(60)),
      must(sb.from('signalements').select('publication_id,commentaire_id,motif,cree_le').order('cree_le', { ascending: false }).limit(200)),
      must(sb.from('groupes').select('id,nom')),
    ]);
    const ids = [...new Set(pubs.map(p => p.auteur_id))];
    const authors = ids.length ? await must(sb.from('profiles').select('id,nom,email').in('id', ids)) : [];
    return { pubs, sigs, groups, authors };
  }, []);
  return <Async state={st}>{({ pubs, sigs, groups, authors }) => {
    const who = Object.fromEntries(authors.map(a => [a.id, a.nom || a.email || 'Éleveur']));
    const gname = Object.fromEntries(groups.map(g => [g.id, g.nom]));
    const count = {}, motifs = {};
    sigs.forEach(x => { if (x.publication_id) { count[x.publication_id] = (count[x.publication_id] || 0) + 1; if (x.motif) (motifs[x.publication_id] ||= []).push(x.motif); } });
    const list = [...pubs].filter(p => !gone[p.id]).sort((a, b) => (count[b.id] || 0) - (count[a.id] || 0));
    const isHidden = p => hidden[p.id] ?? p.masque;
    return <Card title="Publications" sub={`Les plus signalées d’abord. ${sigs.length} signalement(s) au total.`}>
      {list.length ? <div className="tablewrap"><table><thead><tr>{['Publication', 'Groupe', 'Auteur', 'Date', 'Signalements', 'État', ''].map(t => <th key={t}>{t}</th>)}</tr></thead>
        <tbody>{list.map(p => <tr key={p.id}>
          <td style={{ maxWidth: 340 }}><b>{p.titre}</b><div className="muted">{(p.texte || '').slice(0, 140)}</div>{motifs[p.id] && <div style={{ marginTop: 4 }}><Pill tone="warn">Motif : {motifs[p.id][0]}</Pill></div>}</td>
          <td>{gname[p.groupe_id] || p.groupe_id}</td><td>{who[p.auteur_id] || '—'}</td><td>{fdate(p.cree_le)}</td>
          <td className="num">{count[p.id] ? <Pill tone="warn">{count[p.id]}</Pill> : '0'}</td>
          <td>{isHidden(p) ? <Pill tone="bad">Masquée</Pill> : <Pill tone="ok">Visible</Pill>}</td>
          <td style={{ whiteSpace: 'nowrap' }}>
            <button className="btn small sec" type="button" onClick={async () => { try { const v = !isHidden(p); await must(sb.from('publications').update({ masque: v }).eq('id', p.id)); setHidden(h => ({ ...h, [p.id]: v })); toast(v ? 'Publication masquée.' : 'Publication rétablie.'); } catch (e) { toast('Modération : ' + e.message, true); } }}>{isHidden(p) ? 'Rétablir' : 'Masquer'}</button>{' '}
            <Armed label="Supprimer" onConfirm={async () => { try { await must(sb.from('publications').delete().eq('id', p.id)); setGone(g => ({ ...g, [p.id]: true })); toast('Publication supprimée.'); } catch (e) { toast('Suppression : ' + e.message, true); } }} /></td>
        </tr>)}</tbody></table></div> : <div className="empty">Aucune publication pour le moment.</div>}
    </Card>;
  }}</Async>;
}
