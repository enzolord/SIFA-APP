import { useState } from 'react';
import { Armed, Async, Card, Note, Pill, useAsync, useToast } from '../ui.jsx';
import { fdate, genCode, getC, must, sb } from '../lib.js';
import { useSession } from '../session.jsx';
import { PROMO_ACCESS, fcfa, legacyLabel, offers } from '../pricing.js';

const copy = async (text, toast) => { try { await navigator.clipboard.writeText(text); toast('Copié.'); } catch { toast('Copie impossible : sélectionnez le texte.', true); } };

/** Code lisible choisi par l'administrateur : lettres, chiffres et tirets, en majuscules. */
const clean = s => s.toUpperCase().replace(/[^A-Z0-9-]/g, '').slice(0, 24);

function AccessCodes({ tarifs }) {
  const toast = useToast(); const { me } = useSession();
  const catalog = offers(tarifs);
  const label = id => legacyLabel[id] || catalog.find(o => o.id === id)?.label || id;
  const codes = useAsync(() => must(sb.from('codes_activation').select('*').order('cree_le', { ascending: false }).limit(80)), []);
  const [kind, setKind] = useState('promo_complet'); const [qty, setQty] = useState(1); const [months, setMonths] = useState(1);
  const create = async () => {
    try {
      const n = Math.max(1, Math.min(50, +qty || 1));
      await must(sb.from('codes_activation').insert(Array.from({ length: n }, () => ({ code: genCode(), formule: kind, duree_mois: months, cree_par: me.id }))));
      toast(n + ' code(s) créé(s).'); codes.reload();
    } catch (e) { toast('Création : ' + e.message, true); }
  };
  return <Card title="Codes d’accès" sub="Donnent un accès sans paiement : à l’analyse seule, à la gestion de ferme seule, ou aux deux. Vous pouvez aussi créer un code pour une formule précise. L’éleveur le saisit dans « Activer ma formule » (connexion Google nécessaire).">
    <div className="actions" style={{ margin: '0 0 14px' }}>
      <select value={kind} onChange={e => setKind(e.target.value)} style={{ width: 'auto', maxWidth: '100%' }}>
        <optgroup label="Accès libre (sans quota)">{PROMO_ACCESS.map(a => <option key={a.id} value={a.id}>{a.label}</option>)}</optgroup>
        <optgroup label="Une formule précise">{catalog.map(o => <option key={o.id} value={o.id}>{o.label} · {fcfa(o.price)}/mois</option>)}</optgroup>
      </select>
      <span>Durée :</span><select value={months} onChange={e => setMonths(+e.target.value)} style={{ width: 'auto' }}>{[1, 2, 3, 6, 12, 24].map(m => <option key={m} value={m}>{m} mois</option>)}</select>
      <span>Nombre :</span><input type="number" min="1" max="50" value={qty} onChange={e => setQty(e.target.value)} style={{ width: 90 }} />
      <button className="btn" type="button" onClick={create}>Créer des codes</button>
    </div>
    <Async state={codes}>{rows => rows.length ? <div className="tablewrap"><table><thead><tr>{['Code', 'Accès', 'Durée', 'Créé', 'État', ''].map(t => <th key={t}>{t}</th>)}</tr></thead>
      <tbody>{rows.map(r => <tr key={r.code}><td className="mono">{r.code}</td><td>{label(r.formule)}</td><td>{r.duree_mois ?? 1} mois</td><td>{fdate(r.cree_le)}</td>
        <td>{r.utilise_par ? <Pill>Utilisé {fdate(r.utilise_le)}</Pill> : <Pill tone="ok">Disponible</Pill>}</td>
        <td>{!r.utilise_par && <><button className="btn small sec" type="button" onClick={() => copy(r.code, toast)}>Copier</button>{' '}
          <Armed label="Supprimer" onConfirm={async () => { try { await must(sb.from('codes_activation').delete().eq('code', r.code)); codes.reload(); } catch (e) { toast('Suppression : ' + e.message, true); } }} /></>}</td></tr>)}</tbody></table></div> : <p className="muted">Aucun code créé.</p>}</Async>
  </Card>;
}

