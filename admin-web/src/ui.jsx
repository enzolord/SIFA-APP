import { createContext, useCallback, useContext, useEffect, useRef, useState } from 'react';
import { NavLink } from 'react-router-dom';
import { Chart, registerables } from 'chart.js';
import { css, nf } from './lib.js';

Chart.register(...registerables);

/* ───── Messages ───── */
const ToastCtx = createContext(() => {});
export const useToast = () => useContext(ToastCtx);
export function ToastProvider({ children }) {
  const [t, setT] = useState(null);
  const timer = useRef();
  const toast = useCallback((msg, bad) => {
    setT({ msg, bad }); clearTimeout(timer.current);
    timer.current = setTimeout(() => setT(null), bad ? 6000 : 2800);
  }, []);
  return <ToastCtx.Provider value={toast}>{children}{t && <div className={'toast' + (t.bad ? ' bad' : '')} role="status">{t.msg}</div>}</ToastCtx.Provider>;
}

/* ───── Composants de base ───── */
export const Card = ({ title, sub, children, className = '', style }) => (
  <div className={'card ' + className} style={style}>
    {title && <h2>{title}</h2>}
    {sub && <p className="sub">{sub}</p>}
    {children}
  </div>
);
export const Kpi = ({ label, value, detail, tone = '' }) => (
  <div className={'kpi ' + tone}><div className="l">{label}</div><div className="v">{value}</div>{detail && <div className="d">{detail}</div>}</div>
);
export const Kpis = ({ children }) => <div className="kpis">{children}</div>;
export const Grid = ({ n = 2, children }) => <div className={'grid g' + n}>{children}</div>;
export const Note = ({ tone = '', children, style }) => <div className={'note ' + tone} style={style}>{children}</div>;
export const Pill = ({ tone = '', children }) => <span className={'pill ' + tone}>{children}</span>;
export const Empty = ({ children }) => <div className="empty">{children}</div>;
export const Loading = () => <div className="empty">Chargement…</div>;
export const Err = ({ error }) => (
  <Note tone="bad">Impossible de charger cette page : {error?.message || String(error)}
    {/stats_admin|function|relation|does not exist/i.test(error?.message || '') && <><br />Exécutez supabase/admin.sql dans Supabase (SQL Editor), puis actualisez.</>}
  </Note>
);

export function Armed({ label, onConfirm, className = 'btn small danger' }) {
  const [armed, setArmed] = useState(false);
  useEffect(() => { if (!armed) return; const t = setTimeout(() => setArmed(false), 3500); return () => clearTimeout(t); }, [armed]);
  return <button type="button" className={className} onClick={() => { if (armed) { setArmed(false); onConfirm(); } else setArmed(true); }}>{armed ? 'Confirmer ?' : label}</button>;
}

export function Bar({ value, max = 1, bad }) {
  return <div className={'bar' + (bad ? ' bad' : '')}><i style={{ width: Math.round(100 * Math.min(1, value / (max || 1))) + '%' }} /></div>;
}

export function SimpleList({ pairs, empty = 'Pas encore de données.' }) {
  if (!pairs.length) return <p className="muted">{empty}</p>;
  const max = Math.max(1, ...pairs.map(p => p[1]));
  return <div>{pairs.map(([k, v]) => (
    <div className="todo" style={{ alignItems: 'center' }} key={k}>
      <div style={{ flex: 1, minWidth: 0 }}>{k}</div>
      <div style={{ width: 80 }}><Bar value={v} max={max} /></div>
      <b style={{ minWidth: 36, textAlign: 'right' }}>{nf(v)}</b>
    </div>))}</div>;
}

export function BarTable({ rows, cols }) {
  const max = Math.max(1, ...rows.map(r => r.value));
  return <div className="tablewrap"><table>
    <thead><tr>{cols.map((c, i) => <th key={c} className={i ? 'num' : ''}>{c}</th>)}<th /></tr></thead>
    <tbody>{rows.length ? rows.map(r => <tr key={r.label}><td>{r.label}</td>{r.cells.map((c, i) => <td key={i} className="num">{c}</td>)}<td style={{ width: '30%' }}><Bar value={r.value} max={max} /></td></tr>)
      : <tr><td colSpan={cols.length + 1} className="empty">Pas encore de données.</td></tr>}</tbody>
  </table></div>;
}

