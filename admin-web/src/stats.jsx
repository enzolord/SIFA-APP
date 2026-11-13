import { createContext, useCallback, useContext, useEffect, useState } from 'react';
import { sb, must } from './lib.js';

const Ctx = createContext(null);
export const useStats = () => useContext(Ctx);
export const DAYS = [7, 30, 90, 365];

/** Statistiques agrégées (fonction SQL stats_admin), partagées par toutes les pages. */
export function StatsProvider({ children }) {
  const [days, setDays] = useState(() => { try { return +localStorage.getItem('sifa_days') || 30; } catch { return 30; } });
  const [state, setState] = useState({ loading: true });
  const [tick, setTick] = useState(0);
  useEffect(() => {
    let alive = true;
    setState(s => ({ ...s, loading: true, error: undefined }));
    must(sb.rpc('stats_admin', { p_jours: days })).then(data => alive && setState({ data })).catch(error => alive && setState({ error }));
    return () => { alive = false; };
  }, [days, tick]);
  const setPeriod = useCallback(d => { setDays(d); try { localStorage.setItem('sifa_days', String(d)); } catch { /* stockage indisponible */ } }, []);
  return <Ctx.Provider value={{ days, setPeriod, refresh: () => setTick(t => t + 1), ...state }}>{children}</Ctx.Provider>;
}

/** Enveloppe d'une page qui dépend des statistiques. */
export function WithStats({ children }) {
  const s = useStats();
  if (s.error) return <div className="note bad">Impossible de charger les statistiques : {s.error.message}<br />Exécutez supabase/admin.sql dans Supabase (SQL Editor).</div>;
  if (!s.data) return <div className="empty">Chargement…</div>;
  return children(s.data, s);
}