function DiscountCodes() {
  const toast = useToast(); const { me } = useSession();
  const st = useAsync(async () => {
    const list = await must(sb.from('codes_promo').select('*').order('cree_le', { ascending: false }).limit(200));
    const ev = await must(sb.from('evenements').select('props,appareil').eq('nom', 'promo_applique').limit(5000));
    const used = {};
    for (const e of ev) { const c = e.props?.code; if (c) (used[c] ||= new Set()).add(e.appareil); }
    return { list, used: Object.fromEntries(Object.entries(used).map(([k, v]) => [k, v.size])) };
  }, []);
  const [code, setCode] = useState(''); const [pct, setPct] = useState(10); const [until, setUntil] = useState(''); const [note, setNote] = useState('');
  const create = async () => {
    const c = clean(code) || clean('SIFA' + genCode().slice(-4)); const r = Math.max(1, Math.min(100, parseInt(pct, 10) || 0));
    if (c.length < 3) return toast('Le code doit avoir au moins 3 caractères (lettres, chiffres, tirets).', true);
    try {
      await must(sb.from('codes_promo').insert({ code: c, reduction: r, expire_le: until ? new Date(until + 'T23:59:59').toISOString() : null, note: note.trim() || null, cree_par: me.id }));
      toast(`Code ${c} créé : −${r} %.`); setCode(''); setNote(''); st.reload();
    } catch (e) { toast(/duplicate/i.test(e.message) ? 'Ce code existe déjà.' : 'Création : ' + e.message, true); }
  };
  const patch = async (c, values) => { try { await must(sb.from('codes_promo').update(values).eq('code', c)); st.reload(); } catch (e) { toast('Modification : ' + e.message, true); } };
  return <Card title="Codes de réduction" sub="Un pourcentage de réduction que l’éleveur saisit dans l’écran « Formules » : le prix affiché baisse d’autant. Le paiement reste confirmé par vous avant d’envoyer le code d’accès.">
    <div className="actions" style={{ margin: '0 0 14px', alignItems: 'flex-end' }}>
      <div><label className="f">Code (vide = automatique)</label><input value={code} onChange={e => setCode(clean(e.target.value))} placeholder="RENTREE20" style={{ width: 170 }} /></div>
      <div><label className="f">Réduction (%)</label><input type="number" min="1" max="100" value={pct} onChange={e => setPct(e.target.value)} style={{ width: 90 }} /></div>
      <div><label className="f">Valable jusqu’au (facultatif)</label><input type="date" value={until} onChange={e => setUntil(e.target.value)} style={{ width: 170 }} /></div>
      <div><label className="f">Note interne</label><input value={note} onChange={e => setNote(e.target.value)} placeholder="Opération rentrée" style={{ width: 200 }} maxLength={120} /></div>
      <button className="btn" type="button" onClick={create}>Créer le code</button>
    </div>
    <Async state={st}>{({ list, used }) => list.length ? <div className="tablewrap"><table><thead><tr>{['Code', 'Réduction', 'Expire', 'Note', 'Utilisé par', 'État', ''].map(t => <th key={t}>{t}</th>)}</tr></thead>
      <tbody>{list.map(r => {
        const expired = r.expire_le && new Date(r.expire_le) < new Date();
        return <tr key={r.code}><td className="mono">{r.code}</td>
          <td><input type="number" min="1" max="100" defaultValue={r.reduction} style={{ width: 70 }} onBlur={e => { const v = Math.max(1, Math.min(100, parseInt(e.target.value, 10) || r.reduction)); e.target.value = v; if (v !== r.reduction) patch(r.code, { reduction: v }); }} /> %</td>
          <td>{r.expire_le ? fdate(r.expire_le) : '—'}</td><td>{r.note || '—'}</td><td>{used[r.code] || 0} appareil(s)</td>
          <td>{expired ? <Pill tone="bad">Expiré</Pill> : r.actif ? <Pill tone="ok">Actif</Pill> : <Pill>Suspendu</Pill>}</td>
          <td><button className="btn small sec" type="button" onClick={() => copy(r.code, toast)}>Copier</button>{' '}
            <button className="btn small sec" type="button" onClick={() => patch(r.code, { actif: !r.actif })}>{r.actif ? 'Suspendre' : 'Réactiver'}</button>{' '}
            <Armed label="Supprimer" onConfirm={async () => { try { await must(sb.from('codes_promo').delete().eq('code', r.code)); st.reload(); } catch (e) { toast('Suppression : ' + e.message, true); } }} /></td></tr>;
      })}</tbody></table></div> : <p className="muted">Aucun code de réduction.</p>}</Async>
  </Card>;
}

export default function Promo() {
  const tar = useAsync(() => getC('tarifs'), []);
  return <>
    <Note style={{ marginBottom: 14 }}>Deux sortes de codes : les <b>codes d’accès</b> ouvrent l’analyse, la gestion de ferme ou les deux sans paiement ; les <b>codes de réduction</b> baissent le prix affiché dans l’application.</Note>
    <Async state={tar}>{t => <AccessCodes tarifs={t} />}</Async>
    <DiscountCodes />
  </>;
}
