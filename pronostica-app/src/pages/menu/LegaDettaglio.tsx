import { useEffect, useState } from 'react';
import { Link, useNavigate, useParams } from 'react-router-dom';
import { PageHeader } from '../../components/PageHeader';
import { ShieldCrest, ShareIcon, ChevronRightThinIcon, CopyIcon } from '../../components/icons';
import { useAuth } from '../../contexts/AuthContext';
import {
  deleteLeague,
  fetchLeague,
  fetchLeagueInviteCode,
  fetchLeagueLeaderboard,
  fetchLeagueMembers,
  leaveLeague,
  regenerateInviteCode,
  removeLeagueMember,
  type LeaderboardRow,
  type LeagueDetail,
  type LeagueMemberRow,
} from '../../lib/leagues';

type Tab = 'classifica' | 'membri';

export function LegaDettaglio() {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const { session } = useAuth();
  const myUserId = session?.user.id;

  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [league, setLeague] = useState<LeagueDetail | null>(null);
  const [leaderboard, setLeaderboard] = useState<LeaderboardRow[]>([]);
  const [members, setMembers] = useState<LeagueMemberRow[]>([]);
  const [inviteCode, setInviteCode] = useState<string | null>(null);
  const [tab, setTab] = useState<Tab>('classifica');
  const [copied, setCopied] = useState(false);
  const [actionError, setActionError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  const isOwner = members.some((m) => m.userId === myUserId && m.role === 'owner');

  useEffect(() => {
    if (!id) return;
    let cancelled = false;
    setLoading(true);
    setError(null);
    Promise.all([fetchLeague(id), fetchLeagueLeaderboard(id), fetchLeagueMembers(id)])
      .then(([leagueDetail, rows, memberRows]) => {
        if (cancelled) return;
        setLeague(leagueDetail);
        setLeaderboard(rows);
        setMembers(memberRows);
        if (leagueDetail?.visibility === 'private') {
          fetchLeagueInviteCode(id).then((code) => {
            if (!cancelled) setInviteCode(code);
          });
        }
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
  }, [id]);

  async function handleCopy(code: string) {
    try {
      await navigator.clipboard.writeText(code);
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
    } catch {
      // clipboard non disponibile
    }
  }

  async function handleShare(code: string) {
    if (!navigator.share) return;
    try {
      await navigator.share({ title: 'Pronostica!', text: `Unisciti alla mia lega su Pronostica! con il codice ${code}` });
    } catch {
      // condivisione annullata
    }
  }

  async function handleRegenerate() {
    if (!id) return;
    setActionError(null);
    setBusy(true);
    try {
      const result = await regenerateInviteCode(id);
      if (result.ok) {
        setInviteCode(result.code);
      } else {
        setActionError(result.outcome === 'forbidden' ? 'Solo il creatore può rigenerare il codice.' : 'Questa lega non è privata.');
      }
    } catch (err) {
      setActionError(err instanceof Error ? err.message : 'Errore sconosciuto.');
    } finally {
      setBusy(false);
    }
  }

  async function handleRemoveMember(userId: string) {
    if (!id) return;
    if (!window.confirm('Rimuovere questo membro dalla lega?')) return;
    setActionError(null);
    setBusy(true);
    try {
      const outcome = await removeLeagueMember(id, userId);
      if (outcome === 'ok') {
        setMembers((prev) => prev.filter((m) => m.userId !== userId));
        setLeaderboard((prev) => prev.filter((r) => r.userId !== userId));
      } else if (outcome === 'forbidden') {
        setActionError('Non puoi rimuovere questo membro.');
      } else if (outcome === 'target_is_owner') {
        setActionError('Non puoi rimuovere il creatore della lega.');
      } else {
        setActionError('Questo membro non fa più parte della lega.');
      }
    } catch (err) {
      setActionError(err instanceof Error ? err.message : 'Errore sconosciuto.');
    } finally {
      setBusy(false);
    }
  }

  async function handleLeave() {
    if (!id) return;
    if (!window.confirm('Uscire da questa lega?')) return;
    setActionError(null);
    setBusy(true);
    try {
      const outcome = await leaveLeague(id);
      if (outcome === 'ok') {
        navigate('/menu/leghe');
      } else if (outcome === 'owner_cannot_leave') {
        setActionError('Il creatore non può abbandonare la lega. Eliminala, oppure trasferiscine la proprietà (non ancora disponibile).');
      } else {
        setActionError('Non fai più parte di questa lega.');
      }
    } catch (err) {
      setActionError(err instanceof Error ? err.message : 'Errore sconosciuto.');
    } finally {
      setBusy(false);
    }
  }

  async function handleDelete() {
    if (!id) return;
    if (!window.confirm('Eliminare questa lega? La classifica interna sarà rimossa per tutti i membri. Operazione irreversibile.')) return;
    setActionError(null);
    setBusy(true);
    try {
      const outcome = await deleteLeague(id);
      if (outcome === 'ok') {
        navigate('/menu/leghe');
      } else {
        setActionError('Solo il creatore può eliminare la lega.');
      }
    } catch (err) {
      setActionError(err instanceof Error ? err.message : 'Errore sconosciuto.');
    } finally {
      setBusy(false);
    }
  }

  if (loading) {
    return (
      <div className="page">
        <PageHeader title="Lega" />
        <div className="page-scroll">
          <p style={{ color: 'var(--color-text-secondary)', fontSize: 14 }}>Caricamento…</p>
        </div>
      </div>
    );
  }

  if (error || !league) {
    return (
      <div className="page">
        <PageHeader title="Lega" />
        <div className="page-scroll">
          <p style={{ color: error ? '#C0304A' : 'var(--color-text-secondary)', fontSize: 14 }}>
            {error ?? 'Lega non trovata.'}
          </p>
          <Link to="/menu/leghe" style={{ fontWeight: 600, fontSize: 14 }}>Torna alle leghe</Link>
        </div>
      </div>
    );
  }

  const hasPoints = leaderboard.some((r) => r.totalPoints > 0);

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
                  {league.visibility === 'private' ? 'PRIVATA' : 'PUBBLICA'}
                </span>
                <span style={{ font: '400 10px/1 var(--font-mono)', letterSpacing: '.05em', color: '#A9B4CC' }}>
                  {members.length.toLocaleString('it-IT')} PARTECIPANTI · DAL TURNO {league.startRound}
                </span>
              </div>
            </div>
          </div>
        </div>

        {inviteCode && isOwner && (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
            <span className="section-label">CODICE INVITO</span>
            <div className="card" style={{ padding: '15px 16px', display: 'flex', alignItems: 'center', gap: 11 }}>
              <span style={{ flex: 1, minWidth: 0, fontFamily: 'var(--font-heading)', fontSize: 20, letterSpacing: '.1em' }}>{inviteCode}</span>
              <div onClick={() => handleCopy(inviteCode)} style={{ flex: 'none', display: 'flex', alignItems: 'center', gap: 7, background: 'var(--color-accent)', borderRadius: 12, padding: '11px 13px', minHeight: 44, cursor: 'pointer' }}>
                <CopyIcon />
                <span style={{ font: '600 12px/1 var(--font-body)' }}>{copied ? 'Copiato!' : 'Copia'}</span>
              </div>
              {typeof navigator.share === 'function' && (
                <div onClick={() => handleShare(inviteCode)} style={{ flex: 'none', display: 'flex', alignItems: 'center', gap: 7, background: 'var(--color-bg)', borderRadius: 12, padding: '11px 13px', minHeight: 44, cursor: 'pointer' }}>
                  <ShareIcon />
                </div>
              )}
            </div>
            <div onClick={busy ? undefined : handleRegenerate} style={{ display: 'flex', alignItems: 'center', gap: 10, minHeight: 44, cursor: busy ? 'default' : 'pointer', opacity: busy ? 0.6 : 1 }}>
              <span style={{ flex: 1, minWidth: 0, font: '600 13px/1 var(--font-body)', color: 'var(--color-text-primary)' }}>Rigenera codice</span>
              <ChevronRightThinIcon />
            </div>
          </div>
        )}

        <div style={{ display: 'flex', gap: 8 }}>
          <div
            onClick={() => setTab('classifica')}
            className={tab === 'classifica' ? 'card-dark' : 'card'}
            style={{ flex: 1, padding: '11px 0', textAlign: 'center', fontWeight: 600, fontSize: 13, cursor: 'pointer' }}
          >
            Classifica
          </div>
          <div
            onClick={() => setTab('membri')}
            className={tab === 'membri' ? 'card-dark' : 'card'}
            style={{ flex: 1, padding: '11px 0', textAlign: 'center', fontWeight: 600, fontSize: 13, cursor: 'pointer' }}
          >
            Membri
          </div>
        </div>

        {actionError && <p style={{ color: '#C0304A', fontSize: 13, textAlign: 'center' }}>{actionError}</p>}

        {tab === 'classifica' ? (
          leaderboard.length === 0 ? (
            <p style={{ color: 'var(--color-text-secondary)', fontSize: 13, textAlign: 'center', padding: '24px 0' }}>Nessun membro in classifica.</p>
          ) : (
            <div className="card" style={{ padding: '2px 16px', display: 'flex', flexDirection: 'column' }}>
              {leaderboard.map((r, i) => (
                <div key={r.userId} style={{ display: 'flex', alignItems: 'center', gap: 10, padding: '12px 0', borderTop: i === 0 ? 'none' : '1px solid var(--color-bg)' }}>
                  <div style={{ flex: 'none', width: 34, height: 34, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                    <ShieldCrest size={24} pattern={r.crestPattern} />
                  </div>
                  <span style={{ flex: 1, minWidth: 0, fontWeight: 600, fontSize: 13.5, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                    {r.username}{r.userId === myUserId ? ' (tu)' : ''}
                  </span>
                  <span style={{ flex: 'none', font: '600 10px/1 var(--font-mono)', letterSpacing: '.05em', color: 'var(--color-text-secondary)' }}>{r.totalPoints} PT</span>
                  {hasPoints && (
                    <span style={{ flex: 'none', fontFamily: 'var(--font-heading)', fontSize: 13, minWidth: 22, textAlign: 'right' }}>{r.rank}</span>
                  )}
                </div>
              ))}
            </div>
          )
        ) : (
          <div className="card" style={{ padding: '2px 16px', display: 'flex', flexDirection: 'column' }}>
            {members.map((m, i) => (
              <div key={m.userId} style={{ display: 'flex', alignItems: 'center', gap: 10, padding: '12px 0', borderTop: i === 0 ? 'none' : '1px solid var(--color-bg)' }}>
                <ShieldCrest size={28} pattern={m.crestPattern} />
                <span style={{ flex: 1, minWidth: 0, fontWeight: 600, fontSize: 13.5, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{m.username}</span>
                {m.role === 'owner' && <span className="badge-neutral">CREATORE</span>}
                {isOwner && m.role !== 'owner' && (
                  <span
                    onClick={() => (busy ? undefined : handleRemoveMember(m.userId))}
                    style={{ flex: 'none', font: '600 11px/1 var(--font-body)', color: '#C0304A', cursor: busy ? 'default' : 'pointer', opacity: busy ? 0.6 : 1 }}
                  >
                    Rimuovi
                  </span>
                )}
              </div>
            ))}
          </div>
        )}

        <div style={{ display: 'flex', flexDirection: 'column', gap: 10, padding: '2px 4px 0' }}>
          <div style={{ height: 1, background: 'var(--color-border)' }} />
          {!isOwner && (
            <div onClick={busy ? undefined : handleLeave} style={{ display: 'flex', alignItems: 'center', gap: 10, minHeight: 44, cursor: busy ? 'default' : 'pointer', opacity: busy ? 0.6 : 1 }}>
              <span style={{ flex: 1, minWidth: 0, font: '600 13px/1 var(--font-body)', color: 'var(--color-text-secondary)' }}>Esci dalla lega</span>
              <ChevronRightThinIcon />
            </div>
          )}
          {isOwner && (
            <>
              <div onClick={busy ? undefined : handleDelete} style={{ display: 'flex', alignItems: 'center', gap: 10, minHeight: 44, cursor: busy ? 'default' : 'pointer', opacity: busy ? 0.6 : 1 }}>
                <span style={{ flex: 1, minWidth: 0, font: '600 13px/1 var(--font-body)', color: '#C0304A' }}>Elimina lega</span>
                <ChevronRightThinIcon color="#C0304A" />
              </div>
              <span style={{ fontSize: 11, lineHeight: 1.35, color: 'var(--color-text-secondary)' }}>
                Solo il creatore può eliminare la lega. L'eliminazione rimuove la classifica interna per tutti i membri.
              </span>
            </>
          )}
        </div>
      </div>
    </div>
  );
}
