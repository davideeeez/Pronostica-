import { useState } from 'react';
import { ShieldCrest } from '../components/icons';
import { useAuth } from '../contexts/AuthContext';
import { crestPatterns, type CrestPattern } from '../data/mock';

export function Onboarding() {
  const { saveProfile } = useAuth();
  const [username, setUsername] = useState('');
  const [crest, setCrest] = useState<CrestPattern>('star');
  const [error, setError] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);

  const trimmed = username.trim();
  const valid = trimmed.length >= 3 && trimmed.length <= 20 && /^[a-zA-Z0-9_.]+$/.test(trimmed);

  async function handleConfirm() {
    if (!valid) return;
    setSaving(true);
    setError(null);
    try {
      await saveProfile({ username: trimmed, crest_pattern: crest });
    } catch (e) {
      const message = e instanceof Error ? e.message : '';
      setError(message.includes('duplicate') || message.includes('unique') ? 'Username già in uso, scegline un altro.' : 'Qualcosa è andato storto, riprova.');
      setSaving(false);
    }
  }

  return (
    <div className="page">
      <div className="page-scroll" style={{ justifyContent: 'center' }}>
        <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 8, padding: '12px 4px' }}>
          <span style={{ fontFamily: 'var(--font-heading)', fontSize: 22 }}>Benvenuto!</span>
          <p style={{ margin: 0, fontSize: 13.5, lineHeight: 1.45, color: 'var(--color-text-secondary)', textAlign: 'center' }}>
            Scegli uno username e uno stemma per il tuo profilo.
          </p>
        </div>

        <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 10 }}>
          <ShieldCrest size={88} pattern={crest} />
        </div>

        <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
          <span className="section-label">USERNAME</span>
          <div className="card" style={{ borderWidth: 1.5, borderColor: 'var(--color-primary)', padding: '15px 16px', display: 'flex', alignItems: 'center', gap: 10, minHeight: 52 }}>
            <input
              value={username}
              onChange={(e) => setUsername(e.target.value.slice(0, 20))}
              placeholder="es. marcorossi_87"
              style={{ flex: 1, minWidth: 0, border: 'none', outline: 'none', background: 'transparent', fontFamily: 'var(--font-heading)', fontSize: 16, color: 'var(--color-text-primary)' }}
            />
            <span style={{ flex: 'none', font: '400 10px/1 var(--font-mono)', color: 'var(--color-text-secondary)' }}>{username.length}/20</span>
          </div>
          <span style={{ fontSize: 11, color: 'var(--color-text-secondary)', padding: '0 4px' }}>3-20 caratteri: lettere, numeri, punto o underscore.</span>
        </div>

        <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
          <span className="section-label">STEMMA</span>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4,minmax(0,1fr))', gap: 6 }}>
            {crestPatterns.map((p) => {
              const active = p === crest;
              return (
                <div
                  key={p}
                  onClick={() => setCrest(p)}
                  style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 7, padding: '10px 4px', borderRadius: 16, background: active ? 'var(--color-bg)' : 'transparent', border: active ? '1.5px solid var(--color-primary)' : '1.5px solid transparent', cursor: 'pointer' }}
                >
                  <ShieldCrest size={44} pattern={p} />
                </div>
              );
            })}
          </div>
        </div>

        {error && <p style={{ margin: 0, fontSize: 12.5, color: '#C0304A', textAlign: 'center' }}>{error}</p>}

        <button
          onClick={handleConfirm}
          disabled={!valid || saving}
          className="btn btn-primary"
          style={{ width: '100%', opacity: !valid || saving ? 0.5 : 1 }}
        >
          {saving ? 'Salvataggio…' : 'Continua'}
        </button>
      </div>
    </div>
  );
}
