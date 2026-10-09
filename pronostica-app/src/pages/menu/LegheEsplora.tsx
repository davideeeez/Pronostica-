import { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { PageHeader } from '../../components/PageHeader';
import { SearchIcon, ShieldCrest } from '../../components/icons';
import { useAuth } from '../../contexts/AuthContext';
import { useMyLeagues } from '../../hooks/useMyLeagues';
import { fetchExploreLeagues, joinPublicLeague, type ExploreLeague } from '../../lib/leagues';

export function LegheEsplora() {
  const navigate = useNavigate();
  const { session } = useAuth();
  const { leagues: myLeagues } = useMyLeagues(session?.user.id);
  const myLeagueIds = new Set(myLeagues.map((l) => l.id));

  const [query, setQuery] = useState('');
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [leagues, setLeagues] = useState<ExploreLeague[]>([]);
  const [joiningId, setJoiningId] = useState<string | null>(null);
  const [joinError, setJoinError] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;
    fetchExploreLeagues()
      .then((l) => {
        if (!cancelled) setLeagues(l);
      })
      .catch((err) => {
        if (!cancelled) setError(err instanceof Error ? err.message : 'Errore sconosciuto.');
      })
      .finally(() => {
        if (!cancelled) setLoading(false);
      });
    return () => {
      cancelled = true;
    };
  }, []);

  const filtered = leagues.filter((l) => l.name.toLowerCase().includes(query.toLowerCase()));

  async function handleJoin(league: ExploreLeague) {
    setJoiningId(league.id);
    setJoinError(null);
    try {
      const outcome = await joinPublicLeague(league.id);
      if (outcome === 'ok' || outcome === 'already_member') {
        navigate(`/menu/leghe/${league.id}`);
        return;
      }
      setJoinError('Non è stato possibile entrare in questa lega. Riprova.');
    } catch (err) {
      setJoinError(err instanceof Error ? err.message : 'Errore sconosciuto.');
    } finally {
      setJoiningId(null);
    }
  }

  return (
    <div className="page">
      <PageHeader title="Esplora leghe" />

      <div className="page-scroll">
        <div className="card" style={{ borderWidth: 1.5, borderColor: 'var(--color-primary)', padding: '0 14px', display: 'flex', alignItems: 'center', gap: 10, minHeight: 52 }}>
          <SearchIcon />
          <input
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            placeholder="Cerca una lega pubblica"
            style={{ flex: 1, minWidth: 0, border: 'none', outline: 'none', background: 'transparent', fontSize: 14, color: 'var(--color-text-primary)' }}
          />
        </div>

        {error && <p style={{ color: '#C0304A', fontSize: 13, textAlign: 'center' }}>{error}</p>}
        {joinError && <p style={{ color: '#C0304A', fontSize: 13, textAlign: 'center' }}>{joinError}</p>}

        {loading ? (
          <p style={{ color: 'var(--color-text-secondary)', fontSize: 13, textAlign: 'center', padding: '24px 0' }}>Caricamento…</p>
        ) : (
          <>
            <div style={{ display: 'flex', alignItems: 'baseline', gap: 8, padding: '0 4px' }}>
              <span className="section-label" style={{ padding: 0 }}>{filtered.length} LEGHE APERTE</span>
              <span style={{ flex: 1, height: 1, background: 'var(--color-border)' }} />
            </div>

            <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
              {filtered.map((l) => {
                const alreadyMember = myLeagueIds.has(l.id);
                return (
                  <div key={l.id} className="card" style={{ padding: '15px 16px', display: 'flex', alignItems: 'center', gap: 12 }}>
                    <ShieldCrest size={26} />
                    <div style={{ flex: 1, minWidth: 0, display: 'flex', flexDirection: 'column', gap: 4 }}>
                      <span style={{ fontWeight: 600, fontSize: 14, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{l.name}</span>
                      <span style={{ fontSize: 11.5, lineHeight: 1.35, color: 'var(--color-text-secondary)' }}>di {l.ownerUsername}</span>
                      <span style={{ font: '400 10px/1 var(--font-mono)', letterSpacing: '.05em', color: 'var(--color-text-secondary)' }}>
                        {l.memberCount.toLocaleString('it-IT')} PARTECIPANTI · CONTA DAL TURNO {l.startRound}
                      </span>
                    </div>
                    {alreadyMember ? (
                      <span className="badge-neutral" style={{ flex: 'none', padding: '14px 13px', minHeight: 44, display: 'flex', alignItems: 'center' }}>
                        Già dentro
                      </span>
                    ) : (
                      <span
                        className="badge-accent"
                        style={{ flex: 'none', fontFamily: 'var(--font-body)', fontWeight: 600, padding: '14px 13px', minHeight: 44, display: 'flex', alignItems: 'center', cursor: 'pointer', opacity: joiningId === l.id ? 0.6 : 1 }}
                        onClick={() => joiningId === null && handleJoin(l)}
                      >
                        {joiningId === l.id ? '…' : 'Entra'}
                      </span>
                    )}
                  </div>
                );
              })}
              {filtered.length === 0 && (
                <p style={{ color: 'var(--color-text-secondary)', fontSize: 13, textAlign: 'center', padding: '24px 0' }}>Nessuna lega trovata.</p>
              )}
            </div>
          </>
        )}
      </div>
    </div>
  );
}
