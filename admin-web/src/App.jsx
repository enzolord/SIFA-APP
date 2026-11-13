import { useEffect, useState } from 'react';
import { NavLink, Route, Routes, useLocation, Navigate } from 'react-router-dom';
import { sb } from './lib.js';
import { Login, SessionProvider, useSession } from './session.jsx';
import { StatsProvider, useStats, DAYS } from './stats.jsx';
import { ToastProvider } from './ui.jsx';
import Overview from './pages/Overview.jsx';
import Reports from './pages/Reports.jsx';
import Users from './pages/Users.jsx';
import Features from './pages/Features.jsx';
import Quality from './pages/Quality.jsx';
import Gemini from './pages/Gemini.jsx';
import Training from './pages/Training.jsx';
import Content from './pages/Content.jsx';
import Community from './pages/Community.jsx';

const NAV = [
  { group: 'Pilotage' },
  { to: '/', label: 'Vue d’ensemble', end: true, period: true },
  { to: '/utilisateurs', label: 'Utilisateurs', period: true },
  { to: '/fonctionnalites', label: 'Fonctionnalités', period: true },
  { to: '/qualite', label: 'Qualité des réponses', period: true },
  { to: '/gemini', label: 'Photos et Gemini', period: true },
  { to: '/rapports', label: 'Rapports et exports', period: true },
  { group: 'Améliorer SIFA' },
  { to: '/entrainement', label: 'Photos et entraînement' },
  { group: 'Contenu de l’application' },
  { to: '/contenu', label: 'Contenu en direct' },
  { group: 'Gestion' },
  { to: '/communaute', label: 'Communauté' },
];

function useInstall() {
  const [evt, setEvt] = useState(null);
  const [done, setDone] = useState(() => window.matchMedia?.('(display-mode: standalone)').matches);
  useEffect(() => {
    const on = e => { e.preventDefault(); setEvt(e); };
    const ok = () => { setDone(true); setEvt(null); };
    window.addEventListener('beforeinstallprompt', on); window.addEventListener('appinstalled', ok);
    return () => { window.removeEventListener('beforeinstallprompt', on); window.removeEventListener('appinstalled', ok); };
  }, []);
  return { canInstall: !!evt && !done, install: async () => { if (!evt) return; evt.prompt(); await evt.userChoice; setEvt(null); } };
}

function Shell() {
  const { me } = useSession();
  const stats = useStats();
  const loc = useLocation();
  const { canInstall, install } = useInstall();
  const cur = NAV.filter(n => n.to).sort((a, b) => b.to.length - a.to.length).find(n => (n.end ? loc.pathname === n.to : loc.pathname.startsWith(n.to)));
  useEffect(() => { window.scrollTo(0, 0); document.title = (cur?.label ? cur.label + ' · ' : '') + 'SIFA Admin'; }, [loc.pathname, cur?.label]);
  return (
    <div className="shell">
      <aside>
        <div className="brandmark"><i>S</i> SIFA Admin</div>
        <nav aria-label="Sections">
          {NAV.map((n, i) => n.group ? <div className="nav-group" key={i}>{n.group}</div>
            : <NavLink key={n.to} to={n.to} end={n.end} className={({ isActive }) => (isActive ? 'active' : '')}>{n.label}</NavLink>)}
        </nav>
        <div className="sidefoot noprint">
          {canInstall && <button className="btn small" type="button" onClick={install}>Installer l’application</button>}
          <div className="muted" style={{ fontSize: 12, wordBreak: 'break-all' }}>{me?.email}</div>
        </div>
      </aside>
      <main>
        <div className="topbar">
          <span className="stamp">{stats.data ? 'Statistiques du ' + new Date(stats.data.genere_le).toLocaleString('fr-FR', { dateStyle: 'short', timeStyle: 'short' }) : stats.loading ? 'Chargement…' : ''}</span>
          <div className="right">
            {cur?.period && <div className="seg" role="group" aria-label="Période">{DAYS.map(d => <button key={d} type="button" aria-pressed={d === stats.days} onClick={() => stats.setPeriod(d)}>{d === 365 ? '1 an' : d + ' j'}</button>)}</div>}
            <button className="btn sec small" type="button" onClick={() => { stats.refresh(); window.dispatchEvent(new Event('sifa-refresh')); }}>Actualiser</button>
            <button className="btn sec small" type="button" onClick={() => sb.auth.signOut()}>Déconnexion</button>
          </div>
        </div>
        <div className="view">
          <Routes>
            <Route path="/" element={<Overview />} />
            <Route path="/utilisateurs/*" element={<Users />} />
            <Route path="/fonctionnalites" element={<Features />} />
            <Route path="/qualite/*" element={<Quality />} />
            <Route path="/gemini/*" element={<Gemini />} />
            <Route path="/rapports" element={<Reports />} />
            <Route path="/entrainement/*" element={<Training />} />
            <Route path="/contenu/*" element={<Content />} />
            <Route path="/communaute" element={<Community />} />
            <Route path="*" element={<Navigate to="/" replace />} />
          </Routes>
        </div>
      </main>
    </div>
  );
}

function Gate() {
  const s = useSession();
  if (s.status === 'loading') return <div className="login"><div className="empty">Chargement…</div></div>;
  if (s.status === 'out') return <Login message={s.message} />;
  return <StatsProvider><Shell /></StatsProvider>;
}

export default function App() {
  return <ToastProvider><SessionProvider><Gate /></SessionProvider></ToastProvider>;
}
