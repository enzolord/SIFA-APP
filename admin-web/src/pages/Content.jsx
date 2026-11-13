import { useEffect, useState } from 'react';
import { Route, Routes } from 'react-router-dom';
import { Armed, Async, BiField, Card, Grid, Note, Pill, SubTabs, bi, useAsync, useToast } from '../ui.jsx';
import { MALADIES, L, fdate, genCode, getC, must, sb, setC } from '../lib.js';
import { useSession } from '../session.jsx';
import BASE from '../data/fichesBase.json';

const TABS = [['/contenu', 'Annonce et maintenance', true], ['/contenu/formules', 'Formules et codes'], ['/contenu/pharmacies', 'Pharmacies'], ['/contenu/fiches', 'Fiches maladies']];
const clone = o => JSON.parse(JSON.stringify(o));

function Announce() {
  const toast = useToast();
  const st = useAsync(async () => ({ a: await getC('annonce'), m: await getC('maintenance') }), []);
  return <Async state={st}>{init => <AnnounceForm init={init} toast={toast} />}</Async>;
}
function AnnounceForm({ init, toast }) {
  const [A, setA] = useState(() => Object.assign({ actif: false, niveau: 'info', titre: bi(), texte: bi() }, init.a));
  const [M, setM] = useState(() => Object.assign({ actif: false, message: bi() }, init.m));
  const save = async (key, val, ok) => { try { await setC(key, val); toast(ok); } catch (e) { toast('Enregistrement : ' + e.message, true); } };
  return <>
    <Card title="Annonce sur l’accueil" sub="Un bandeau en haut de l’accueil, visible en quelques secondes par les éleveurs en ligne. Exemple : alerte Newcastle dans une zone, nouvelle fonctionnalité.">
      <label className="switch"><input type="checkbox" checked={!!A.actif} onChange={e => setA({ ...A, actif: e.target.checked })} />Afficher l’annonce</label>
      <label className="f">Niveau</label>
      <select value={A.niveau} onChange={e => setA({ ...A, niveau: e.target.value })}>{[['info', 'Information (vert)'], ['warn', 'Attention (jaune)'], ['danger', 'Urgent (rouge)']].map(([v, t]) => <option key={v} value={v}>{t}</option>)}</select>
      <BiField label="Titre" value={A.titre} onChange={v => setA({ ...A, titre: v })} />
      <BiField label="Texte" value={A.texte} area onChange={v => setA({ ...A, texte: v })} />
      <label className="f">Aperçu</label>
      {A.actif ? <div className={'preview ' + A.niveau}><div><b>{A.titre.fr || '(titre)'}</b><div>{A.texte.fr || '(texte)'}</div></div></div> : <p className="muted">Annonce désactivée : rien ne s’affiche.</p>}
      <div className="actions"><button className="btn" type="button" onClick={() => save('annonce', A, 'Annonce enregistrée.')}>Enregistrer</button></div>
    </Card>
    <Card title="Mode maintenance" sub="Bloque l’application avec un message, pour une opération sur la base ou un incident. À utiliser rarement.">
      <label className="switch"><input type="checkbox" checked={!!M.actif} onChange={e => setM({ ...M, actif: e.target.checked })} />Activer la maintenance</label>
      <BiField label="Message" value={M.message} area onChange={v => setM({ ...M, message: v })} />
      <div className="actions"><button className="btn danger" type="button" onClick={() => save('maintenance', M, M.actif ? 'Maintenance activée : l’application est bloquée.' : 'Maintenance désactivée.')}>Enregistrer</button></div>
    </Card>
  </>;
}

