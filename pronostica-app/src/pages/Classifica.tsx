import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { AppHeader } from '../components/AppHeader';
import { InfoCircleIcon, ShieldCrest } from '../components/icons';
import { useAuth } from '../contexts/AuthContext';
import { fetchLeaderboard, type LeaderboardRow } from '../lib/leaderboard';

const podiumColors: Record<number, { bg: string; ring: string }> = {
  1: { bg: '#E8B44A', ring: '#E8B44A' },
  2: { bg: 'rgba(192,200,214,.2)', ring: '#C0C8D6' },
  3: { bg: 'rgba(200,131,74,.22)', ring: '#C8834A' },
};

export function Classifica() {
  const { session } = useAuth();
  const [selectedLeagueId, setSelectedLeagueId] = useState('gen');
  const [rows, setRows] = useState<LeaderboardRow[] | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    fetchLeaderboard()
      .then(setRows)
      .catch((err) => setError(err instanceof Error ? err.message : 'Errore sconosciuto.'));
  }, []);

  const loading = rows === null && !error;
  const hasPoints = rows?.some((r) => r.totalPoints > 0) ?? false;
  const first = hasPoints ? rows?.find((r) => r.rank === 1) : undefined;
  const second = hasPoints ? rows?.find((r) => r.rank === 2) : undefined;
  const third = hasPoints ? rows?.find((r) => r.rank === 3) : undefined;
  const me = rows?.find((r) => r.userId === session?.user.id) ?? null;

  return (
    <div className="page">
      <AppHeader selectedLeagueId={selectedLeagueId} onSelectLeague={setSelectedLeagueId} />

      <div className="page-scroll" style={{ paddingBottom: 200 }}>
        <div className="card-dark" style={{ padding: '14px 16px 16px', display: 'flex', flexDirection: 'column', gap: 12 }}>
          <div style={{ display: 'flex', alignItems: 'flex-start', justifyContent: 'space-between', gap: 10 }}>
            <span style={{ font: '600 9.5px/1.5 var(--font-mono)', letterSpacing: '.12em' }}>
              CLASSIFICA GENERALE
              <br />
              {(rows?.length ?? 0).toLocaleString('it-IT')} UTENTI
            </span>
            <Link to="/menu/regolamento" style={{ display: 'flex', alignItems: 'center', gap: 5, flex: 'none' }}>
              <InfoCircleIcon size={15} />
              <span style={{ font: '600 9px/1 var(--font-mono)', letterSpacing: '.1em', color: 'var(--color-accent)' }}>REGOLAMENTO</span>
            </Link>
          </div>

          {loading ? (
            <p style={{ margin: 0, fontSize: 13, color: '#A9B4CC' }}>Caricamento…</p>
          ) : error ? (
            <p style={{ margin: 0, fontSize: 13, color: '#F28B9D' }}>{error}</p>
          ) : !rows || rows.length === 0 ? (
            <p style={{ margin: 0, fontSize: 13, lineHeight: 1.45, color: '#A9B4CC' }}>
              Nessun iscritto ancora. Sarai tra i primi a comparire qui.
            </p>
          ) : hasPoints && first && second && third ? (
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1.5fr 1fr', alignItems: 'end', gap: 7 }}>
              <PodiumSpot entry={second} colors={podiumColors[2]} size={42} nameColor="#fff" />
              <PodiumSpot entry={first} colors={podiumColors[1]} size={60} nameColor="#fff" crown />
              <PodiumSpot entry={third} colors={podiumColors[3]} size={42} nameColor="#fff" />
            </div>
          ) : (
            <p style={{ margin: 0, fontSize: 13, lineHeight: 1.45, color: '#A9B4CC' }}>
              Nessuno ha ancora punti: il podio comparirà dal primo risultato pronosticato. Per ora, ordine di iscrizione.
            </p>
          )}
        </div>

        {rows && rows.length > 0 && (
          <>
            <div
              style={{
                display: 'grid',
                gridTemplateColumns: hasPoints ? '40px minmax(0,1fr) 46px' : 'minmax(0,1fr) 46px',
                gap: 10,
                padding: '6px 14px 0',
                font: '600 9px/1 var(--font-mono)',
                letterSpacing: '.1em',
                color: 'var(--color-text-secondary)',
              }}
            >
              {hasPoints && <span>POS</span>}
              <span>UTENTE · ESATTI / ESITI</span>
              <span style={{ textAlign: 'right' }}>PUNTI</span>
            </div>

            <div className="card" style={{ padding: '4px 14px', display: 'flex', flexDirection: 'column' }}>
              {rows.map((row, i) => (
                <div
                  key={row.userId}
                  style={{
                    display: 'grid',
                    gridTemplateColumns: hasPoints ? '40px minmax(0,1fr) 46px' : 'minmax(0,1fr) 46px',
                    gap: 10,
                    alignItems: 'center',
                    padding: '11px 0',
                    borderTop: i === 0 ? 'none' : '1px solid var(--color-bg)',
                  }}
                >
                  {hasPoints && (
                    <span style={{ fontFamily: 'var(--font-heading)', fontSize: 14 }}>{row.rank}</span>
                  )}
                  <div style={{ display: 'flex', alignItems: 'center', gap: 9, minWidth: 0 }}>
                    <ShieldCrest size={26} pattern={row.crestPattern} />
                    <div style={{ display: 'flex', flexDirection: 'column', gap: 3, minWidth: 0 }}>
                      <span style={{ fontWeight: 600, fontSize: 13, color: 'var(--color-text-primary)', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                        {row.username}
                      </span>
                      <span style={{ font: '400 10px/1 var(--font-mono)', letterSpacing: '.06em', color: 'var(--color-text-secondary)' }}>
                        {row.exactResults} ESATTI · {row.correctOutcomes} ESITI
                      </span>
                    </div>
                  </div>
                  <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'flex-end', gap: 3 }}>
                    <span style={{ fontFamily: 'var(--font-heading)', fontSize: 14 }}>{row.totalPoints}</span>
                    <span style={{ font: '600 8px/1 var(--font-mono)', letterSpacing: '.1em', color: 'var(--color-text-secondary)' }}>PT</span>
                  </div>
                </div>
              ))}
            </div>
          </>
        )}
      </div>

      <div style={{ position: 'absolute', left: 0, right: 0, bottom: 79, background: 'var(--color-surface)', borderTop: '1px solid var(--color-border)', padding: '10px 18px 12px' }}>
        <div style={{ background: 'var(--color-accent)', borderRadius: 16, padding: '11px 14px', display: 'grid', gridTemplateColumns: 'auto minmax(0,1fr) auto', gap: 12, alignItems: 'center' }}>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
            <span style={{ font: '600 8px/1 var(--font-mono)', letterSpacing: '.1em', opacity: 0.65 }}>POS</span>
            <span style={{ fontFamily: 'var(--font-heading)', fontSize: 16 }}>
              {me && hasPoints ? me.rank.toLocaleString('it-IT') : '—'}
            </span>
          </div>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 3, minWidth: 0 }}>
            <span style={{ fontFamily: 'var(--font-heading)', fontSize: 13 }}>La tua posizione</span>
            <span style={{ font: '400 9.5px/1 var(--font-mono)', letterSpacing: '.04em' }}>
              {me ? `${me.exactResults} ESATTI · ${me.correctOutcomes} ESITI` : '— ESATTI · — ESITI'}
            </span>
          </div>
          <span style={{ fontFamily: 'var(--font-heading)', fontSize: 15 }}>
            {me?.totalPoints ?? 0} <span style={{ fontFamily: 'var(--font-mono)', fontSize: 8.5, fontWeight: 600, letterSpacing: '.1em', opacity: 0.65 }}>PT</span>
          </span>
        </div>
      </div>
    </div>
  );
}