/** Tableau « avis / justes / % » utilisé par plusieurs pages de qualité. */
export function RateTable({ rows }) {
  return <div className="tablewrap"><table>
    <thead><tr><th /><th className="num">Avis</th><th className="num">Justes</th><th /></tr></thead>
    <tbody>{rows.map(([label, o]) => {
      o = o || { retours: 0, justes: 0 };
      return <tr key={label}><td>{label}</td><td className="num">{nf(o.retours)}</td>
        <td className="num">{o.retours ? (100 * o.justes / o.retours).toFixed(0) + ' %' : '—'}</td>
        <td style={{ width: '30%' }}>{o.retours ? <Bar value={o.justes} max={o.retours} bad={o.justes / o.retours < .6} /> : null}</td></tr>;
    })}</tbody></table></div>;
}

export function SubTabs({ items }) {
  return <div className="subtabs" role="tablist">{items.map(([to, label, end]) => <NavLink key={to} to={to} end={end} className={({ isActive }) => (isActive ? 'active' : '')}>{label}</NavLink>)}</div>;
}

export function PageHead({ title, children }) {
  return <div style={{ display: 'flex', flexWrap: 'wrap', gap: 12, alignItems: 'center', justifyContent: 'space-between', marginBottom: 14 }}><h1>{title}</h1>{children}</div>;
}

/* ───── Graphiques (couleurs lues dans le thème) ───── */
export function ChartBox({ config, tall, empty }) {
  const ref = useRef();
  useEffect(() => {
    if (empty || !ref.current) return;
    const ink = css('--muted'), grid = css('--grid');
    Chart.defaults.font.family = css('--font-body'); Chart.defaults.color = ink;
    const cfg = typeof config === 'function' ? config() : config;
    cfg.options = Object.assign({ responsive: true, maintainAspectRatio: false, animation: false }, cfg.options || {});
    if (cfg.options.scales) for (const s of Object.values(cfg.options.scales)) { s.grid = Object.assign({ color: grid }, s.grid); s.ticks = Object.assign({ precision: 0 }, s.ticks); }
    const c = new Chart(ref.current, cfg);
    return () => c.destroy();
  }, [config, empty]);
  if (empty) return <Empty>{typeof empty === 'string' ? empty : 'Pas encore de données.'}</Empty>;
  return <div className={'chart' + (tall ? ' tall' : '')}><canvas ref={ref} /></div>;
}
export const col = n => css(n);

/* ───── Champs FR / EN ───── */
export const bi = (fr, en) => ({ fr: fr || '', en: en || '' });
export function BiField({ label, value, onChange, area }) {
  const Tag = area ? 'textarea' : 'input';
  return <div className="row2">{['fr', 'en'].map(l => (
    <div key={l}><label className="f">{label} ({l === 'fr' ? 'français' : 'anglais'})</label>
      <Tag {...(area ? {} : { type: 'text' })} value={value?.[l] || ''} onChange={e => onChange({ ...value, [l]: e.target.value })} /></div>))}</div>;
}

/** Charge des données asynchrones avec état de chargement et erreur. */
export function useAsync(fn, deps) {
  const [s, setS] = useState({ loading: true });
  const [tick, setTick] = useState(0);
  useEffect(() => {
    let alive = true;
    setS(p => ({ ...p, loading: true, error: undefined }));
    Promise.resolve().then(fn).then(data => alive && setS({ data })).catch(error => { console.error(error); alive && setS({ error }); });
    return () => { alive = false; };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [...deps, tick]);
  return { ...s, reload: () => setTick(t => t + 1) };
}
export function Async({ state, children }) {
  if (state.error) return <Err error={state.error} />;
  if (state.data === undefined) return <Loading />;
  return children(state.data);
}
