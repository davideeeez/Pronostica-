import { useEffect, useState } from 'react';
import { Link, useLocation } from 'react-router-dom';
import { AppHeader } from '../components/AppHeader';
import { ChevronRightIcon, CheckIcon, InfoCircleIcon, LockIcon } from '../components/icons';
import { useAuth } from '../contexts/AuthContext';
import { useCalendar } from '../hooks/useCalendar';
import { useRoundLock } from '../hooks/useRoundLock';
import { fetchMyPredictions, saveMyPredictions, type MyPrediction } from '../lib/predictions';
import { formatRoundDateRange, type CalendarMatch, type RoundSummary } from '../lib/calendar';
import { seasonalPredictions } from '../data/mock';

type Tab = 'pronostica' | 'calendario';
type Draft = { home: string; away: string };

export function Pronostici() {
  const location = useLocation();
  const { session } = useAuth();
  const [selectedLeagueId, setSelectedLeagueId] = useState('gen');
  const [tab, setTab] = useState<Tab>((location.state as { tab?: Tab } | null)?.tab ?? 'pronostica');
  const { loading: calendarLoading, error: calendarError, rounds, currentRound, lastPlayedRound } = useCalendar();
  const [expandedRound, setExpandedRound] = useState<number | null>(null);
  const { isOpen, closesLabel, countdownLabel } = useRoundLock(currentRound?.locksAt ?? null);

  const [predictionsMap, setPredictionsMap] = useState<Record<string, MyPrediction>>({});
  const [drafts, setDrafts] = useState<Record<string, Draft>>({});
  const [predictionsError, setPredictionsError] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);
  const [saveError, setSaveError] = useState<string | null>(null);

  useEffect(() => {
    if (lastPlayedRound && expandedRound === null) setExpandedRound(lastPlayedRound.roundNumber);
  }, [lastPlayedRound, expandedRound]);

  useEffect(() => {
    if (!session || !currentRound) return;
    fetchMyPredictions(session.user.id)
      .then((map) => {
        setPredictionsMap(map);
        setDrafts((prev) => {
          const next = { ...prev };
          for (const m of currentRound.matches) {
            if (next[m.matchId]) continue;
            const saved = map[m.matchId];
            next[m.matchId] = saved ? { home: String(saved.homeGoals), away: String(saved.awayGoals) } : { home: '', away: '' };
          }
          return next;
        });
      })
      .catch((err) => setPredictionsError(err instanceof Error ? err.message : 'Errore sconosciuto.'));
  }, [session, currentRound]);

  const done = currentRound
    ? currentRound.matches.filter((m) => {
        const d = drafts[m.matchId];
        return d && d.home !== '' && d.away !== '';
      }).length
    : 0;
  const total = currentRound?.matches.length ?? 0;

  function setDraft(matchId: string, field: 'home' | 'away', value: string) {
    const digit = value.replace(/\D/g, '').slice(-1);
    setDrafts((prev) => ({ ...prev, [matchId]: { ...(prev[matchId] ?? { home: '', away: '' }), [field]: digit } }));
  }

  async function handleConfirm() {
    if (!session || !isOpen || !currentRound) return;
    setSaving(true);
    setSaveError(null);
    try {
      const entries = currentRound.matches
        .filter((m) => drafts[m.matchId]?.home !== '' && drafts[m.matchId]?.away !== '')
        .map((m) => ({ matchId: m.matchId, homeGoals: Number(drafts[m.matchId].home), awayGoals: Number(drafts[m.matchId].away) }));
      await saveMyPredictions(session.user.id, entries);
      const fresh = await fetchMyPredictions(session.user.id);
      setPredictionsMap(fresh);
    } catch (err) {
      setSaveError(err instanceof Error ? err.message : 'Errore sconosciuto, riprova.');
    } finally {
      setSaving(false);
    }
  }

  const loading = calendarLoading;
  const error = calendarError ?? predictionsError;

  return (
    <div className="page">
      <div style={{ flex: 'none', padding: '6px 18px 12px', display: 'flex', flexDirection: 'column', gap: 12, background: 'var(--color-bg)' }}>
        <AppHeader selectedLeagueId={selectedLeagueId} onSelectLeague={setSelectedLeagueId} />
        <div style={{ display: 'flex', gap: 6, background: 'var(--color-surface)', border: '1px solid var(--color-border)', borderRadius: 14, padding: 4, margin: '0 18px' }}>
          <TabButton active={tab === 'pronostica'} onClick={() => setTab('pronostica')} label="Pronostica!" />
          <TabButton active={tab === 'calendario'} onClick={() => setTab('calendario')} label="Calendario" />
        </div>
      </div>

      <div className="page-scroll" style={tab === 'pronostica' && isOpen ? { paddingBottom: 230 } : undefined}>
        {loading ? (
          <p style={{ margin: '24px 0', fontSize: 13, color: 'var(--color-text-secondary)', textAlign: 'center' }}>Caricamento…</p>
        ) : error ? (
          <p style={{ margin: '24px 0', fontSize: 13, color: '#C0304A', textAlign: 'center' }}>{error}</p>
        ) : !currentRound ? (
          <p style={{ margin: '24px 0', fontSize: 13, color: 'var(--color-text-secondary)', textAlign: 'center' }}>Nessuna giornata disponibile al momento.</p>
        ) : tab === 'pronostica' ? (
          <>
            <div className="card-dark" style={{ padding: '15px 17px', display: 'flex', flexDirection: 'column', gap: 11 }}>
              <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 10 }}>
                <span style={{ font: '600 10.5px/1 var(--font-mono)', letterSpacing: '.12em' }}>SERIE A · GIORNATA {currentRound.roundNumber}</span>
                {closesLabel && (
                  <span style={{ font: '600 10.5px/1 var(--font-mono)', color: 'var(--color-accent)', whiteSpace: 'nowrap' }}>
                    {isOpen ? `CHIUDE ${closesLabel}` : 'CHIUSA'}
                  </span>
                )}
              </div>
              <div style={{ display: 'flex', alignItems: 'flex-end', justifyContent: 'space-between', gap: 12 }}>
                <div style={{ display: 'flex', flexDirection: 'column', gap: 3 }}>
                  <span style={{ fontSize: 11.5, color: '#A9B4CC' }}>Tempo rimasto per tutta la giornata</span>
                  <span style={{ fontFamily: 'var(--font-heading)', fontSize: 28, lineHeight: 1 }}>{isOpen ? (countdownLabel ?? '—') : '00:00:00'}</span>
                </div>
                <span style={{ fontFamily: 'var(--font-heading)', fontSize: 15, color: 'var(--color-accent)', background: 'rgba(255,255,255,.08)', borderRadius: 9, padding: '8px 10px', whiteSpace: 'nowrap' }}>
                  {done}/{total}
                </span>
              </div>
              <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                <div className="progress-track" style={{ background: 'rgba(255,255,255,.16)' }}>
                  <div className="progress-fill" style={{ width: `${total > 0 ? Math.round((done / total) * 100) : 0}%` }} />
                </div>
                <span style={{ font: '600 10px/1 var(--font-mono)', color: '#A9B4CC', whiteSpace: 'nowrap' }}>COMPLETATE</span>
              </div>
              <Link
                to="/menu/regolamento"
                style={{ display: 'flex', alignItems: 'center', gap: 5, alignSelf: 'flex-end', paddingTop: 2, borderTop: '1px solid rgba(255,255,255,.12)', marginTop: 2, width: '100%', justifyContent: 'flex-end' }}
              >
                <InfoCircleIcon size={14} />
                <span style={{ font: '600 9px/1 var(--font-mono)', letterSpacing: '.1em', color: 'var(--color-accent)' }}>REGOLAMENTO</span>
              </Link>
            </div>

            {!isOpen && (
              <div className="card" style={{ padding: '12px 14px', display: 'flex', alignItems: 'center', gap: 9 }}>
                <LockIcon color="var(--color-text-secondary)" size={16} />
                <span style={{ fontSize: 12.5, color: 'var(--color-text-secondary)' }}>
                  Pronostici chiusi: la prima partita della giornata è già iniziata. I tuoi pronostici restano in sola lettura.
                </span>
              </div>
            )}

            {saveError && (
              <div className="card" style={{ padding: '12px 14px', border: '1px solid #C0304A', background: 'rgba(192,48,74,.06)' }}>
                <span style={{ fontSize: 12.5, color: '#C0304A' }}>{saveError}</span>
              </div>
            )}

            <div className="section-divider-row">
              <span className="section-label" style={{ padding: 0 }}>{formatRoundDateRange(currentRound.matches).toUpperCase()} · {currentRound.matches.length} PARTITE</span>
              <span className="section-divider-row__line" />
            </div>
            {currentRound.matches.map((m) => (
              <MatchCard
                key={m.matchId}
                match={m}
                draft={drafts[m.matchId] ?? { home: '', away: '' }}
                editable={isOpen}
                onChangeHome={(v) => setDraft(m.matchId, 'home', v)}
                onChangeAway={(v) => setDraft(m.matchId, 'away', v)}
              />
            ))}

            <div className="card" style={{ padding: '14px 16px', display: 'flex', flexDirection: 'column', gap: 11 }}>
              <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 10 }}>
                <span className="section-label" style={{ padding: 0 }}>PRONOSTICI STAGIONALI</span>
                <span style={{ display: 'flex', alignItems: 'center', gap: 5, font: '600 9px/1 var(--font-mono)', letterSpacing: '.1em', color: 'var(--color-text-secondary)', background: 'var(--color-bg)', borderRadius: 6, padding: '5px 7px' }}>
                  <LockIcon color="var(--color-text-secondary)" size={11} /> BLOCCATI
                </span>
              </div>
              <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
                {seasonalPredictions.map((p) => (
                  <div key={p.label} style={{ display: 'flex', alignItems: 'center', gap: 10, background: '#FBFCFE', border: '1px solid var(--color-bg)', borderRadius: 12, padding: '10px 12px' }}>
                    <div style={{ flex: 1, minWidth: 0, display: 'flex', flexDirection: 'column', gap: 3 }}>
                      <span style={{ fontSize: 11.5, color: 'var(--color-text-secondary)' }}>{p.label}</span>
                      <span style={{ fontFamily: 'var(--font-heading)', fontSize: 14 }}>{p.value ?? 'Non ancora scelto'}</span>
                    </div>
                    {p.points !== null && (
                      <span style={{ font: '600 9px/1 var(--font-mono)', letterSpacing: '.1em', color: 'var(--color-text-secondary)' }}>+{p.points} PT</span>
                    )}
                  </div>
                ))}
              </div>
              <span style={{ fontSize: 11.5, lineHeight: 1.35, color: 'var(--color-text-secondary)' }}>
                Scelti alla chiusura del mercato estivo. Un solo cambio possibile alla chiusura del mercato di gennaio.
              </span>
            </div>

            {isOpen && (
              <div style={{ position: 'absolute', left: 0, right: 0, bottom: 79, background: 'var(--color-surface)', borderTop: '1px solid var(--color-border)', padding: '12px 18px 14px', display: 'flex', flexDirection: 'column', gap: 8 }}>
                <button className="btn btn-primary" style={{ fontSize: 14.5, padding: '14px 16px', minHeight: 48 }} onClick={handleConfirm} disabled={saving || done === 0}>
                  {saving ? 'Salvataggio…' : 'Conferma'}
                </button>
                <button className="btn btn-outline" style={{ fontSize: 13.5, padding: '13px 16px', minHeight: 48 }} onClick={handleConfirm} disabled={saving || done === 0}>
                  Conferma per tutte le leghe
                </button>
              </div>
            )}
          </>
        ) : (
          <CalendarioTab
            rounds={rounds}
            predictionsMap={predictionsMap}
            expandedRound={expandedRound}
            onToggleRound={(n) => setExpandedRound((r) => (r === n ? null : n))}
            onGoToPronostica={() => setTab('pronostica')}
          />
        )}
      </div>
    </div>
  );
}

