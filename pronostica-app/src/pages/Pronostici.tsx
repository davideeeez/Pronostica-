import { useEffect, useMemo, useState } from 'react';
import { Link, useLocation } from 'react-router-dom';
import { AppHeader } from '../components/AppHeader';
import { ChevronRightIcon, CheckIcon, InfoCircleIcon, LockIcon } from '../components/icons';
import { useAuth } from '../contexts/AuthContext';
import { useRoundLock } from '../hooks/useRoundLock';
import { fetchMyPredictions, saveMyPredictions } from '../lib/predictions';
import { serieARounds, currentRoundNumber, SCHEDULE_COMPLETE_THROUGH, fantasyPointsForMatch, seasonalPredictions, type RealMatch } from '../data/mock';

type Tab = 'pronostica' | 'calendario';
type Draft = { home: string; away: string };

const ALL_MATCH_IDS = serieARounds.flatMap((r) => r.matches.map((m) => m.id));

export function Pronostici() {
  const location = useLocation();
  const { session } = useAuth();
  const [selectedLeagueId, setSelectedLeagueId] = useState('gen');
  const [tab, setTab] = useState<Tab>((location.state as { tab?: Tab } | null)?.tab ?? 'pronostica');
  const lastPlayed = [...serieARounds].reverse().find((r) => r.status === 'played');
  const [expandedRound, setExpandedRound] = useState<number | null>(lastPlayed?.number ?? null);

  const currentRound = serieARounds.find((r) => r.number === currentRoundNumber)!;
  const { isOpen, loading: lockLoading, closesLabel, countdownLabel } = useRoundLock(currentRoundNumber);

  const [predictionsMap, setPredictionsMap] = useState<Record<string, string>>({});
  const [drafts, setDrafts] = useState<Record<string, Draft>>({});
  const [saving, setSaving] = useState(false);
  const [saveError, setSaveError] = useState<string | null>(null);

  useEffect(() => {
    if (!session) return;
    fetchMyPredictions(session.user.id, ALL_MATCH_IDS).then((map) => {
      setPredictionsMap(map);
      setDrafts((prev) => {
        const next = { ...prev };
        for (const m of currentRound.matches) {
          if (next[m.id]) continue;
          const saved = map[m.id];
          next[m.id] = saved ? { home: saved.split('-')[0], away: saved.split('-')[1] } : { home: '', away: '' };
        }
        return next;
      });
    });
  }, [session]);

  const roundsWithPredictions = useMemo(
    () =>
      serieARounds.map((r) => ({
        ...r,
        matches: r.matches.map((m) => ({ ...m, myPrediction: predictionsMap[m.id] })),
      })),
    [predictionsMap],
  );

  const done = currentRound.matches.filter((m) => {
    const d = drafts[m.id];
    return d && d.home !== '' && d.away !== '';
  }).length;
  const total = currentRound.matches.length;

  function setDraft(matchId: string, field: 'home' | 'away', value: string) {
    const digit = value.replace(/\D/g, '').slice(-1);
    setDrafts((prev) => ({ ...prev, [matchId]: { ...(prev[matchId] ?? { home: '', away: '' }), [field]: digit } }));
  }

  async function handleConfirm() {
    if (!session || !isOpen) return;
    setSaving(true);
    setSaveError(null);
    try {
      const entries = currentRound.matches
        .filter((m) => drafts[m.id]?.home !== '' && drafts[m.id]?.away !== '')
        .map((m) => ({ matchId: m.id, homeGoals: Number(drafts[m.id].home), awayGoals: Number(drafts[m.id].away) }));
      await saveMyPredictions(session.user.id, entries);
      setPredictionsMap((prev) => {
        const next = { ...prev };
        for (const e of entries) next[e.matchId] = `${e.homeGoals}-${e.awayGoals}`;
        return next;
      });
    } catch (err) {
      setSaveError(err instanceof Error ? err.message : 'Errore sconosciuto, riprova.');
    } finally {
      setSaving(false);
    }
  }

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
        {tab === 'pronostica' ? (
          <>
            <div className="card-dark" style={{ padding: '15px 17px', display: 'flex', flexDirection: 'column', gap: 11 }}>
              <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 10 }}>
                <span style={{ font: '600 10.5px/1 var(--font-mono)', letterSpacing: '.12em' }}>SERIE A · GIORNATA {currentRound.number}</span>
                {!lockLoading && closesLabel && (
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
                  <div className="progress-fill" style={{ width: `${Math.round((done / total) * 100)}%` }} />
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

            {!isOpen && !lockLoading && (
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
              <span className="section-label" style={{ padding: 0 }}>{currentRound.dateRangeLabel.toUpperCase()} · {currentRound.matches.length} PARTITE</span>
              <span className="section-divider-row__line" />
            </div>
            {currentRound.matches.map((m) => (
              <MatchCard
                key={m.id}
                match={m}
                draft={drafts[m.id] ?? { home: '', away: '' }}
                editable={isOpen}
                onChangeHome={(v) => setDraft(m.id, 'home', v)}
                onChangeAway={(v) => setDraft(m.id, 'away', v)}
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
          <>
            {roundsWithPredictions.map((round) => {
              if (round.status === 'upcoming') {
                const roundDone = round.matches.filter((m) => m.myPrediction).length;
                return (
                  <div key={round.number} style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
                    <div className="section-divider-row">
                      <span className="section-divider-row__line" />
                      <span className="section-label" style={{ padding: 0 }}>GIORNATA IN CORSO</span>
                      <span className="section-divider-row__line" />
                    </div>
                    <div className="card-dark" style={{ padding: '15px 17px', display: 'flex', flexDirection: 'column', gap: 10, cursor: 'pointer' }} onClick={() => setTab('pronostica')}>
                      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 10 }}>
                        <span style={{ font: '600 10px/1 var(--font-mono)', letterSpacing: '.12em' }}>GIORNATA {round.number} · PROGRAMMATA</span>
                      </div>
                      <div style={{ display: 'flex', alignItems: 'flex-end', justifyContent: 'space-between', gap: 12 }}>
                        <span style={{ fontSize: 11.5, color: '#A9B4CC' }}>{round.dateRangeLabel} · {round.matches.length} partite</span>
                        <span style={{ fontFamily: 'var(--font-heading)', fontSize: 15, color: 'var(--color-accent)', background: 'rgba(255,255,255,.08)', borderRadius: 9, padding: '8px 10px' }}>
                          {roundDone}/{round.matches.length}
                        </span>
                      </div>
                    </div>
                  </div>
                );
              }

              if (round.status === 'played-unverified') {
                return (
                  <div key={round.number} className="card" style={{ padding: '14px 16px', display: 'flex', alignItems: 'center', gap: 12 }}>
                    <div style={{ flex: 1, display: 'flex', flexDirection: 'column', gap: 4, minWidth: 0 }}>
                      <span style={{ fontFamily: 'var(--font-heading)', fontSize: 16 }}>Giornata {round.number}</span>
                      <span style={{ fontSize: 11.5, color: 'var(--color-text-secondary)' }}>
                        {round.dateRangeLabel} · risultati non disponibili
                        {round.missingMatches ? ` (${round.matches.length}/${round.matches.length + round.missingMatches} partite note)` : ''}
                      </span>
                    </div>
                  </div>
                );
              }

              const expanded = expandedRound === round.number;
              return (
                <div key={round.number} className="card" style={{ overflow: 'hidden', border: expanded ? '1px solid var(--color-primary)' : undefined }}>
                  <div
                    style={{ padding: '14px 16px', display: 'flex', alignItems: 'center', gap: 12, cursor: 'pointer' }}
                    onClick={() => setExpandedRound((r) => (r === round.number ? null : round.number))}
                  >
                    <div style={{ flex: 1, display: 'flex', flexDirection: 'column', gap: 4, minWidth: 0 }}>
                      <span style={{ fontFamily: 'var(--font-heading)', fontSize: 16 }}>Giornata {round.number}</span>
                      <span style={{ fontSize: 11.5, color: 'var(--color-text-secondary)' }}>
                        {round.dateRangeLabel} · risultati finali
                        {round.fantasyDemo ? ` · ${round.fantasyDemo.points}pt (media ${round.fantasyDemo.average}pt)` : ''}
                      </span>
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
                        const pts = fantasyPointsForMatch(m);
                        return (
                          <div key={m.id} style={{ display: 'grid', gridTemplateColumns: '1fr 52px 34px', gap: 8, alignItems: 'center', padding: '7px 0', borderTop: '1px solid var(--color-bg)' }}>
                            <div style={{ display: 'flex', flexDirection: 'column', gap: 2, minWidth: 0 }}>
                              <span style={{ fontSize: 12.5 }}>{m.home} — {m.away}</span>
                              <span style={{ font: '400 9.5px/1 var(--font-mono)', color: 'var(--color-text-secondary)' }}>{m.homeScore}-{m.awayScore}</span>
                            </div>
                            <span style={{ textAlign: 'right', fontFamily: 'var(--font-heading)', fontSize: 13 }}>{m.myPrediction ?? '—'}</span>
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

            <div className="section-divider-row">
              <span className="section-divider-row__line" />
              <span className="section-label" style={{ padding: 0 }}>IN ARRIVO</span>
              <span className="section-divider-row__line" />
            </div>
            <p style={{ margin: 0, fontSize: 13, color: 'var(--color-text-secondary)', textAlign: 'center', padding: '4px 0' }}>
              Calendario dalla giornata {SCHEDULE_COMPLETE_THROUGH + 1} in arrivo.
            </p>
          </>
        )}
      </div>
    </div>
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
  match: RealMatch;
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
