import { useEffect, useState } from 'react';
import { Route, Routes } from 'react-router-dom';
import { Armed, Async, BiField, Card, Grid, Note, Pill, SubTabs, bi, useAsync, useToast } from '../ui.jsx';
import { MALADIES, L, fdate, genCode, getC, must, sb, setC } from '../lib.js';
import { useSession } from '../session.jsx';
import BASE from '../data/fichesBase.json';
import { catalogue, packPrice, fcfa, offers, PACKS, TIERS, DEFAULT_TARIFS } from '../pricing.js';

const TABS = [['/contenu', 'Annonce et maintenance', true], ['/contenu/tarifs', 'Tarifs'], ['/contenu/formules', 'Codes et paiement'], ['/contenu/pharmacies', 'Pharmacies'], ['/contenu/fiches', 'Fiches maladies']];
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
  const tar = useAsync(() => getC('tarifs'), []);
  const [qty, setQty] = useState(5); const [kind, setKind] = useState('analyse_solo'); const [months, setMonths] = useState(1);
  return <>
    <Async state={st}>{init => <PlansForm init={init} toast={toast} />}</Async>
    <Card title="Codes d’activation" sub="Après un paiement Mobile Money confirmé, créez un code et envoyez-le à l’éleveur. Il l’entre dans l’application (connexion Google nécessaire).">
      <div className="actions" style={{ margin: '0 0 14px' }}>
        <select value={kind} onChange={e => setKind(e.target.value)} style={{ width: 'auto', maxWidth: '100%' }}>{offers(tar.data || {}).map(o => <option key={o.id} value={o.id}>{o.label} · {fcfa(o.price)}/mois</option>)}</select>
        <span>Durée :</span><select value={months} onChange={e => setMonths(+e.target.value)} style={{ width: 'auto' }}>{[1, 3, 6, 12].map(m => <option key={m} value={m}>{m} mois</option>)}</select>
        <span>Nombre :</span><input type="number" min="1" max="20" value={qty} onChange={e => setQty(e.target.value)} style={{ width: 90 }} />
        <button className="btn" type="button" onClick={async () => {
          try { const n = Math.max(1, Math.min(20, +qty || 1)); await must(sb.from('codes_activation').insert(Array.from({ length: n }, () => ({ code: genCode(), formule: kind, duree_mois: months, cree_par: me.id })))); toast(n + ' code(s) créé(s).'); codes.reload(); }
          catch (e) { toast('Création : ' + e.message, true); }
        }}>Créer des codes</button>
      </div>
      <Async state={codes}>{rows => rows.length ? <div className="tablewrap"><table><thead><tr>{['Code', 'Offre', 'Durée', 'Créé', 'État', ''].map(t => <th key={t}>{t}</th>)}</tr></thead>
        <tbody>{rows.map(r => <tr key={r.code}><td className="mono">{r.code}</td><td>{offers(tar.data || {}).find(o => o.id === r.formule)?.label || r.formule}</td><td>{r.duree_mois ?? 1} mois</td><td>{fdate(r.cree_le)}</td>
          <td>{r.utilise_par ? <Pill>Utilisé {fdate(r.utilise_le)}</Pill> : <Pill tone="ok">Disponible</Pill>}</td>
          <td>{!r.utilise_par && <button className="btn small sec" type="button" onClick={async () => { try { await navigator.clipboard.writeText(r.code); toast('Code copié.'); } catch { toast('Copie impossible : sélectionnez le code.', true); } }}>Copier</button>}</td></tr>)}</tbody></table></div> : <p className="muted">Aucun code créé.</p>}</Async>
    </Card>
  </>;
}
function PlansForm({ init, toast }) {
  const [F, setF] = useState(() => ({ ...init, paiement: bi(init.paiement?.fr, init.paiement?.en) }));
  return <Card title="Comment payer" sub="Texte affiché dans l’écran « Formules » : numéro Mobile Money, étapes, contact.">
    <BiField label="Instructions de paiement" value={F.paiement} area onChange={v => setF({ ...F, paiement: v })} />
    <div className="actions"><button className="btn" type="button" onClick={async () => { try { await setC('formules', F); toast('Instructions enregistrées.'); } catch (e) { toast('Enregistrement : ' + e.message, true); } }}>Enregistrer</button></div>
  </Card>;
}

