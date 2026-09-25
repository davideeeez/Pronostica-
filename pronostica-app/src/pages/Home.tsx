import { useState } from 'react';
import { Link } from 'react-router-dom';
import { AppHeader } from '../components/AppHeader';
import { ChevronRightIcon, ShieldCrest } from '../components/icons';
import { useAuth } from '../contexts/AuthContext';
import { serieARounds, currentRoundNumber, lastPlayedRound, leagues, currentUser } from '../data/mock';

export function Home() {
  const { profile } = useAuth();
  const [selectedLeagueId, setSelectedLeagueId] = useState('gen');
  const currentRound = serieARounds.find((r) => r.number === currentRoundNumber)!;
  const done = currentRound.matches.filter((m) => m.myPrediction).length;
  const total = currentRound.matches.length;
  const remaining = total - done;
  const progressPct = Math.round((done / total) * 100);
  const hasLeagues = leagues.some((l) => !l.isGeneral);
  const selectedLeague = leagues.find((l) => l.id === selectedLeagueId) ?? leagues[0];
  const last = lastPlayedRound;

  return (
    <div className="page">
      <AppHeader selectedLeagueId={selectedLeagueId} onSelectLeague={setSelectedLeagueId} />

      <div className="page-scroll">
        <div className="card-dark" style={{ padding: '20px 20px 18px', display: 'flex', flexDirection: 'column', gap: 16 }}>
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 10 }}>
            <span style={{ font: '600 10.5px/1 var(--font-mono)', letterSpacing: '.12em' }}>
              SERIE A · GIORNATA {currentRound.number}
            </span>
            <span style={{ display: 'flex', alignItems: 'center', gap: 6, font: '600 10.5px/1 var(--font-mono)', color: 'var(--color-accent)' }}>
              <span style={{ width: 7, height: 7, borderRadius: '50%', background: 'var(--color-accent)', display: 'block' }} />
              APERTA
            </span>
          </div>

          <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
            <span style={{ fontSize: 12, color: '#A9B4CC' }}>Chiude tra</span>
            <span style={{ fontFamily: 'var(--font-heading)', fontSize: 52, lineHeight: 0.92, letterSpacing: '-.02em' }}>
              {currentRound.countdownLabel ?? '—'}
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

        {hasLeagues ? (
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
                <span className="stat-tile__value">{currentUser.leaguePoints.toLocaleString('it-IT')}</span>
              </div>
              <div className="stat-tile">
                <span className="stat-tile__label">POSIZIONE</span>
                <span className="stat-tile__value">{selectedLeague.position ?? '—'}</span>
              </div>
              <div className="stat-tile">
                <span className="stat-tile__label">VARIAZIONE</span>
                <span className="stat-tile__value">
                  {selectedLeague.delta === null ? '—' : (
                    <>{selectedLeague.delta >= 0 ? '▲' : '▼'} {Math.abs(selectedLeague.delta)}</>
                  )}
                </span>
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

        {last && last.fantasyDemo && (
          <Link to="/pronostici" state={{ tab: 'calendario' }} className="card" style={{ overflow: 'hidden', textDecoration: 'none', color: 'inherit' }}>
            <div style={{ padding: '14px 16px 12px', display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 10, borderBottom: '1px solid var(--color-border)' }}>
              <span className="section-label" style={{ padding: 0 }}>
                RIEPILOGO TURNO · GIORNATA {last.number}
              </span>
              <span style={{ fontSize: 12, color: 'var(--color-text-secondary)' }}>Vedi tutto</span>
            </div>
            <div style={{ padding: '15px 16px', display: 'flex', alignItems: 'flex-end', gap: 16 }}>
              <div style={{ display: 'flex', flexDirection: 'column', gap: 3 }}>
                <span style={{ fontSize: 11.5, color: 'var(--color-text-secondary)' }}>Il tuo punteggio</span>
                <span style={{ fontFamily: 'var(--font-heading)', fontSize: 34, color: 'var(--color-text-primary)' }}>
                  {last.fantasyDemo.points}
                  <span style={{ fontSize: 15, color: 'var(--color-text-secondary)' }}> pt</span>
                </span>
              </div>
              <div style={{ flex: 1, display: 'flex', flexDirection: 'column', gap: 6, paddingBottom: 4 }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: 11.5, color: 'var(--color-text-secondary)' }}>
                  <span>Media generale {last.fantasyDemo.average} pt</span>
                  <span style={{ color: 'var(--color-text-primary)', fontWeight: 600 }}>+{last.fantasyDemo.diff}</span>
                </div>
                <div className="progress-track">
                  <div className="progress-fill" style={{ width: `${last.fantasyDemo.progress}%` }} />
                </div>
              </div>
            </div>
          </Link>
        )}
      </div>
    </div>
  );
}
