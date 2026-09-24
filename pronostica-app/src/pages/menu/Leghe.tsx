import { Link } from 'react-router-dom';
import { PageHeader } from '../../components/PageHeader';
import { PlusIcon, CodeIcon, SearchIcon, ShieldCrest, ChevronRightThinIcon } from '../../components/icons';
import { leagues } from '../../data/mock';

export function Leghe() {
  const general = leagues.find((l) => l.isGeneral)!;
  const privateLeagues = leagues.filter((l) => l.isPrivate);
  const publicLeagues = leagues.filter((l) => !l.isPrivate && !l.isGeneral);

  return (
    <div className="page">
      <PageHeader title="Leghe" />

      <div className="page-scroll">
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(2,minmax(0,1fr))', gap: 8 }}>
          <Link
            to="/menu/leghe/crea"
            className="card-dark"
            style={{ gridColumn: '1 / -1', padding: '15px 16px', display: 'flex', alignItems: 'center', gap: 11, minHeight: 48, cursor: 'pointer' }}
          >
            <PlusIcon />
            <span style={{ flex: 1, minWidth: 0, fontFamily: 'var(--font-heading)', fontSize: 14.5 }}>Crea lega</span>
            <ChevronRightThinIcon color="var(--color-accent)" />
          </Link>
          <div className="card" style={{ padding: 14, display: 'flex', flexDirection: 'column', gap: 9, minHeight: 48, cursor: 'pointer' }}>
            <CodeIcon />
            <span style={{ fontWeight: 600, fontSize: 13 }}>Ho un codice</span>
          </div>
          <Link to="/menu/leghe/esplora" className="card" style={{ padding: 14, display: 'flex', flexDirection: 'column', gap: 9, minHeight: 48, cursor: 'pointer' }}>
            <SearchIcon size={22} />
            <span style={{ fontWeight: 600, fontSize: 13 }}>Esplora leghe pubbliche</span>
          </Link>
        </div>

        <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
          <span className="section-label">SEMPRE ATTIVA</span>
          <LeagueRow id={general.id} name={general.name} members={general.members} points={general.points} position={general.position} tag="GENERALE" />
        </div>

        <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
          <span className="section-label">LEGHE PRIVATE</span>
          {privateLeagues.length > 0 ? (
            <div className="card" style={{ padding: '0 16px', display: 'flex', flexDirection: 'column' }}>
              {privateLeagues.map((l, i) => (
                <LeagueListItem key={l.id} id={l.id} name={l.name} members={l.members} points={l.points} position={l.position} first={i === 0} />
              ))}
            </div>
          ) : (
            <div className="card" style={{ padding: '16px', display: 'flex', flexDirection: 'column', gap: 4 }}>
              <span style={{ fontSize: 13.5, color: 'var(--color-text-secondary)' }}>Non hai ancora nessuna lega privata.</span>
              <Link to="/menu/leghe/crea" style={{ fontWeight: 600, fontSize: 13.5 }}>Creane una tu, o unisciti con un codice invito</Link>
            </div>
          )}
        </div>

        {publicLeagues.length > 0 && (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
            <span className="section-label">LEGHE PUBBLICHE</span>
            <div className="card" style={{ padding: '0 16px', display: 'flex', flexDirection: 'column' }}>
              {publicLeagues.map((l, i) => (
                <LeagueListItem key={l.id} id={l.id} name={l.name} members={l.members} points={l.points} position={l.position} first={i === 0} />
              ))}
            </div>
          </div>
        )}
      </div>
    </div>
  );
}

function LeagueRow({ name, points, position, tag }: { id: string; name: string; members: number; points: number | null; position: number | null; tag: string }) {
  return (
    <Link to="/classifica" className="card" style={{ padding: '14px 16px', display: 'flex', alignItems: 'center', gap: 11, minHeight: 48 }}>
      <ShieldCrest size={26} />
      <div style={{ flex: 1, minWidth: 0, display: 'flex', flexDirection: 'column', gap: 4 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 7 }}>
          <span style={{ fontWeight: 600, fontSize: 14 }}>{name}</span>
          <span className="badge-accent" style={{ fontSize: 8, padding: '4px 7px', borderRadius: 99 }}>{tag}</span>
        </div>
        <span style={{ font: '400 10px/1 var(--font-mono)', letterSpacing: '.05em', color: 'var(--color-text-secondary)' }}>{points ?? 0} PT</span>
      </div>
      <div style={{ flex: 'none', display: 'flex', flexDirection: 'column', alignItems: 'flex-end', gap: 3 }}>
        <span style={{ fontFamily: 'var(--font-heading)', fontSize: 15 }}>{position !== null ? position.toLocaleString('it-IT') : '—'}</span>
        <span style={{ font: '600 8px/1 var(--font-mono)', letterSpacing: '.1em', color: 'var(--color-text-secondary)' }}>POS</span>
      </div>
    </Link>
  );
}

function LeagueListItem({ id, name, members, points, position, first }: { id: string; name: string; members: number; points: number | null; position: number | null; first: boolean }) {
  return (
    <Link to={`/menu/leghe/${id}`} style={{ display: 'flex', alignItems: 'center', gap: 11, padding: '14px 0', minHeight: 48, borderTop: first ? 'none' : '1px solid var(--color-bg)' }}>
      <ShieldCrest size={26} />
      <div style={{ flex: 1, minWidth: 0, display: 'flex', flexDirection: 'column', gap: 3 }}>
        <span style={{ fontWeight: 600, fontSize: 14, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{name}</span>
        <span style={{ font: '400 10px/1 var(--font-mono)', letterSpacing: '.05em', color: 'var(--color-text-secondary)' }}>
          {members.toLocaleString('it-IT')} PARTECIPANTI · {points ?? 0} PT
        </span>
      </div>
      <div style={{ flex: 'none', display: 'flex', flexDirection: 'column', alignItems: 'flex-end', gap: 3 }}>
        <span style={{ fontFamily: 'var(--font-heading)', fontSize: 15 }}>{position ?? '—'}</span>
        <span style={{ font: '600 8px/1 var(--font-mono)', letterSpacing: '.1em', color: 'var(--color-text-secondary)' }}>POS</span>
      </div>
      <ChevronRightThinIcon />
    </Link>
  );
}
