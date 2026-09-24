import { Link, useParams } from 'react-router-dom';
import { PageHeader } from '../../components/PageHeader';
import { ShieldCrest, ClassificaIcon, ChevronRightThinIcon, ShareIcon, FlagIcon } from '../../components/icons';
import { leagues, leagueMembers } from '../../data/mock';

export function LegaDettaglio() {
  const { id } = useParams<{ id: string }>();
  const league = leagues.find((l) => l.id === id && !l.isGeneral);
  const members = leagueMembers[id ?? ''] ?? [];

  if (!league) {
    return (
      <div className="page">
        <PageHeader title="Lega" />
        <div className="page-scroll">
          <p style={{ color: 'var(--color-text-secondary)', fontSize: 14 }}>Lega non trovata.</p>
          <Link to="/menu/leghe" style={{ fontWeight: 600, fontSize: 14 }}>Torna alle leghe</Link>
        </div>
      </div>
    );
  }

  return (
    <div className="page">
      <PageHeader title={league.name} />

      <div className="page-scroll">
        <div className="card-dark" style={{ padding: '18px 16px', display: 'flex', flexDirection: 'column', gap: 12 }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
            <ShieldCrest size={42} base="#1B2745" />
            <div style={{ flex: 1, minWidth: 0, display: 'flex', flexDirection: 'column', gap: 6 }}>
              <span style={{ fontFamily: 'var(--font-heading)', fontSize: 20 }}>{league.name}</span>
              <div style={{ display: 'flex', alignItems: 'center', gap: 7 }}>
                <span className="badge-accent" style={{ borderRadius: 99, fontSize: 8, padding: '4px 7px' }}>
                  {league.isPrivate ? 'PRIVATA' : 'PUBBLICA'}
                </span>
                <span style={{ font: '400 10px/1 var(--font-mono)', letterSpacing: '.05em', color: '#A9B4CC' }}>
                  {league.members.toLocaleString('it-IT')} PARTECIPANTI
                </span>
              </div>
            </div>
          </div>
          <div style={{ display: 'flex', gap: 8, paddingTop: 2, borderTop: '1px solid rgba(255,255,255,.12)' }}>
            <div style={{ flex: 1, display: 'flex', flexDirection: 'column', gap: 4, paddingTop: 10 }}>
              <span style={{ font: '600 8.5px/1 var(--font-mono)', letterSpacing: '.1em', color: '#A9B4CC' }}>TUA POSIZIONE</span>
              <span style={{ fontFamily: 'var(--font-heading)', fontSize: 22, color: 'var(--color-accent)' }}>{league.position}</span>
            </div>
            <div style={{ flex: 1, display: 'flex', flexDirection: 'column', gap: 4, paddingTop: 10 }}>
              <span style={{ font: '600 8.5px/1 var(--font-mono)', letterSpacing: '.1em', color: '#A9B4CC' }}>PUNTI</span>
              <span style={{ fontFamily: 'var(--font-heading)', fontSize: 22 }}>{league.points}</span>
            </div>
          </div>
        </div>

        <Link to="/classifica" className="card" style={{ padding: '15px 16px', display: 'flex', alignItems: 'center', gap: 11, minHeight: 48 }}>
          <ClassificaIcon color="var(--color-text-primary)" />
          <span style={{ flex: 1, minWidth: 0, fontWeight: 600, fontSize: 14 }}>Vedi classifica della lega</span>
          <ChevronRightThinIcon />
        </Link>

        {league.isPrivate && league.code && (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
            <span className="section-label">CODICE INVITO</span>
            <div className="card" style={{ padding: '15px 16px', display: 'flex', alignItems: 'center', gap: 11 }}>
              <span style={{ flex: 1, minWidth: 0, fontFamily: 'var(--font-heading)', fontSize: 20, letterSpacing: '.1em' }}>{league.code}</span>
              <div style={{ flex: 'none', display: 'flex', alignItems: 'center', gap: 7, background: 'var(--color-accent)', borderRadius: 12, padding: '11px 13px', minHeight: 44, cursor: 'pointer' }}>
                <ShareIcon />
                <span style={{ font: '600 12px/1 var(--font-body)' }}>Condividi</span>
              </div>
            </div>
          </div>
        )}

        {members.length > 0 && (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
            <div style={{ display: 'flex', alignItems: 'baseline', gap: 8, padding: '0 4px' }}>
              <span className="section-label" style={{ padding: 0 }}>MEMBRI</span>
              <span style={{ flex: 1, height: 1, background: 'var(--color-border)' }} />
              <span className="section-label" style={{ padding: 0 }}>{league.members.toLocaleString('it-IT')}</span>
            </div>
            <div className="card" style={{ padding: '2px 16px', display: 'flex', flexDirection: 'column' }}>
              {members.map((m, i) => (
                <div
                  key={m.position}
                  style={
                    m.isYou
                      ? { display: 'flex', alignItems: 'center', gap: 10, padding: '8px 0 12px', borderTop: i === 0 ? 'none' : '1px solid var(--color-bg)' }
                      : { display: 'flex', alignItems: 'center', gap: 10, padding: '12px 0', borderTop: i === 0 ? 'none' : '1px solid var(--color-bg)' }
                  }
                >
                  <div
                    style={
                      m.isYou
                        ? { flex: 1, background: 'var(--color-accent)', borderRadius: 14, padding: '11px 13px', display: 'flex', alignItems: 'center', gap: 10 }
                        : { flex: 1, display: 'flex', alignItems: 'center', gap: 10 }
                    }
                  >
                    <div style={{ flex: 'none', width: 34, height: 34, borderRadius: 11, background: m.isYou ? 'rgba(16,26,51,.1)' : 'var(--color-bg)', display: 'flex', alignItems: 'center', justifyContent: 'center', fontFamily: 'var(--font-heading)', fontSize: 12 }}>
                      {m.initials}
                    </div>
                    <span style={{ flex: 1, minWidth: 0, fontWeight: 600, fontSize: 13.5, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{m.name}</span>
                    {m.isCreator && <span className="badge-neutral">CREATORE</span>}
                    <span style={{ flex: 'none', font: '600 10px/1 var(--font-mono)', letterSpacing: '.05em', color: m.isYou ? 'var(--color-text-primary)' : 'var(--color-text-secondary)' }}>{m.points} PT</span>
                    <span style={{ flex: 'none', fontFamily: 'var(--font-heading)', fontSize: 13, minWidth: 22, textAlign: 'right' }}>{m.position}</span>
                  </div>
                </div>
              ))}
            </div>
          </div>
        )}

        {!league.isPrivate && (
          <div className="card" style={{ padding: '15px 16px', display: 'flex', alignItems: 'center', gap: 11, minHeight: 48, cursor: 'pointer' }}>
            <FlagIcon />
            <div style={{ flex: 1, minWidth: 0, display: 'flex', flexDirection: 'column', gap: 3 }}>
              <span style={{ fontWeight: 600, fontSize: 14 }}>Segnala</span>
              <span style={{ fontSize: 11, color: 'var(--color-text-secondary)' }}>Nome o contenuti inappropriati</span>
            </div>
            <ChevronRightThinIcon />
          </div>
        )}

        <div style={{ display: 'flex', flexDirection: 'column', gap: 10, padding: '2px 4px 0' }}>
          <div style={{ height: 1, background: 'var(--color-border)' }} />
          <div style={{ display: 'flex', alignItems: 'center', gap: 10, minHeight: 44, cursor: 'pointer' }}>
            <span style={{ flex: 1, minWidth: 0, font: '600 13px/1 var(--font-body)', color: 'var(--color-text-secondary)' }}>Abbandona lega</span>
            <ChevronRightThinIcon />
          </div>
          {league.createdByMe ? (
            <>
              <div style={{ display: 'flex', alignItems: 'center', gap: 10, minHeight: 44, cursor: 'pointer' }}>
                <span style={{ flex: 1, minWidth: 0, font: '600 13px/1 var(--font-body)', color: '#C0304A' }}>Elimina lega</span>
                <ChevronRightThinIcon color="#C0304A" />
              </div>
              <span style={{ fontSize: 11, lineHeight: 1.35, color: 'var(--color-text-secondary)' }}>
                Solo il creatore può eliminare la lega. L'eliminazione rimuove la classifica interna per tutti i membri.
              </span>
            </>
          ) : (
            <span style={{ fontSize: 11, lineHeight: 1.35, color: 'var(--color-text-secondary)' }}>
              Non fai parte di questa lega come creatore, puoi solo uscirne.
            </span>
          )}
        </div>
      </div>
    </div>
  );
}
