import { Link } from 'react-router-dom';
import { PageHeader } from '../../components/PageHeader';
import { PlusIcon, CodeIcon, SearchIcon, ShieldCrest, ChevronRightThinIcon } from '../../components/icons';
import { useAuth } from '../../contexts/AuthContext';
import { useMyLeagues } from '../../hooks/useMyLeagues';
import type { MyLeague } from '../../lib/leagues';

export function Leghe() {
  const { session } = useAuth();
  const { loading, error, leagues } = useMyLeagues(session?.user.id);
  const privateLeagues = leagues.filter((l) => l.visibility === 'private');
  const publicLeagues = leagues.filter((l) => l.visibility === 'public');

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
          <Link
            to="/menu/leghe/codice"
            className="card"
            style={{ padding: 14, display: 'flex', flexDirection: 'column', gap: 9, minHeight: 48, cursor: 'pointer' }}
          >
            <CodeIcon />
            <span style={{ fontWeight: 600, fontSize: 13 }}>Ho un codice</span>
          </Link>
          <Link to="/menu/leghe/esplora" className="card" style={{ padding: 14, display: 'flex', flexDirection: 'column', gap: 9, minHeight: 48, cursor: 'pointer' }}>
            <SearchIcon size={22} />
            <span style={{ fontWeight: 600, fontSize: 13 }}>Esplora leghe pubbliche</span>
          </Link>
        </div>

        {error && (
          <p style={{ color: '#C0304A', fontSize: 13, textAlign: 'center', padding: '8px 0' }}>{error}</p>
        )}

        {loading ? (
          <p style={{ color: 'var(--color-text-secondary)', fontSize: 13, textAlign: 'center', padding: '24px 0' }}>Caricamento…</p>
        ) : leagues.length === 0 && !error ? (
          <div className="card" style={{ padding: '16px', display: 'flex', flexDirection: 'column', gap: 4 }}>
            <span style={{ fontSize: 13.5, color: 'var(--color-text-secondary)' }}>Non fai ancora parte di nessuna lega.</span>
            <span style={{ fontSize: 13.5, color: 'var(--color-text-secondary)' }}>
              Creane una, usa un codice invito o esplora quelle pubbliche qui sopra.
            </span>
          </div>
        ) : (
          <>
            <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
              <span className="section-label">LEGHE PRIVATE</span>
              {privateLeagues.length > 0 ? (
                <div className="card" style={{ padding: '0 16px', display: 'flex', flexDirection: 'column' }}>
                  {privateLeagues.map((l, i) => (
                    <LeagueListItem key={l.id} league={l} first={i === 0} />
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
                    <LeagueListItem key={l.id} league={l} first={i === 0} />
                  ))}
                </div>
              </div>
            )}
          </>
        )}
      </div>
    </div>
  );
}

function LeagueListItem({ league, first }: { league: MyLeague; first: boolean }) {
  return (
    <Link to={`/menu/leghe/${league.id}`} style={{ display: 'flex', alignItems: 'center', gap: 11, padding: '14px 0', minHeight: 48, borderTop: first ? 'none' : '1px solid var(--color-bg)' }}>
      <ShieldCrest size={26} />
      <div style={{ flex: 1, minWidth: 0, display: 'flex', flexDirection: 'column', gap: 3 }}>
        <span style={{ fontWeight: 600, fontSize: 14, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{league.name}</span>
        <span style={{ font: '400 10px/1 var(--font-mono)', letterSpacing: '.05em', color: 'var(--color-text-secondary)' }}>
          {league.memberCount.toLocaleString('it-IT')} PARTECIPANTI
        </span>
      </div>
      <ChevronRightThinIcon />
    </Link>
  );
}