function Plans() {
  const toast = useToast();
  const { me } = useSession();
  const st = useAsync(() => getC('formules'), []);
  const codes = useAsync(() => must(sb.from('codes_activation').select('*').order('cree_le', { ascending: false }).limit(60)), []);
  const [qty, setQty] = useState(5); const [kind, setKind] = useState('mensuelle');
  return <>
    <Async state={st}>{init => <PlansForm init={init} toast={toast} />}</Async>
    <Card title="Codes d’activation" sub="Après un paiement Mobile Money confirmé, créez un code et envoyez-le à l’éleveur. Il l’entre dans l’application (connexion Google nécessaire).">
      <div className="actions" style={{ margin: '0 0 14px' }}>
        <select value={kind} onChange={e => setKind(e.target.value)} style={{ width: 'auto' }}><option value="mensuelle">Mensuelle</option><option value="annuelle">Annuelle</option></select>
        <span>Nombre :</span><input type="number" min="1" max="20" value={qty} onChange={e => setQty(e.target.value)} style={{ width: 90 }} />
        <button className="btn" type="button" onClick={async () => {
          try { const n = Math.max(1, Math.min(20, +qty || 1)); await must(sb.from('codes_activation').insert(Array.from({ length: n }, () => ({ code: genCode(), formule: kind, cree_par: me.id })))); toast(n + ' code(s) créé(s).'); codes.reload(); }
          catch (e) { toast('Création : ' + e.message, true); }
        }}>Créer des codes</button>
      </div>
      <Async state={codes}>{rows => rows.length ? <div className="tablewrap"><table><thead><tr>{['Code', 'Formule', 'Créé', 'État', ''].map(t => <th key={t}>{t}</th>)}</tr></thead>
        <tbody>{rows.map(r => <tr key={r.code}><td className="mono">{r.code}</td><td>{r.formule}</td><td>{fdate(r.cree_le)}</td>
          <td>{r.utilise_par ? <Pill>Utilisé {fdate(r.utilise_le)}</Pill> : <Pill tone="ok">Disponible</Pill>}</td>
          <td>{!r.utilise_par && <button className="btn small sec" type="button" onClick={async () => { try { await navigator.clipboard.writeText(r.code); toast('Code copié.'); } catch { toast('Copie impossible : sélectionnez le code.', true); } }}>Copier</button>}</td></tr>)}</tbody></table></div> : <p className="muted">Aucun code créé.</p>}</Async>
    </Card>
  </>;
}
function PlansForm({ init, toast }) {
  const [F, setF] = useState(() => {
    const f = Object.assign({ mensuelle: {}, annuelle: {}, paiement: bi() }, init);
    for (const k of ['mensuelle', 'annuelle']) f[k] = { prix: '', ...f[k], desc: bi(f[k]?.desc?.fr, f[k]?.desc?.en) };
    f.paiement = bi(f.paiement?.fr, f.paiement?.en); return f;
  });
  const plan = (k, title) => <div className="item"><h3>{title}</h3>
    <label className="f">Prix affiché (ex. 5 000 FCFA / mois)</label><input type="text" value={F[k].prix} onChange={e => setF({ ...F, [k]: { ...F[k], prix: e.target.value } })} />
    <BiField label="Description" value={F[k].desc} onChange={v => setF({ ...F, [k]: { ...F[k], desc: v } })} /></div>;
  return <Card title="Formules et prix" sub="Ce que les éleveurs voient dans l’écran « Formules ». Les prix sont du texte libre.">
    <Grid>{plan('mensuelle', 'Formule mensuelle')}{plan('annuelle', 'Formule annuelle')}</Grid>
    <div style={{ marginTop: 8 }}><BiField label="Comment payer (Mobile Money, numéro, étapes)" value={F.paiement} area onChange={v => setF({ ...F, paiement: v })} /></div>
    <div className="actions"><button className="btn" type="button" onClick={async () => { try { await setC('formules', F); toast('Formules enregistrées.'); } catch (e) { toast('Enregistrement : ' + e.message, true); } }}>Enregistrer</button></div>
  </Card>;
}

