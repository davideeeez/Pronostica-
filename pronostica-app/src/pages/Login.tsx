import { useState } from 'react';
import { GoogleIcon, ShieldCrest } from '../components/icons';
import { useAuth } from '../contexts/AuthContext';

export function Login() {
  const { signInWithGoogle } = useAuth();
  const [pending, setPending] = useState(false);

  async function handleClick() {
    setPending(true);
    try {
      await signInWithGoogle();
    } catch {
      setPending(false);
    }
  }

  return (
    <div className="page" style={{ justifyContent: 'center', alignItems: 'center', padding: '0 28px' }}>
      <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 22, width: '100%', maxWidth: 320 }}>
        <ShieldCrest size={72} />
        <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 8, textAlign: 'center' }}>
          <span style={{ fontFamily: 'var(--font-heading)', fontSize: 26 }}>Pronostica!</span>
          <p style={{ margin: 0, fontSize: 14, lineHeight: 1.45, color: 'var(--color-text-secondary)' }}>
            Sfida i tuoi amici sui pronostici di Serie A. Accedi per iniziare.
          </p>
        </div>
        <button
          onClick={handleClick}
          disabled={pending}
          className="btn"
          style={{ width: '100%', background: 'var(--color-surface)', border: '1px solid var(--color-border)', color: 'var(--color-text-primary)', gap: 11, opacity: pending ? 0.7 : 1 }}
        >
          <GoogleIcon />
          {pending ? 'Accesso in corso…' : 'Accedi con Google'}
        </button>
      </div>
    </div>
  );
}
