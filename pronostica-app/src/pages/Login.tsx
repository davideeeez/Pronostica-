import { useEffect, useState } from 'react';
import { GoogleIcon, ShieldCrest } from '../components/icons';
import { useAuth } from '../contexts/AuthContext';

export function Login() {
  const { signInWithGoogle, authError, clearAuthError } = useAuth();
  const [pending, setPending] = useState(false);

  useEffect(() => {
    if (authError) setPending(false);
  }, [authError]);

  async function handleClick() {
    setPending(true);
    clearAuthError();
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
        {authError && (
          <div style={{ width: '100%', background: 'rgba(192,48,74,.1)', border: '1px solid rgba(192,48,74,.35)', borderRadius: 12, padding: '11px 13px', display: 'flex', flexDirection: 'column', gap: 3 }}>
            <span style={{ font: '600 10px/1 var(--font-mono)', letterSpacing: '.08em', color: '#C0304A' }}>ACCESSO NON RIUSCITO</span>
            <span style={{ fontSize: 12.5, lineHeight: 1.4, color: 'var(--color-text-primary)' }}>{authError}</span>
          </div>
        )}
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
