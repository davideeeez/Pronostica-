import { useCallback, useEffect, useMemo, useRef, useState, type ReactNode } from 'react';
import { useLocation } from 'react-router-dom';
import { useAuth } from './AuthContext';
import { MyLeaguesContext, type MyLeaguesValue } from './myLeaguesContext';
import { fetchMyLeagues, type MyLeague } from '../lib/leagues';
import { getSelectedLeagueId, setSelectedLeagueId } from '../lib/selectedLeague';

interface State {
  /** Di chi è l'elenco: cambiando account non si mostra l'elenco di quello precedente. */
  userId: string | undefined;
  /** `null` finché l'elenco non è stato caricato almeno una volta. */
  leagues: MyLeague[] | null;
  /** Con l'elenco caricato è sempre una mia lega (o `null` se non ne ho); prima è il valore salvato, non ancora verificato. */
  selectedId: string | null;
}

/** La lega cercata se è ancora tra le mie, altrimenti la prima, altrimenti nessuna. */
function resolveSelectedId(wanted: string | null, leagues: MyLeague[]): string | null {
  if (wanted && leagues.some((l) => l.id === wanted)) return wanted;
  return leagues[0]?.id ?? null;
}

/**
 * Unica fonte di verità per le mie leghe e per la lega selezionata. Sta sopra
 * le rotte (dentro AuthProvider), quindi non si smonta navigando fra le pagine.
 * - all'avvio legge la lega salvata sul dispositivo (localStorage);
 * - finché l'elenco non è caricato non scrive nulla sul dispositivo: la scelta
 *   salvata non viene sovrascritta dalla "prima lega";
 * - a elenco caricato verifica la scelta: se non è più tra le mie leghe
 *   (uscita, rimozione, eliminazione) ripiega sulla prima, o su nessuna;
 * - a ogni cambio salva la scelta sul dispositivo.
 * L'elenco si ricarica a ogni cambio di pagina e quando l'app torna visibile,
 * senza mai svuotarlo nel frattempo (niente lampeggi, niente falsi "nessuna lega").
 */
export function MyLeaguesProvider({ children }: { children: ReactNode }) {
  const { session } = useAuth();
  const userId = session?.user.id;
  const { pathname } = useLocation();

  const [state, setState] = useState<State>(() => ({ userId: undefined, leagues: null, selectedId: getSelectedLeagueId() }));
  const [error, setError] = useState<string | null>(null);
  const lastRequest = useRef(0);

  const refreshLeagues = useCallback(async () => {
    if (!userId) return;
    const request = ++lastRequest.current;
    try {
      const list = await fetchMyLeagues(userId);
      if (request !== lastRequest.current) return; // risposta superata da una richiesta più recente
      setState((prev) => ({ userId, leagues: list, selectedId: resolveSelectedId(prev.selectedId, list) }));
      setError(null);
    } catch (err) {
      if (request !== lastRequest.current) return;
      setError(err instanceof Error ? err.message : 'Errore sconosciuto.');
    }
  }, [userId]);

  useEffect(() => {
    void refreshLeagues();
  }, [refreshLeagues, pathname]);

  useEffect(() => {
    const onVisible = () => {
      if (document.visibilityState === 'visible') void refreshLeagues();
    };
    document.addEventListener('visibilitychange', onVisible);
    return () => document.removeEventListener('visibilitychange', onVisible);
  }, [refreshLeagues]);

  // Salva sul dispositivo solo a elenco caricato (mai durante il caricamento).
  useEffect(() => {
    if (state.leagues === null) return;
    setSelectedLeagueId(state.selectedId);
  }, [state.leagues, state.selectedId]);

  const selectLeague = useCallback((id: string) => {
    setState((prev) => (prev.leagues?.some((l) => l.id === id) ? { ...prev, selectedId: id } : prev));
  }, []);

  const value = useMemo<MyLeaguesValue>(() => {
    const leagues = state.userId === userId ? state.leagues : null;
    return {
      leagues: leagues ?? [],
      loading: userId !== undefined && leagues === null && !error,
      error,
      selectedLeague: leagues?.find((l) => l.id === state.selectedId) ?? null,
      selectLeague,
      refreshLeagues,
    };
  }, [state, userId, error, selectLeague, refreshLeagues]);

  return <MyLeaguesContext.Provider value={value}>{children}</MyLeaguesContext.Provider>;
}
