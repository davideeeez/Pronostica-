import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { PlusIcon, CodeIcon, SearchIcon, ShieldCrest } from '../components/icons';
import { useAuth } from '../contexts/AuthContext';
import { useMyLeagues } from '../hooks/useMyLeagues';
import { getSelectedLeagueId } from '../lib/selectedLeague';
import { fetchLeagueLeaderboard, type LeaderboardRow } from '../lib/leagues';

export function Classifica() {
  const { session } = useAuth();
  const { loading: leaguesLoading, leagues } = useMyLeagues(session?.user.id);
  const [rows, setRows] = useState<LeaderboardRow[] | null>(null);
  const [error, setError] = useState<string | null>(null);

  const selectedId = getSelectedLeagueId();
  const selectedLeague = leagues.find((l) => l.id === selectedId) ?? leagues[0] ?? null;

  useEffect(() => {
    if (!selectedLeague) return;
    let cancelled = false;
    setRows(null);
    setError(null);
    fetchLeagueLeaderboard(selectedLeague.id)
      .then((r) => {
        if (!cancelled) setRows(r);
      })
      .catch((err) => {
        if (!cancelled) setError(err instanceof Error ? err.message : 'Errore sconosciuto.');
      });
    return () => {
      cancelled = true;
    };
  }, [selectedLeague]);

  if (leaguesLoading) {
    return <div className="page" />;
  }

  if (!selectedLeague) {
    return (
      <div className="page">
        <div style={{ flex: 'none', padding: '16px 18px 12px' }}>
          <span style={{ fontFamily: 'var(--font-heading)', fontSize: 20 }}>Classifica</span>
        </div>

        <div className="page-scroll" style={{ justifyContent: 'center', alignItems: 'center', textAlign: 'center' }}>
          <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 16, padding: '24px 8px' }}>
            <span style={{ fontFamily: 'var(--font-heading)', fontSize: 19 }}>Non fai ancora parte di nessuna lega</span>
            <p style={{ margin: 0, fontSize: 13.5, lineHeight: 1.5, color: 'var(--color-text-secondary)', maxWidth: 280 }}>
              La classifica generale è sospesa fino a gennaio. Per ora si gioca solo in leghe tra amici o pubbliche.
            </p>

            <div style={{ display: 'flex', flexDirection: 'column', gap: 9, width: '100%', maxWidth: 280, marginTop: 8 }}>
              <Link to="/menu/leghe/crea" className="btn btn-primary" style={{ gap: 10 }}>
                <PlusIcon color="#101A33" />
                Crea una lega
              </Link>
              <Link to="/menu/leghe" className="btn btn-outline" style={{ gap: 10 }}>
                <CodeIcon color="var(--color-text-primary)" />
                Ho un codice
              </Link>
              <Link to="/menu/leghe/esplora" className="btn btn-outline" style={{ gap: 10 }}>
                <SearchIcon size={18} />
                Esplora leghe pubbliche
              </Link>
            </div>
          </div>
        </div>
      </div>
    );
  }

  const hasPoints = (rows ?? []).some((r) => r.totalPoints > 0);

  return (
    <div className="page">
      <div style={{ flex: 'none', padding: '16px 18px 12px', display: 'flex', flexDirection: 'column', gap: 2 }}>
        <span style={{ fontFamily: 'var(--font-heading)', fontSize: 20 }}>Classifica</span>
        <span style={{ fontSize: 12, color: 'var(--color-text-secondary)' }}>{selectedLeague.name}</span>
      </div>

      <div className="page-scroll">
        {error && <p style={{ color: '#C0304A', fontSize: 13, textAlign: 'center' }}>{error}</p>}

        {rows === null && !error ? (
          <p style={{ color: 'var(--color-text-secondary)', fontSize: 13, textAlign: 'center', padding: '24px 0' }}>Caricamento…</p>
        ) : rows && rows.length === 0 ? (
          <p style={{ color: 'var(--color-text-secondary)', fontSize: 13, textAlign: 'center', padding: '24px 0' }}>Nessun membro ancora in classifica.</p>
        ) : rows ? (
          <div className="card" style={{ padding: '2px 16px', display: 'flex', flexDirection: 'column' }}>
            {rows.map((r, i) => (
              <div key={r.userId} style={{ display: 'flex', alignItems: 'center', gap: 10, padding: '12px 0', borderTop: i === 0 ? 'none' : '1px solid var(--color-bg)' }}>
                <ShieldCrest size={28} pattern={r.crestPattern} />
                <span style={{ flex: 1, minWidth: 0, fontWeight: 600, fontSize: 13.5, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                  {r.username}{r.userId === session?.user.id ? ' (tu)' : ''}
                </span>
                {hasPoints && (
                  <span style={{ flex: 'none', font: '600 10px/1 var(--font-mono)', letterSpacing: '.05em', color: 'var(--color-text-secondary)' }}>{r.totalPoints} PT</span>
                )}
                {hasPoints && (
                  <span style={{ flex: 'none', fontFamily: 'var(--font-heading)', fontSize: 13, minWidth: 22, textAlign: 'right' }}>{r.rank}</span>
                )}
              </div>
            ))}
          </div>
        ) : null}
      </div>
    </div>
  );
}