function Tarifs() {
  const toast = useToast();
  const st = useAsync(() => getC('tarifs'), []);
  return <Async state={st}>{init => <TarifsForm init={init} toast={toast} />}</Async>;
}
function TarifsForm({ init, toast }) {
  const [T, setT] = useState(() => ({ ...DEFAULT_TARIFS, ...init, prix: { ...(init.prix || {}) } }));
  const cat = catalogue(T);
  const [raw, setRaw] = useState(() => Object.fromEntries(Object.entries(init.prix || {}).map(([k, v]) => [k, v === null ? 'devis' : String(v)])));
  const setPrice = (id, text) => {
    setRaw(r => ({ ...r, [id]: text }));
    setT(x => {
      const prix = { ...x.prix }; const n = parseInt(text.replace(/\s/g, ''), 10);
      if (text.toLowerCase() === 'devis') prix[id] = null; else if (n > 0 && /^[\d\s]+$/.test(text)) prix[id] = n; else delete prix[id];
      return { ...x, prix };
    });
  };
  const field = (id, shown) => <input type="text" inputMode="numeric" style={{ width: 120 }} value={raw[id] ?? ''} placeholder={shown == null ? 'devis' : String(shown)} onChange={e => setPrice(id, e.target.value.trim())} />;
  const base = Object.fromEntries([...PACKS.map(p => ['analyse_' + p.key, p.price]), ...TIERS.map(t => ['gestion_' + t.n, t.price])]);
  return <>
    <Note style={{ marginBottom: 14 }}>Ces prix sont ceux affichés dans l’application. Laissez une case vide pour garder le prix officiel (en gris). Tapez <b>devis</b> pour afficher « Sur devis ».</Note>
    <Card title="Formule 1 : analyse fécale" sub="Prix par mois, en FCFA.">
      <div className="tablewrap"><table><thead><tr><th>Pack</th><th className="num">Comptes</th><th className="num">Analyses / mois</th><th>Prix / mois</th><th className="num">Par analyse</th></tr></thead>
        <tbody>{cat.packs.map(p => <tr key={p.id}><td><b>{p.name}</b></td><td className="num">{p.accounts}{p.key === 'entreprise' ? ' et +' : ''}</td><td className="num">{p.analyses}</td><td>{field(p.id, base[p.id])}</td><td className="num">{p.price ? fcfa(Math.round(p.price / p.analyses)) : '—'}</td></tr>)}</tbody></table></div>
      <div className="row2" style={{ marginTop: 10 }}>
        <div><label className="f">+ 1 compte (FCFA / mois)</label><input type="text" inputMode="numeric" value={T.compte_supplementaire} onChange={e => setT({ ...T, compte_supplementaire: parseInt(e.target.value, 10) || 0 })} /></div>
        <div><label className="f">+ 20 analyses (FCFA)</label><input type="text" inputMode="numeric" value={T.analyses_supplementaires} onChange={e => setT({ ...T, analyses_supplementaires: parseInt(e.target.value, 10) || 0 })} /></div>
      </div>
      <div style={{ marginTop: 10 }}>
        <label className="f">Analyses gratuites (à vie, sans formule d’analyse)</label>
        <input type="text" inputMode="numeric" style={{ width: 100 }} value={T.analyses_gratuites ?? 5} onChange={e => setT({ ...T, analyses_gratuites: Math.min(1000, parseInt(e.target.value, 10) || 0) })} />
        <div className="muted" style={{ marginTop: 4 }}>Une fois ce nombre atteint, le scanner est bloqué et propose les formules.</div>
      </div>
    </Card>
    <Card title="Formule 2 : gestion de ferme" sub="Par nombre de sujets, prix par mois. Inclus : achat des poussins, aliment, santé, dépenses, ventes, stocks, clients, rentabilité par bande, rapports QR ; 2 comptes.">
      <div className="tablewrap"><table><thead><tr><th>Palier</th><th>Sujets</th><th>Prix / mois</th></tr></thead>
        <tbody>{cat.tiers.map(x => <tr key={x.id}><td><b>{x.name}</b></td><td>{x.max ? `${x.min} à ${x.max}` : `plus de ${x.min - 1}`}</td><td>{field(x.id, base[x.id])}</td></tr>)}</tbody></table></div>
      <label className="switch" style={{ marginTop: 14 }}><input type="checkbox" checked={!!T.gestion_disponible} onChange={e => setT({ ...T, gestion_disponible: e.target.checked })} />La gestion de ferme est disponible à l’achat dans l’application</label>
      <p className="muted" style={{ margin: 0 }}>Laissez décoché tant que les modules de gestion (achats, ventes, stocks, clients…) ne sont pas dans l’application : les éleveurs voient alors « Bientôt » et ne peuvent pas choisir cette formule.</p>
    </Card>
    <Card title="Formule 3 : pack complet" sub="Somme de l’analyse et de la gestion, moins la réduction, arrondie aux 50 FCFA supérieurs.">
      <label className="f">Réduction (%)</label><input type="text" inputMode="numeric" style={{ width: 100 }} value={T.reduction_pack} onChange={e => setT({ ...T, reduction_pack: Math.min(90, parseInt(e.target.value, 10) || 0) })} />
      <div className="tablewrap" style={{ marginTop: 12 }}><table><thead><tr><th>Combinaison</th><th className="num">Somme</th><th className="num">Pack complet</th><th className="num">Économie</th></tr></thead>
        <tbody>{[['solo', 1], ['solo', 2], ['equipe', 3], ['pro', 4], ['entreprise', 6]].map(([k, n]) => { const a = cat.packs.find(p => p.key === k), g = cat.tiers.find(x => x.n === n), pr = packPrice(a, g, cat.discount), sum = a.price + g.price; return <tr key={k + n}><td>{a.name.replace('Analyse ', '')} + {g.name}</td><td className="num">{fcfa(sum)}</td><td className="num"><b>{fcfa(pr)}</b></td><td className="num">{fcfa(sum - pr)}</td></tr>; })}</tbody></table></div>
    </Card>
    <div className="actions"><button className="btn" type="button" onClick={async () => { try { await setC('tarifs', T); toast('Tarifs enregistrés : visibles dans l’application.'); } catch (e) { toast('Enregistrement : ' + e.message, true); } }}>Enregistrer les tarifs</button></div>
  </>;
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
    <Route index element={<Announce />} /><Route path="tarifs" element={<Tarifs />} /><Route path="formules" element={<Plans />} /><Route path="pharmacies" element={<Pharmacies />} /><Route path="fiches" element={<Sheets />} />
  </Routes></>;
}
