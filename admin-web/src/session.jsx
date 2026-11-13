import { createContext, useContext, useEffect, useState } from 'react';
import { sb, must, fdate } from './lib.js';

const Ctx = createContext(null);
export const useSession = () => useContext(Ctx);

export function SessionProvider({ children }) {
  const [state, setState] = useState({ status: 'loading', me: null, message: null });
  useEffect(() => {
    let alive = true;
    async function enter(session) {
      if (!alive) return;
      if (!session) return setState(s => ({ status: 'out', me: null, message: s.message }));
      try {
        const me = await must(sb.from('profiles').select('id,role,email').eq('id', session.user.id).maybeSingle());
        if (!alive) return;
        if (!me || me.role !== 'admin') {
          setState({ status: 'out', me: null, message: { sql: `update public.profiles set role = 'admin' where id = '${session.user.id}';` } });
          await sb.auth.signOut(); return;
        }
        setState({ status: 'in', me, message: null });
      } catch (e) { setState({ status: 'out', me: null, message: { text: 'Lecture du profil impossible : ' + e.message } }); }
    }
    sb.auth.getSession().then(({ data }) => enter(data.session));
    const { data: sub } = sb.auth.onAuthStateChange((ev, session) => { if (ev === 'SIGNED_IN' || ev === 'SIGNED_OUT') enter(session); });
    return () => { alive = false; sub.subscription.unsubscribe(); };
  }, []);
  return <Ctx.Provider value={state}>{children}</Ctx.Provider>;
}

export function Login({ message }) {
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState('');
  return (
    <div className="login">
      <form className="login-card" onSubmit={async e => {
        e.preventDefault(); setBusy(true); setErr('');
        const f = new FormData(e.target);
        const { error } = await sb.auth.signInWithPassword({ email: String(f.get('email')).trim(), password: String(f.get('pwd')) });
        setBusy(false); if (error) setErr('Connexion refusée : ' + error.message);
      }}>
        <div className="brandmark"><img src="/logo-sifa.png" alt="" width="44" height="44" /> SIFA Admin</div>
        <h1 style={{ marginTop: 18 }}>Connexion</h1>
        <p className="muted" style={{ margin: '6px 0 4px' }}>Réservé aux administrateurs de SIFA.</p>
        <label className="f" htmlFor="email">E-mail</label>
        <input type="email" id="email" name="email" autoComplete="username" required />
        <label className="f" htmlFor="pwd">Mot de passe</label>
        <input type="password" id="pwd" name="pwd" autoComplete="current-password" required />
        <div className="actions"><button className="btn" type="submit" disabled={busy}>{busy ? 'Connexion…' : 'Se connecter'}</button></div>
        {err && <p className="note bad" style={{ marginTop: 14 }}>{err}</p>}
        {message?.text && <p className="note bad" style={{ marginTop: 14 }}>{message.text}</p>}
        {message?.sql && <p className="note bad" style={{ marginTop: 14 }}>Ce compte n’est pas administrateur. Dans Supabase (SQL Editor), exécutez :<br /><code className="mono">{message.sql}</code></p>}
      </form>
    </div>
  );
}

export { fdate };
