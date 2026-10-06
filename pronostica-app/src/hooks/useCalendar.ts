import { useEffect, useState } from 'react';
import { fetchCalendar, groupByRound, type CalendarMatch, type RoundSummary } from '../lib/calendar';

/** Calendario completo (matches+rounds, fonte unica) con loading/errore. */
export function useCalendar() {
  const [matches, setMatches] = useState<CalendarMatch[] | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;
    fetchCalendar()
      .then((m) => {
        if (!cancelled) setMatches(m);
      })
      .catch((err) => {
        if (!cancelled) setError(err instanceof Error ? err.message : 'Errore sconosciuto.');
      });
    return () => {
      cancelled = true;
    };
  }, []);

  const rounds: RoundSummary[] = matches ? groupByRound(matches) : [];
  const currentRound = rounds.find((r) => r.status === 'corrente') ?? null;
  const lastPlayedRound = [...rounds].reverse().find((r) => r.status === 'giocato') ?? null;

  return {
    loading: matches === null && !error,
    error,
    matches: matches ?? [],
    rounds,
    currentRound,
    lastPlayedRound,
  };
}