function PodiumSpot({
  entry,
  colors,
  size,
  nameColor,
  crown,
}: {
  entry: LeaderboardRow;
  colors: { bg: string; ring: string };
  size: number;
  nameColor: string;
  crown?: boolean;
}) {
  return (
    <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 6 }}>
      <ShieldCrest size={size} pattern={entry.crestPattern} />
      <span style={{ fontFamily: 'var(--font-heading)', fontSize: crown ? 14.5 : 11.5, color: nameColor, textAlign: 'center', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap', maxWidth: '100%' }}>
        {entry.username}
      </span>
      <div
        style={{
          width: '100%',
          background: crown ? '#E8B44A' : colors.bg,
          borderRadius: crown ? '14px 14px 0 0' : '10px 10px 0 0',
          padding: crown ? '12px 6px 15px' : '9px 5px 11px',
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'center',
          gap: 4,
          minHeight: crown ? 130 : 76,
          justifyContent: 'flex-end',
        }}
      >
        <span style={{ fontFamily: 'var(--font-heading)', fontSize: crown ? 34 : 20, color: crown ? 'var(--color-text-primary)' : '#fff' }}>{entry.rank}</span>
        <span style={{ fontFamily: 'var(--font-heading)', fontSize: crown ? 19 : 14, color: crown ? 'var(--color-text-primary)' : '#fff' }}>{entry.totalPoints}</span>
        <span style={{ font: '600 8.5px/1 var(--font-mono)', letterSpacing: '.1em', color: crown ? 'var(--color-text-primary)' : '#A9B4CC', opacity: crown ? 0.75 : 1 }}>PT</span>
      </div>
    </div>
  );
}