const STOCKS = [['en_stock', 'En stock'], ['limite', 'Stock limité'], ['rupture', 'Rupture'], ['inconnu', 'Non renseigné']];
const blank = () => ({ nom: '', ville: 'Douala', quartier: '', adresse: '', telephone: '', horaires: '', latitude: '', longitude: '', stock: 'inconnu', actif: true });
function Pharmacies() {
  const toast = useToast();
  const st = useAsync(() => must(sb.from('pharmacies').select('*').order('ville').order('nom')), []);
  const [edit, setEdit] = useState(null);
  return <Async state={st}>{rows => <>
    <Card title="Pharmacies vétérinaires" sub="La liste, la carte et le stock affichés aux éleveurs. Un changement apparaît en direct dans l’application.">
      <div className="actions" style={{ margin: '0 0 14px' }}><button className="btn" type="button" onClick={() => setEdit({ isNew: true, d: blank() })}>Ajouter une pharmacie</button></div>
      {rows.length ? <div className="tablewrap"><table><thead><tr>{['Pharmacie', 'Ville', 'Téléphone', 'Stock', 'Mis à jour', 'Visible', ''].map(t => <th key={t}>{t}</th>)}</tr></thead>
        <tbody>{rows.map(p => {
          const old = Date.now() - new Date(p.stock_maj) > 30 * 864e5;
          return <tr key={p.id}><td><b>{p.nom}</b><div className="muted">{[p.quartier, p.adresse].filter(Boolean).join(' · ')}</div></td><td>{p.ville}</td><td>{p.telephone || '—'}</td>
            <td><select style={{ minWidth: 130 }} value={p.stock} onChange={async e => { try { await must(sb.from('pharmacies').update({ stock: e.target.value, stock_maj: new Date().toISOString() }).eq('id', p.id)); toast('Stock mis à jour.'); st.reload(); } catch (x) { toast('Mise à jour : ' + x.message, true); } }}>{STOCKS.map(([v, t]) => <option key={v} value={v}>{t}</option>)}</select></td>
            <td><Pill tone={old ? 'warn' : ''}>{fdate(p.stock_maj)}</Pill></td><td>{p.actif ? 'Oui' : 'Non'}</td>
            <td style={{ whiteSpace: 'nowrap' }}><button className="btn small sec" type="button" onClick={() => setEdit({ isNew: false, d: { ...blank(), ...p } })}>Modifier</button>{' '}
              <Armed label="Supprimer" onConfirm={async () => { try { await must(sb.from('pharmacies').delete().eq('id', p.id)); toast('Pharmacie supprimée.'); st.reload(); } catch (e) { toast('Suppression : ' + e.message, true); } }} /></td></tr>;
        })}</tbody></table></div> : <div className="empty">Aucune pharmacie. Tant que la liste est vide, l’application affiche l’exemple intégré, qui n’est pas réel.</div>}
    </Card>
    {edit && <PharmacyForm key={edit.d.id || 'new'} edit={edit} onClose={() => setEdit(null)} onSaved={() => { setEdit(null); st.reload(); }} toast={toast} />}
  </>}</Async>;
}
function PharmacyForm({ edit, onClose, onSaved, toast }) {
  const [d, setD] = useState(edit.d); const [paste, setPaste] = useState('');
  const set = (k, v) => setD(x => ({ ...x, [k]: v }));
  const inp = (k, label) => <div><label className="f">{label}</label><input type="text" value={d[k] ?? ''} onChange={e => set(k, e.target.value)} /></div>;
  useEffect(() => { const m = paste.match(/(-?\d+(?:[.,]\d+)?)\s*[,; ]\s*(-?\d+(?:[.,]\d+)?)/); if (m) setD(x => ({ ...x, latitude: m[1].replace(',', '.'), longitude: m[2].replace(',', '.') })); }, [paste]);
  async function save() {
    try {
      const la = parseFloat(String(d.latitude).replace(',', '.')), lo = parseFloat(String(d.longitude).replace(',', '.'));
      if (!d.nom.trim() || !d.ville.trim()) throw new Error('Le nom et la ville sont obligatoires.');
      if (!(la >= -90 && la <= 90 && lo >= -180 && lo <= 180)) throw new Error('Position invalide : latitude entre -90 et 90, longitude entre -180 et 180.');
      const rec = { nom: d.nom.trim(), ville: d.ville.trim(), quartier: (d.quartier || '').trim(), adresse: (d.adresse || '').trim(), telephone: (d.telephone || '').trim() || null, horaires: (d.horaires || '').trim(), latitude: la, longitude: lo, stock: d.stock, actif: d.actif };
      if (edit.isNew || rec.stock !== edit.d.stock) rec.stock_maj = new Date().toISOString();
      if (edit.isNew) await must(sb.from('pharmacies').insert(rec)); else await must(sb.from('pharmacies').update(rec).eq('id', d.id));
      toast('Pharmacie enregistrée.'); onSaved();
    } catch (e) { toast('Enregistrement : ' + e.message, true); }
  }
  return <Card title={edit.isNew ? 'Ajouter une pharmacie' : 'Modifier : ' + edit.d.nom}>
    <div className="row2">{inp('nom', 'Nom')}{inp('ville', 'Ville')}{inp('quartier', 'Quartier')}{inp('adresse', 'Adresse')}{inp('telephone', 'Téléphone (ex. +237 6 00 00 00 00)')}{inp('horaires', 'Horaires (ex. Lun–Sam 8h–18h)')}</div>
    <label className="f">Position : dans Google Maps, touchez longuement le lieu puis copiez les deux nombres</label>
    <input type="text" placeholder="Collez ici « 4.0511, 9.7679 » copié depuis Google Maps" value={paste} onChange={e => setPaste(e.target.value)} />
    <div className="row2">{inp('latitude', 'Latitude')}{inp('longitude', 'Longitude')}</div>
    <div className="row2"><div><label className="f">Stock</label><select value={d.stock} onChange={e => set('stock', e.target.value)}>{STOCKS.map(([v, t]) => <option key={v} value={v}>{t}</option>)}</select></div>
      <div><label className="switch" style={{ marginTop: 34 }}><input type="checkbox" checked={!!d.actif} onChange={e => set('actif', e.target.checked)} />Visible dans l’application</label></div></div>
    <div className="actions"><button className="btn" type="button" onClick={save}>Enregistrer</button><button className="btn sec" type="button" onClick={onClose}>Annuler</button></div>
  </Card>;
}