function CalendarioTab({
  rounds,
  predictionsMap,
  expandedRound,
  onToggleRound,
  onGoToPronostica,
}: {
  rounds: RoundSummary[];
  predictionsMap: Record<string, MyPrediction>;
  expandedRound: number | null;
  onToggleRound: (roundNumber: number) => void;
  onGoToPronostica: () => void;
}) {
  return (
    <>
      {rounds.map((round) => {
        if (round.status === 'corrente') {
          const roundDone = round.matches.filter((m) => predictionsMap[m.matchId]).length;
          return (
            <div key={round.roundNumber} style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
              <div className="section-divider-row">
                <span className="section-divider-row__line" />
                <span className="section-label" style={{ padding: 0 }}>GIORNATA IN CORSO</span>
                <span className="section-divider-row__line" />
              </div>
              <div className="card-dark" style={{ padding: '15px 17px', display: 'flex', flexDirection: 'column', gap: 10, cursor: 'pointer' }} onClick={onGoToPronostica}>
                <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 10 }}>
                  <span style={{ font: '600 10px/1 var(--font-mono)', letterSpacing: '.12em' }}>GIORNATA {round.roundNumber} · PROGRAMMATA</span>
                </div>
                <div style={{ display: 'flex', alignItems: 'flex-end', justifyContent: 'space-between', gap: 12 }}>
                  <span style={{ fontSize: 11.5, color: '#A9B4CC' }}>{formatRoundDateRange(round.matches)} · {round.matches.length} partite</span>
                  <span style={{ fontFamily: 'var(--font-heading)', fontSize: 15, color: 'var(--color-accent)', background: 'rgba(255,255,255,.08)', borderRadius: 9, padding: '8px 10px' }}>
                    {roundDone}/{round.matches.length}
                  </span>
                </div>
              </div>
            </div>
          );
        }

        if (round.status === 'futuro') {
          return (
            <div key={round.roundNumber} className="card" style={{ padding: '14px 16px', display: 'flex', alignItems: 'center', gap: 12 }}>
              <div style={{ flex: 1, display: 'flex', flexDirection: 'column', gap: 4, minWidth: 0 }}>
                <span style={{ fontFamily: 'var(--font-heading)', fontSize: 16 }}>Giornata {round.roundNumber}</span>
                <span style={{ fontSize: 11.5, color: 'var(--color-text-secondary)' }}>{formatRoundDateRange(round.matches)} · {round.matches.length} partite</span>
              </div>
            </div>
          );
        }

        // 'giocato'
        const expanded = expandedRound === round.roundNumber;
        return (
          <div key={round.roundNumber} className="card" style={{ overflow: 'hidden', border: expanded ? '1px solid var(--color-primary)' : undefined }}>
            <div
              style={{ padding: '14px 16px', display: 'flex', alignItems: 'center', gap: 12, cursor: 'pointer' }}
              onClick={() => onToggleRound(round.roundNumber)}
            >
              <div style={{ flex: 1, display: 'flex', flexDirection: 'column', gap: 4, minWidth: 0 }}>
                <span style={{ fontFamily: 'var(--font-heading)', fontSize: 16 }}>Giornata {round.roundNumber}</span>
                <span style={{ fontSize: 11.5, color: 'var(--color-text-secondary)' }}>{formatRoundDateRange(round.matches)} · risultati finali</span>
              </div>
              <ChevronRightIcon color="var(--color-text-secondary)" />
            </div>

            {expanded && (
              <div style={{ borderTop: '1px solid var(--color-border)', padding: '12px 16px 14px', display: 'flex', flexDirection: 'column', gap: 9, background: '#FBFCFE' }}>
                <div style={{ display: 'grid', gridTemplateColumns: '1fr 52px 34px', gap: 8, font: '600 9px/1 var(--font-mono)', letterSpacing: '.1em', color: 'var(--color-text-secondary)' }}>
                  <span>PARTITA</span>
                  <span style={{ textAlign: 'right' }}>TUO</span>
                  <span style={{ textAlign: 'right' }}>PT</span>
                </div>
                {round.matches.map((m) => {
                  const pred = predictionsMap[m.matchId];
                  const pts = pred?.points ?? null;
                  return (
                    <div key={m.matchId} style={{ display: 'grid', gridTemplateColumns: '1fr 52px 34px', gap: 8, alignItems: 'center', padding: '7px 0', borderTop: '1px solid var(--color-bg)' }}>
                      <div style={{ display: 'flex', flexDirection: 'column', gap: 2, minWidth: 0 }}>
                        <span style={{ fontSize: 12.5 }}>{m.home} — {m.away}</span>
                        <span style={{ font: '400 9.5px/1 var(--font-mono)', color: 'var(--color-text-secondary)' }}>{m.homeGoals}-{m.awayGoals}</span>
                      </div>
                      <span style={{ textAlign: 'right', fontFamily: 'var(--font-heading)', fontSize: 13 }}>{pred ? `${pred.homeGoals}-${pred.awayGoals}` : '—'}</span>
                      <span style={{ textAlign: 'right', fontFamily: 'var(--font-heading)', fontSize: 13, color: pts === 3 ? 'var(--color-text-primary)' : pts === 1 ? 'var(--color-text-secondary)' : pts === 0 ? '#C0304A' : 'var(--color-text-secondary)' }}>
                        {pts ?? '—'}
                      </span>
                    </div>
                  );
                })}
              </div>
            )}
          </div>
        );
      })}
    </>
  );
}

