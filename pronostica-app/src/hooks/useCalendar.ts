import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { fetchCalendar, groupByRound, type CalendarMatch } from '../lib/calendar';

/** Il più lungo ritardo accettato da setTimeout (~24,8 giorni): oltre, scatterebbe subito. */
const MAX_TIMEOUT_MS = 2_147_483_647;
/** Scarto dopo locks_at: il database confronta con il proprio now(), il timer con l'orologio del dispositivo. */
const LOCK_MARGIN_MS = 1000;
/** Se per il dispositivo il blocco è passato ma il database ha ancora lo stesso turno aperto (orologio sfasato), si riprova poche volte. */
const STALE_RETRY_MS = 15_000;
const STALE_MAX_RETRIES = 4;

/**
 * Calendario completo (matches+rounds, fonte unica) con loading/errore.
 *
 * Si ricarica da solo, senza polling: una volta alla scadenza di `locks_at` del
 * turno aperto (così passa al turno successivo senza ricaricare l'app) e ogni
 * volta che l'app torna in primo piano (timer sospesi o dispositivo in standby).
 * Un ricaricamento fallito non cancella il calendario già mostrato.
 */
export function useCalendar() {
  const [matches, setMatches] = useState<CalendarMatch[] | null>(null);
  const [error, setError] = useState<string | null>(null);
  const lastRequest = useRef(0);
  const hasData = useRef(false);
  const staleRetries = useRef<{ locksAt: string | null; count: number }>({ locksAt: null, count: 0 });

  const load = useCallback(async () => {
    const request = ++lastRequest.current;
    try {
      const m = await fetchCalendar();
      if (request !== lastRequest.current) return; // risposta superata da una più recente (o hook smontato)
      hasData.current = true;
      setMatches(m);
      setError(null);
    } catch (err) {
      if (request !== lastRequest.current) return;
      if (!hasData.current) setError(err instanceof Error ? err.message : 'Errore sconosciuto.');
    }
  }, []);

  // Allo smontaggio invalida le richieste in corso (la loro risposta verrebbe ignorata).
  const invalidate = useCallback(() => {
    lastRequest.current++;
  }, []);

  useEffect(() => {
    void load();
    return invalidate;
  }, [load, invalidate]);

  useEffect(() => {
    const onVisible = () => {
      if (document.visibilityState === 'visible') void load();
    };
    document.addEventListener('visibilitychange', onVisible);
    return () => document.removeEventListener('visibilitychange', onVisible);
  }, [load]);

  // Identità stabili: senza useMemo i turni verrebbero ricreati a ogni render (ogni secondo, per il countdown)
  // e gli effetti delle pagine che dipendono da `currentRound` rifarebbero le loro richieste a ogni tick.
  const rounds = useMemo(() => (matches ? groupByRound(matches) : []), [matches]);
  const currentRound = useMemo(() => rounds.find((r) => r.status === 'corrente') ?? null, [rounds]);
  const lastPlayedRound = useMemo(() => [...rounds].reverse().find((r) => r.status === 'giocato') ?? null, [rounds]);

  // Un solo timer, fino al blocco del turno aperto; dopo ogni ricaricamento si riarma sul turno nuovo.
  const locksAt = currentRound?.locksAt ?? null;
  useEffect(() => {
    if (!locksAt) return;
    if (staleRetries.current.locksAt !== locksAt) staleRetries.current = { locksAt, count: 0 };

    const remaining = new Date(locksAt).getTime() - Date.now();
    let delay: number;
    if (remaining > 0) {
      delay = Math.min(remaining + LOCK_MARGIN_MS, MAX_TIMEOUT_MS);
    } else {
      if (staleRetries.current.count >= STALE_MAX_RETRIES) return;
      staleRetries.current.count++;
      delay = STALE_RETRY_MS;
    }
    const id = setTimeout(() => void load(), delay);
    return () => clearTimeout(id);
  }, [locksAt, matches, load]);

  return {
    loading: matches === null && !error,
    error,
    matches: matches ?? [],
    rounds,
    currentRound,
    lastPlayedRound,
  };
}