const EVID = [['', '—'], ['proven', 'Prouvé'], ['limited', 'Preuves limitées'], ['unproven', 'Non prouvé'], ['dangerous', 'Déconseillé / dangereux'], ['commonSense', 'Bon sens d’élevage']];
const PARTS = [['maintenant', 'À faire maintenant', 'lines'], ['reconnaitre', 'Comment reconnaître', 'items'], ['scientifique', 'Voie scientifique (vétérinaire)', 'items+ev'], ['artisanal', 'Voie artisanale (traditionnelle)', 'items+ev'], ['prevention', 'Prévention', 'lines'], ['confusions', 'Maladies qui ressemblent', 'lines']];
function Sheets() {
  const st = useAsync(() => getC('fiches'), []);
  return <Async state={st}>{all => <SheetsEditor all={all} reload={st.reload} />}</Async>;
}
function SheetsEditor({ all, reload }) {
  const toast = useToast();
  const [sel, setSel] = useState('coccidiosis');
  const [ed, setEd] = useState(null);
  const has = !!all[sel];
  useEffect(() => { const e = clone(Object.assign({}, BASE[sel], all[sel] || {})); e.risque_humain = bi(e.risque_humain?.fr, e.risque_humain?.en); setEd(e); }, [sel, all]);
  if (!ed) return null;
  const upd = (key, arr) => setEd({ ...ed, [key]: arr });
  return <>
    <Note tone="warn" style={{ marginBottom: 14 }}>Ces fiches sont des conseils de santé. Toute modification doit être validée par le vétérinaire référent de SIFA avant publication.</Note>
    <Note style={{ marginBottom: 14 }}>{has ? 'Cette fiche est modifiée : les éleveurs voient votre version.' : 'Cette fiche affiche le texte intégré de l’application. Modifiez-le puis enregistrez : votre version remplace alors celle de l’application.'}</Note>
    <div className="tabs">{MALADIES.map(k => <button key={k} className={'btn small ' + (k === sel ? '' : 'sec')} type="button" onClick={() => setSel(k)}>{L.maladie[k]}</button>)}</div>
    {PARTS.map(([key, title, kind]) => {
      const arr = ed[key] || [];
      const move = (i, d) => { const j = i + d; if (j < 0 || j >= arr.length) return; const c = [...arr]; [c[i], c[j]] = [c[j], c[i]]; upd(key, c); };
      const put = (i, v) => upd(key, arr.map((x, n) => n === i ? v : x));
      return <Card key={key} title={title}>
        {arr.map((it, i) => <div className="item" key={i}>
          <div className="head"><b>#{i + 1}</b><div style={{ display: 'flex', gap: 4 }}>
            <button className="btn small sec" type="button" onClick={() => move(i, -1)} aria-label="Monter">↑</button><button className="btn small sec" type="button" onClick={() => move(i, 1)} aria-label="Descendre">↓</button>
            <Armed label="Retirer" onConfirm={() => upd(key, arr.filter((_, n) => n !== i))} /></div></div>
          {kind === 'lines' ? <BiField label="Phrase" area value={it} onChange={v => put(i, v)} /> : <>
            <BiField label="Titre" value={it.titre} onChange={v => put(i, { ...it, titre: v })} />
            <BiField label="Texte" area value={it.texte} onChange={v => put(i, { ...it, texte: v })} />
            {kind === 'items+ev' && <div><label className="f">Niveau de preuve</label><select value={it.preuve || ''} onChange={e => put(i, { ...it, preuve: e.target.value || undefined })}>{EVID.map(([v, t]) => <option key={v} value={v}>{t}</option>)}</select></div>}</>}
        </div>)}
        <button className="btn small sec" type="button" style={{ marginTop: 10 }} onClick={() => upd(key, [...arr, kind === 'lines' ? bi() : { titre: bi(), texte: bi() }])}>+ Ajouter</button>
      </Card>;
    })}
    <Card title="Risque pour l’homme"><BiField label="Texte" area value={ed.risque_humain} onChange={v => setEd({ ...ed, risque_humain: v })} /></Card>
    <div className="actions">
      <button className="btn" type="button" onClick={async () => {
        try {
          const clean = clone(ed);
          for (const [k, , kd] of PARTS) clean[k] = (clean[k] || []).filter(x => kd === 'lines' ? (x.fr.trim() || x.en.trim()) : (x.titre.fr.trim() || x.texte.fr.trim()));
          await setC('fiches', { ...all, [sel]: clean }); toast('Fiche enregistrée : visible dans l’application.'); reload();
        } catch (e) { toast('Enregistrement : ' + e.message, true); }
      }}>Enregistrer cette fiche</button>
      {has && <Armed className="btn sec" label="Revenir au texte intégré" onConfirm={async () => { try { const c = { ...all }; delete c[sel]; await setC('fiches', c); toast('Texte intégré rétabli.'); reload(); } catch (e) { toast('Rétablissement : ' + e.message, true); } }} />}
    </div>
  </>;
}

export default function Content() {
  return <><SubTabs items={TABS} /><Routes>
    <Route index element={<Announce />} /><Route path="formules" element={<Plans />} /><Route path="pharmacies" element={<Pharmacies />} /><Route path="fiches" element={<Sheets />} />
  </Routes></>;
}