function TabButton({ active, onClick, label }: { active: boolean; onClick: () => void; label: string }) {
  return (
    <div
      onClick={onClick}
      style={{
        flex: 1,
        background: active ? 'var(--color-primary)' : 'transparent',
        borderRadius: 10,
        padding: '10px 6px',
        textAlign: 'center',
        fontFamily: active ? 'var(--font-heading)' : undefined,
        fontWeight: active ? undefined : 600,
        fontSize: 12.5,
        color: active ? '#fff' : 'var(--color-text-secondary)',
        minHeight: 40,
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        cursor: 'pointer',
      }}
    >
      {label}
    </div>
  );
}

function ScoreInput({ value, onChange, editable, done }: { value: string; onChange: (v: string) => void; editable: boolean; done: boolean }) {
  const borderColor = done ? 'var(--color-primary)' : '#B9C4DC';
  return (
    <input
      type="tel"
      inputMode="numeric"
      maxLength={1}
      value={value}
      disabled={!editable}
      onChange={(e) => onChange(e.target.value)}
      onClick={(e) => e.stopPropagation()}
      placeholder="–"
      style={{
        width: 46,
        height: 38,
        border: `1.5px ${done ? 'solid' : 'dashed'} ${borderColor}`,
        borderRadius: 9,
        textAlign: 'center',
        fontFamily: 'var(--font-heading)',
        fontSize: 14,
        color: done ? 'var(--color-text-primary)' : '#B9C4DC',
        background: editable ? 'var(--color-surface)' : 'var(--color-bg)',
      }}
    />
  );
}

