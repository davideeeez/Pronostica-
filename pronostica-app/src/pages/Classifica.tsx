import { useState } from 'react';
import { Link } from 'react-router-dom';
import { AppHeader } from '../components/AppHeader';
import { InfoCircleIcon } from '../components/icons';
import { generalLeaderboardPodium, generalLeaderboardRest, yourGeneralPosition, leagues } from '../data/mock';

const podiumColors: Record<number, { bg: string; ring: string }> = {
  1: { bg: '#E8B44A', ring: '#E8B44A' },
  2: { bg: 'rgba(192,200,214,.2)', ring: '#C0C8D6' },
  3: { bg: 'rgba(200,131,74,.22)', ring: '#C8834A' },
};

export function Classifica() {
  const [selectedLeagueId, setSelectedLeagueId] = useState('gen');
  const first = generalLeaderboardPodium.find((p) => p.position === 1)!;
  const second = generalLeaderboardPodium.find((p) => p.position === 2)!;
  const third = generalLeaderboardPodium.find((p) => p.position === 3)!;

  return (
    <div className="page">
      <AppHeader selectedLeagueId={selectedLeagueId} onSelectLeague={setSelectedLeagueId} />

      <div className="page-scroll" style={{ paddingBottom: 200 }}>
        <div className="card-dark" style={{ padding: '14px 16px 16px', display: 'flex', flexDirection: 'column', gap: 12 }}>
          <div style={{ display: 'flex', alignItems: 'flex-start', justifyContent: 'space-between', gap: 10 }}>
            <span style={{ font: '600 9.5px/1.5 var(--font-mono)', letterSpacing: '.12em' }}>
              DOPO LA GIORNATA 12
              <br />
              {leagues.find((l) => l.isGeneral)!.members.toLocaleString('it-IT')} UTENTI
            </span>
            <Link to="/menu/regolamento" style={{ display: 'flex', alignItems: 'center', gap: 5, flex: 'none' }}>
              <InfoCircleIcon size={15} />
              <span style={{ font: '600 9px/1 var(--font-mono)', letterSpacing: '.1em', color: 'var(--color-accent)' }}>REGOLAMENTO</span>
            </Link>
          </div>

          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1.5fr 1fr', alignItems: 'end', gap: 7 }}>
            <PodiumSpot entry={second} colors={podiumColors[2]} size={42} nameColor="#fff" />
            <PodiumSpot entry={first} colors={podiumColors[1]} size={60} nameColor="#fff" crown />
            <PodiumSpot entry={third} colors={podiumColors[3]} size={42} nameColor="#fff" />
          </div>
        </div>

        <div style={{ display: 'grid', gridTemplateColumns: '40px minmax(0,1fr) 46px', gap: 10, padding: '6px 14px 0', font: '600 9px/1 var(--font-mono)', letterSpacing: '.1em', color: 'var(--color-text-secondary)' }}>
          <span>POS</span>
          <span>UTENTE · ESATTI / ESITI</span>
          <span style={{ textAlign: 'right' }}>PUNTI</span>
        </div>

        <div className="card" style={{ padding: '4px 14px', display: 'flex', flexDirection: 'column' }}>
          {generalLeaderboardRest.map((row, i) => (
            <div
              key={row.position}
              style={{
                display: 'grid',
                gridTemplateColumns: '40px minmax(0,1fr) 46px',
                gap: 10,
                alignItems: 'center',
                padding: '11px 0',
                borderTop: i === 0 ? 'none' : '1px solid var(--color-bg)',
              }}
            >
              <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'flex-start', gap: 3 }}>
                <span style={{ fontFamily: 'var(--font-heading)', fontSize: 14 }}>{row.position}</span>
                <span style={{ font: '600 9.5px/1 var(--font-mono)', color: row.delta > 0 ? '#1B7A46' : row.delta < 0 ? '#C0304A' : 'var(--color-text-secondary)', whiteSpace: 'nowrap' }}>
                  {row.delta > 0 ? '▲' : row.delta < 0 ? '▼' : '—'} {Math.abs(row.delta)}
                </span>
              </div>
              <div style={{ display: 'flex', flexDirection: 'column', gap: 3, minWidth: 0 }}>
                <span style={{ fontWeight: 600, fontSize: 13, color: 'var(--color-text-primary)', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{row.name}</span>
                <span style={{ font: '400 10px/1 var(--font-mono)', letterSpacing: '.06em', color: 'var(--color-text-secondary)' }}>
                  {row.exact} ESATTI · {row.outcomes} ESITI
                </span>
              </div>
              <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'flex-end', gap: 3 }}>
                <span style={{ fontFamily: 'var(--font-heading)', fontSize: 14 }}>{row.points}</span>
                <span style={{ font: '600 8px/1 var(--font-mono)', letterSpacing: '.1em', color: 'var(--color-text-secondary)' }}>PT</span>
              </div>
            </div>
          ))}
        </div>
      </div>

      <div style={{ position: 'absolute', left: 0, right: 0, bottom: 79, background: 'var(--color-surface)', borderTop: '1px solid var(--color-border)', padding: '10px 18px 12px' }}>
        <div style={{ background: 'var(--color-accent)', borderRadius: 16, padding: '11px 14px', display: 'grid', gridTemplateColumns: 'auto minmax(0,1fr) auto', gap: 12, alignItems: 'center' }}>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
            <span style={{ font: '600 8px/1 var(--font-mono)', letterSpacing: '.1em', opacity: 0.65 }}>POS</span>
            <span style={{ fontFamily: 'var(--font-heading)', fontSize: 16 }}>
              {yourGeneralPosition.position !== null ? yourGeneralPosition.position.toLocaleString('it-IT') : '—'}
            </span>
            {yourGeneralPosition.delta !== null && (
              <span style={{ font: '600 9.5px/1 var(--font-mono)', color: '#0E4527' }}>▲ {yourGeneralPosition.delta}</span>
            )}
          </div>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 3, minWidth: 0 }}>
            <span style={{ fontFamily: 'var(--font-heading)', fontSize: 13 }}>La tua posizione</span>
            <span style={{ font: '400 9.5px/1 var(--font-mono)', letterSpacing: '.04em' }}>
              {yourGeneralPosition.exact} ESATTI · {yourGeneralPosition.outcomes} ESITI
            </span>
          </div>
          <span style={{ fontFamily: 'var(--font-heading)', fontSize: 15 }}>
            {yourGeneralPosition.points} <span style={{ fontFamily: 'var(--font-mono)', fontSize: 8.5, fontWeight: 600, letterSpacing: '.1em', opacity: 0.65 }}>PT</span>
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
  entry: { position: number; name: string; points: number; initials: string };
  colors: { bg: string; ring: string };
  size: number;
  nameColor: string;
  crown?: boolean;
}) {
  return (
    <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 6 }}>
      <div
        style={{
          width: size,
          height: size,
          borderRadius: size / 3.2,
          background: crown ? 'var(--color-accent)' : colors.bg,
          border: `${crown ? 2.5 : 1.5}px solid ${colors.ring}`,
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          fontFamily: 'var(--font-heading)',
          fontSize: size / 3,
          color: crown ? 'var(--color-text-primary)' : '#fff',
        }}
      >
        {entry.initials}
      </div>
      <span style={{ fontFamily: 'var(--font-heading)', fontSize: crown ? 14.5 : 11.5, color: nameColor, textAlign: 'center' }}>{entry.name}</span>
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
        <span style={{ fontFamily: 'var(--font-heading)', fontSize: crown ? 34 : 20, color: crown ? 'var(--color-text-primary)' : '#fff' }}>{entry.position}</span>
        <span style={{ fontFamily: 'var(--font-heading)', fontSize: crown ? 19 : 14, color: crown ? 'var(--color-text-primary)' : '#fff' }}>{entry.points}</span>
        <span style={{ font: '600 8.5px/1 var(--font-mono)', letterSpacing: '.1em', color: crown ? 'var(--color-text-primary)' : '#A9B4CC', opacity: crown ? 0.75 : 1 }}>PT</span>
      </div>
    </div>
  );
}
