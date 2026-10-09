import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { AppHeader } from '../components/AppHeader';
import { ChevronRightIcon, ShieldCrest } from '../components/icons';
import { useAuth } from '../contexts/AuthContext';
import { useCalendar } from '../hooks/useCalendar';
import { useRoundLock } from '../hooks/useRoundLock';
import { useMyLeagues } from '../hooks/useMyLeagues';
import { fetchMyPredictions } from '../lib/predictions';
import { fetchLeagueLeaderboard, type LeaderboardRow } from '../lib/leagues';

export function Home() {
  const { profile, session } = useAuth();
  const [selectedLeagueId, setSelectedLeagueId] = useState<string | null>(null);
  const [done, setDone] = useState(0);
  const [myRow, setMyRow] = useState<LeaderboardRow | null>(null);
  const [leagueStatsError, setLeagueStatsError] = useState<string | null>(null);
  const { loading, error, currentRound } = useCalendar();
  const { leagues: myLeagues, loading: leaguesLoading } = useMyLeagues(session?.user.id);
  const { countdownLabel } = useRoundLock(currentRound?.locksAt ?? null);
  const total = currentRound?.matches.length ?? 0;
  const remaining = total - done;
  const progressPct = total > 0 ? Math.round((done / total) * 100) : 0;
  const hasLeagues = myLeagues.length > 0;

  useEffect(() => {
    if (!session) return;
    fetchMyPredictions(session.user.id).then((map) => {
      if (!currentRound) return;
      setDone(currentRound.matches.filter((m) => map[m.matchId]).length);
    });
  }, [session, currentRound]);

  useEffect(() => {
    if (!selectedLeagueId || !session) {
      setMyRow(null);
      return;
    }
    let cancelled = false;
    setLeagueStatsError(null);
    fetchLeagueLeaderboard(selectedLeagueId)
      .then((rows) => {
        if (cancelled) return;
        setMyRow(rows.find((r) => r.userId === session.user.id) ?? null);
      })
      .catch((err) => {
        if (!cancelled) setLeagueStatsError(err instanceof Error ? err.message : 'Errore sconosciuto.');
      });
    return () => {
      cancelled = true;
    };
  }, [selectedLeagueId, session]);

  if (loading) return <div className="page" />;
  if (error || !currentRound) {
    return (
      <div className="page" style={{ justifyContent: 'center', padding: '0 28px' }}>
        <p style={{ margin: 0, fontSize: 13.5, textAlign: 'center', color: 'var(--color-text-secondary)' }}>
          {error ?? 'Nessuna giornata disponibile al momento.'}
        </p>
      </div>
    );
  }

  return (
    <div className="page">
      <AppHeader onSelectionChange={setSelectedLeagueId} />

      <div className="page-scroll">
        <div className="card-dark" style={{ padding: '20px 20px 18px', display: 'flex', flexDirection: 'column', gap: 16 }}>
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 10 }}>
            <span style={{ font: '600 10.5px/1 var(--font-mono)', letterSpacing: '.12em' }}>
              SERIE A · GIORNATA {currentRound.roundNumber}
            </span>
            <span style={{ display: 'flex', alignItems: 'center', gap: 6, font: '600 10.5px/1 var(--font-mono)', color: 'var(--color-accent)' }}>
              <span style={{ width: 7, height: 7, borderRadius: '50%', background: 'var(--color-accent)', display: 'block' }} />
              APERTA
            </span>
          </div>

          <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
            <span style={{ fontSize: 12, color: '#A9B4CC' }}>Chiude tra</span>
            <span style={{ fontFamily: 'var(--font-heading)', fontSize: 52, lineHeight: 0.92, letterSpacing: '-.02em' }}>
              {countdownLabel ?? '—'}
            </span>
            <span style={{ fontSize: 12.5, lineHeight: 1.35, color: '#A9B4CC' }}>
              Hai {remaining} partite ancora da pronosticare
            </span>
          </div>

          <Link to="/pronostici" className="btn btn-primary">
            Pronostica!
            <ChevronRightIcon color="#101A33" />
          </Link>

          <div style={{ display: 'flex', alignItems: 'center', gap: 9 }}>
            <div className="progress-track" style={{ background: 'rgba(255,255,255,.16)' }}>
              <div className="progress-fill" style={{ width: `${progressPct}%` }} />
            </div>
            <span style={{ font: '600 10px/1 var(--font-mono)', color: '#A9B4CC', whiteSpace: 'nowrap' }}>
              {done}/{total} FATTE
            </span>
          </div>
        </div>

        {leaguesLoading ? null : hasLeagues ? (
          <Link to="/menu/profilo" className="card" style={{ padding: '15px 16px 16px', display: 'flex', flexDirection: 'column', gap: 13, textDecoration: 'none' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
              <ShieldCrest size={38} pattern={profile?.crest_pattern ?? 'star'} />
              <div style={{ flex: 1, minWidth: 0, display: 'flex', flexDirection: 'column', gap: 3 }}>
                <span style={{ fontFamily: 'var(--font-heading)', fontSize: 17, color: 'var(--color-text-primary)', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                  {profile?.username}
                </span>
                <span style={{ font: '600 9.5px/1 var(--font-mono)', letterSpacing: '.1em', color: 'var(--color-text-secondary)' }}>
                  VEDI PROFILO
                </span>
              </div>
              <ChevronRightIcon />
            </div>

            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3,minmax(0,1fr))', gap: 8 }}>
              <div className="stat-tile">
                <span className="stat-tile__label">PUNTI</span>
                <span className="stat-tile__value">
                  {leagueStatsError ? '—' : (myRow?.totalPoints ?? 0).toLocaleString('it-IT')}
                </span>
              </div>
              <div className="stat-tile">
                <span className="stat-tile__label">POSIZIONE</span>
                <span className="stat-tile__value">{leagueStatsError ? '—' : myRow?.rank ?? '—'}</span>
              </div>
              <div className="stat-tile">
                <span className="stat-tile__label">VARIAZIONE</span>
                {/* Richiede uno storico delle posizioni turno-per-turno non ancora tracciato: per ora nessun dato finto. */}
                <span className="stat-tile__value">—</span>
              </div>
            </div>

            <div style={{ borderTop: '1px solid var(--color-bg)', paddingTop: 13, display: 'flex', flexDirection: 'column', gap: 10 }}>
              <span style={{ font: '600 9px/1 var(--font-mono)', letterSpacing: '.12em', color: '#9AA6C0' }}>TRAGUARDI</span>
              <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4,minmax(0,1fr))', gap: 10 }}>
                {[0, 1, 2, 3].map((i) => (
                  <div key={i} style={{ aspectRatio: '1', border: '1px dashed #B9C4DC', borderRadius: '50%', background: 'repeating-linear-gradient(135deg, var(--color-bg) 0 5px, #F7F9FD 5px 10px)' }} />
                ))}
              </div>
              <span style={{ font: '400 10px/1.4 var(--font-mono)', color: '#9AA6C0' }}>spazio riservato · badge e traguardi in arrivo</span>
            </div>
          </Link>
        ) : (
          <div className="card" style={{ padding: 18, display: 'flex', flexDirection: 'column', gap: 12 }}>
            <span style={{ fontFamily: 'var(--font-heading)', fontSize: 18, lineHeight: 1.2 }}>Crea o unisciti a una lega</span>
            <p style={{ margin: 0, fontSize: 13.5, lineHeight: 1.45, color: 'var(--color-text-secondary)' }}>
              Sfida i tuoi amici sulla stessa giornata. La posta resta tra voi: l'app non tocca i soldi.
            </p>
            <div style={{ display: 'flex', gap: 9 }}>
              <Link to="/menu/leghe/crea" className="btn btn-primary" style={{ flex: 1, fontSize: 13.5, padding: '13px 14px', minHeight: 46 }}>
                Crea lega
              </Link>
              <Link to="/menu/leghe" className="btn btn-outline" style={{ flex: 1, fontSize: 13.5, padding: '13px 14px', minHeight: 46 }}>
                Ho un codice
              </Link>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