function MatchCard({
  match,
  draft,
  editable,
  onChangeHome,
  onChangeAway,
}: {
  match: CalendarMatch;
  draft: Draft;
  editable: boolean;
  onChangeHome: (v: string) => void;
  onChangeAway: (v: string) => void;
}) {
  const done = draft.home !== '' && draft.away !== '';

  return (
    <div
      className="card"
      style={{
        border: done ? '1.5px solid var(--color-primary)' : '1.5px dashed #B9C4DC',
        padding: '13px 15px',
        display: 'flex',
        flexDirection: 'column',
        gap: 10,
      }}
    >
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'flex-end', gap: 6 }}>
        {done ? (
          <span className="badge-accent" style={{ display: 'inline-flex', alignItems: 'center', gap: 4 }}>
            <CheckIcon size={11} color="var(--color-text-primary)" /> FATTO
          </span>
        ) : (
          <span className="badge-accent">DA FARE</span>
        )}
      </div>
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 12 }}>
        <span style={{ fontFamily: 'var(--font-heading)', fontSize: 15.5 }}>{match.home} — {match.away}</span>
      </div>
      <div style={{ display: 'flex', alignItems: 'center', gap: 9, borderTop: '1px solid var(--color-bg)', paddingTop: 10 }}>
        <ScoreInput value={draft.home} onChange={onChangeHome} editable={editable} done={done} />
        <span style={{ fontFamily: 'var(--font-heading)', fontSize: 13, color: done ? undefined : '#B9C4DC' }}>:</span>
        <ScoreInput value={draft.away} onChange={onChangeAway} editable={editable} done={done} />
        <span style={{ fontSize: 11.5, color: 'var(--color-text-secondary)' }}>
          {editable ? (done ? 'Tocca per modificare' : 'inserisci il risultato esatto') : 'pronostici chiusi'}
        </span>
      </div>
    </div>
  );
}
