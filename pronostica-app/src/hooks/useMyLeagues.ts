import { useEffect, useState } from 'react';
import { fetchMyLeagues, type MyLeague } from '../lib/leagues';

/** Le leghe dell'utente loggato, con loading/errore. */
export function useMyLeagues(userId: string | undefined) {
  const [leagues, setLeagues] = useState<MyLeague[] | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!userId) return;
    let cancelled = false;
    setLeagues(null);
    setError(null);
    fetchMyLeagues(userId)
      .then((l) => {
        if (!cancelled) setLeagues(l);
      })
      .catch((err) => {
        if (!cancelled) setError(err instanceof Error ? err.message : 'Errore sconosciuto.');
      });
    return () => {
      cancelled = true;
    };
  }, [userId]);

  return {
    loading: userId !== undefined && leagues === null && !error,
    error,
    leagues: leagues ?? [],
  };
}
