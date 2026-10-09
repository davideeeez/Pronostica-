import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { PageHeader } from '../../components/PageHeader';
import { LockIcon, GlobeIcon, CheckCircleIcon, CopyIcon, ShareIcon } from '../../components/icons';
import { useCalendar } from '../../hooks/useCalendar';
import { createLeague, fetchLeagueInviteCode, type LeagueVisibility } from '../../lib/leagues';

export function LegheCrea() {
  const navigate = useNavigate();
  const { loading: calendarLoading, error: calendarError, rounds, currentRound } = useCalendar();
  const [name, setName] = useState('');
  const [visibility, setVisibility] = useState<LeagueVisibility>('private');
  const [startRound, setStartRound] = useState<number | null>(null);
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [created, setCreated] = useState<{ leagueId: string; code: string | null } | null>(null);
  const [copied, setCopied] = useState(false);

  const minRound = currentRound?.roundNumber ?? null;
  const maxRound = rounds.length > 0 ? Math.max(...rounds.map((r) => r.roundNumber)) : null;
  const effectiveStartRound = startRound ?? minRound;

  const trimmedName = name.trim();
  const nameValid = trimmedName.length >= 3 && trimmedName.length <= 40;
  const canSubmit = nameValid && effectiveStartRound !== null && !submitting;

  async function handleSubmit() {
    if (!canSubmit || effectiveStartRound === null) return;
    setSubmitting(true);
    setError(null);
    try {
      const leagueId = await createLeague(trimmedName, visibility, effectiveStartRound);
      const code = visibility === 'private' ? await fetchLeagueInviteCode(leagueId) : null;
      setCreated({ leagueId, code });
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Errore sconosciuto.');
    } finally {
      setSubmitting(false);
    }
  }

  async function handleCopy(code: string) {
    try {
      await navigator.clipboard.writeText(code);
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
    } catch {
      // clipboard non disponibile: nessun effetto, l'utente può selezionare il testo a mano
    }
  }

  async function handleShare(code: string) {
    if (!navigator.share) return;
    try {
      await navigator.share({ title: 'Pronostica!', text: `Unisciti alla mia lega su Pronostica! con il codice ${code}` });
    } catch {
      // condivisione annullata dall'utente: nessun errore da mostrare
    }
  }

  if (created) {
    return (
      <div className="page">
        <PageHeader title="Lega creata" />
        <div className="page-scroll">
          <div className="card-dark" style={{ padding: 18, display: 'flex', flexDirection: 'column', gap: 10 }}>
            <span style={{ fontFamily: 'var(--font-heading)', fontSize: 18 }}>{trimmedName}</span>
            <span style={{ fontSize: 13, color: '#A9B4CC' }}>La lega è pronta.</span>
          </div>

          {created.code && (
            <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
              <span className="section-label">CODICE INVITO</span>
              <div className="card" style={{ padding: '15px 16px', display: 'flex', alignItems: 'center', gap: 11 }}>
                <span style={{ flex: 1, minWidth: 0, fontFamily: 'var(--font-heading)', fontSize: 20, letterSpacing: '.1em' }}>{created.code}</span>
                <div
                  onClick={() => handleCopy(created.code!)}
                  style={{ flex: 'none', display: 'flex', alignItems: 'center', gap: 7, background: 'var(--color-accent)', borderRadius: 12, padding: '11px 13px', minHeight: 44, cursor: 'pointer' }}
                >
                  <CopyIcon />
                  <span style={{ font: '600 12px/1 var(--font-body)' }}>{copied ? 'Copiato!' : 'Copia'}</span>
                </div>
                {typeof navigator.share === 'function' && (
                  <div
                    onClick={() => handleShare(created.code!)}
                    style={{ flex: 'none', display: 'flex', alignItems: 'center', gap: 7, background: 'var(--color-bg)', borderRadius: 12, padding: '11px 13px', minHeight: 44, cursor: 'pointer' }}
                  >
                    <ShareIcon />
                  </div>
                )}
              </div>
            </div>
          )}

          <button className="btn btn-primary" style={{ width: '100%' }} onClick={() => navigate(`/menu/leghe/${created.leagueId}`)}>
            Vai alla lega
          </button>
        </div>
      </div>
    );
  }

  return (
    <div className="page">
      <PageHeader title="Crea lega" />

      <div className="page-scroll">
        <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
          <span className="section-label">NOME LEGA</span>
          <div className="card" style={{ borderWidth: 1.5, borderColor: 'var(--color-primary)', padding: '15px 16px', display: 'flex', alignItems: 'center', gap: 10, minHeight: 52 }}>
            <input
              value={name}
              onChange={(e) => setName(e.target.value.slice(0, 40))}
              placeholder="Es. Amici del lunedì"
              style={{ flex: 1, minWidth: 0, border: 'none', outline: 'none', background: 'transparent', fontFamily: 'var(--font-heading)', fontSize: 16, color: 'var(--color-text-primary)' }}
            />
            <span style={{ flex: 'none', font: '400 10px/1 var(--font-mono)', color: 'var(--color-text-secondary)' }}>{name.length}/40</span>
          </div>
          {name.length > 0 && !nameValid && (
            <span style={{ fontSize: 11, color: '#C0304A', padding: '0 4px' }}>Il nome deve essere tra 3 e 40 caratteri.</span>
          )}
        </div>

        <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
          <span className="section-label">PRIVACY</span>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(2,minmax(0,1fr))', gap: 8 }}>
            <div
              onClick={() => setVisibility('private')}
              className={visibility === 'private' ? 'card-dark' : 'card'}
              style={{ padding: 15, display: 'flex', flexDirection: 'column', gap: 8, cursor: 'pointer' }}
            >
              <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 8 }}>
                <LockIcon color={visibility === 'private' ? 'var(--color-accent)' : 'var(--color-text-primary)'} />
                {visibility === 'private' ? <CheckCircleIcon /> : <span style={{ width: 18, height: 18, borderRadius: 99, border: '1.8px solid var(--color-border)', display: 'block' }} />}
              </div>
              <span style={{ fontFamily: 'var(--font-heading)', fontSize: 14 }}>Privata</span>
              <span style={{ fontSize: 11, lineHeight: 1.35, color: visibility === 'private' ? '#A9B4CC' : 'var(--color-text-secondary)' }}>Si entra solo con il codice invito</span>
            </div>
            <div
              onClick={() => setVisibility('public')}
              className={visibility === 'public' ? 'card-dark' : 'card'}
              style={{ padding: 15, display: 'flex', flexDirection: 'column', gap: 8, cursor: 'pointer' }}
            >
              <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 8 }}>
                <GlobeIcon color={visibility === 'public' ? 'var(--color-accent)' : 'var(--color-text-primary)'} />
                {visibility === 'public' ? <CheckCircleIcon /> : <span style={{ width: 18, height: 18, borderRadius: 99, border: '1.8px solid var(--color-border)', display: 'block' }} />}
              </div>
              <span style={{ fontFamily: 'var(--font-heading)', fontSize: 14 }}>Pubblica</span>
              <span style={{ fontSize: 11, lineHeight: 1.35, color: visibility === 'public' ? '#A9B4CC' : 'var(--color-text-secondary)' }}>Visibile a tutti in Esplora</span>
            </div>
          </div>
        </div>

        <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
          <span className="section-label">TURNO DI PARTENZA</span>
          {calendarLoading ? (
            <p style={{ color: 'var(--color-text-secondary)', fontSize: 13 }}>Caricamento calendario…</p>
          ) : calendarError || minRound === null || maxRound === null ? (
            <p style={{ color: '#C0304A', fontSize: 13 }}>{calendarError ?? 'Calendario non disponibile.'}</p>
          ) : (
            <div className="card" style={{ padding: '11px 14px', display: 'flex', alignItems: 'center', gap: 10, minHeight: 52 }}>
              <select
                value={effectiveStartRound ?? minRound}
                onChange={(e) => setStartRound(Number(e.target.value))}
                style={{ flex: 1, border: 'none', outline: 'none', background: 'transparent', fontFamily: 'var(--font-heading)', fontSize: 15, color: 'var(--color-text-primary)' }}
              >
                {Array.from({ length: maxRound - minRound + 1 }, (_, i) => minRound + i).map((r) => (
                  <option key={r} value={r}>
                    Giornata {r}{r === minRound ? ' (corrente)' : ''}
                  </option>
                ))}
              </select>
            </div>
          )}
          <span style={{ fontSize: 11, lineHeight: 1.35, color: 'var(--color-text-secondary)', padding: '0 4px' }}>
            La classifica della lega conta i punti solo dal turno scelto in avanti.
          </span>
        </div>

        {error && <p style={{ color: '#C0304A', fontSize: 13, textAlign: 'center' }}>{error}</p>}

        <div style={{ paddingTop: 4 }}>
          <button className="btn btn-primary" style={{ width: '100%' }} disabled={!canSubmit} onClick={handleSubmit}>
            {submitting ? 'Creazione in corso…' : 'Crea lega'}
          </button>
        </div>
      </div>
    </div>
  );
}
