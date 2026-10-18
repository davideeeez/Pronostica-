import { useRef, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { PageHeader } from '../../components/PageHeader';
import { CodeIcon } from '../../components/icons';
import { useMyLeagues } from '../../hooks/useMyLeagues';
import { joinPrivateLeague } from '../../lib/leagues';

export function LegheCodice() {
  const navigate = useNavigate();
  const { refreshLeagues } = useMyLeagues();
  const [code, setCode] = useState('');
  const [submitting, setSubmitting] = useState(false);
  // Blocco sincrono: due tap ravvicinati non possono far partire due chiamate, qualunque sia il momento del render.
  const submitLock = useRef(false);
  const [error, setError] = useState<string | null>(null);
  const [info, setInfo] = useState<string | null>(null);

  async function handleSubmit() {
    // Rimuove TUTTI gli spazi (non solo ai bordi): l'utente può incollare un
    // codice con spazi ovunque, il confronto server-side ignora comunque il
    // maiuscolo/minuscolo ma non spazi interni non ai bordi.
    const cleaned = code.replace(/\s+/g, '');
    if (!cleaned || submitLock.current) return;
    submitLock.current = true;

    setSubmitting(true);
    setError(null);
    setInfo(null);
    try {
      const { outcome, leagueId } = await joinPrivateLeague(cleaned);
      if (outcome === 'ok' && leagueId) {
        await refreshLeagues();
        navigate(`/menu/leghe/${leagueId}`);
        return;
      }
      if (outcome === 'already_member' && leagueId) {
        setInfo('Sei già in questa lega');
        await refreshLeagues();
        navigate(`/menu/leghe/${leagueId}`);
        return;
      }
      setError('Codice non valido, riprova tra qualche minuto');
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Errore sconosciuto.');
    } finally {
      submitLock.current = false;
      setSubmitting(false);
    }
  }

  return (
    <div className="page">
      <PageHeader title="Ho un codice" />

      <div className="page-scroll">
        <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
          <span className="section-label">CODICE INVITO</span>
          <div className="card" style={{ borderWidth: 1.5, borderColor: 'var(--color-primary)', padding: '15px 16px', display: 'flex', alignItems: 'center', gap: 10, minHeight: 52 }}>
            <CodeIcon />
            <input
              value={code}
              onChange={(e) => setCode(e.target.value)}
              placeholder="Es. ab3d f7k2"
              autoCapitalize="none"
              autoCorrect="off"
              style={{ flex: 1, minWidth: 0, border: 'none', outline: 'none', background: 'transparent', fontFamily: 'var(--font-heading)', fontSize: 16, letterSpacing: '.08em', color: 'var(--color-text-primary)' }}
            />
          </div>
          <span style={{ fontSize: 11, lineHeight: 1.35, color: 'var(--color-text-secondary)', padding: '0 4px' }}>
            Maiuscole, minuscole e spazi non contano.
          </span>
        </div>

        {info && <p style={{ color: 'var(--color-text-secondary)', fontSize: 13, textAlign: 'center' }}>{info}</p>}
        {error && <p style={{ color: '#C0304A', fontSize: 13, textAlign: 'center' }}>{error}</p>}

        <div style={{ paddingTop: 4 }}>
          <button className="btn btn-primary" style={{ width: '100%' }} disabled={submitting || !code.replace(/\s+/g, '')} aria-busy={submitting} onClick={handleSubmit}>
            {submitting ? 'Verifica in corso…' : 'Entra nella lega'}
          </button>
        </div>
      </div>
    </div>
  );
}
