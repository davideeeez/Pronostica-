import { useEffect, useState } from 'react';
import { fetchRoundLock } from '../lib/predictions';

const DAYS = ['DOM', 'LUN', 'MAR', 'MER', 'GIO', 'VEN', 'SAB'];

function formatCountdown(ms: number): string {
  if (ms <= 0) return '00:00:00';
  const totalSeconds = Math.floor(ms / 1000);
  const h = Math.floor(totalSeconds / 3600);
  const m = Math.floor((totalSeconds % 3600) / 60);
  const s = totalSeconds % 60;
  return `${String(h).padStart(2, '0')}:${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`;
}

function formatCloses(d: Date): string {
  const hh = String(d.getHours()).padStart(2, '0');
  const mm = String(d.getMinutes()).padStart(2, '0');
  return `${DAYS[d.getDay()]} ${hh}:${mm}`;
}

/** Stato di chiusura di un turno, letto da `rounds.locks_at` (mai scritto a mano). */
export function useRoundLock(roundNumber: number) {
  const [locksAt, setLocksAt] = useState<Date | null>(null);
  const [loading, setLoading] = useState(true);
  const [now, setNow] = useState(() => new Date());

  useEffect(() => {
    let cancelled = false;
    fetchRoundLock(roundNumber)
      .then((lock) => {
        if (cancelled) return;
        setLocksAt(lock ? new Date(lock.locksAt) : null);
        setLoading(false);
      })
      .catch(() => {
        if (!cancelled) setLoading(false);
      });
    return () => {
      cancelled = true;
    };
  }, [roundNumber]);

  useEffect(() => {
    const id = setInterval(() => setNow(new Date()), 1000);
    return () => clearInterval(id);
  }, []);

  const isOpen = locksAt !== null && now < locksAt;

  return {
    loading,
    locksAt,
    isOpen,
    countdownLabel: locksAt ? formatCountdown(locksAt.getTime() - now.getTime()) : null,
    closesLabel: locksAt ? formatCloses(locksAt) : null,
  };
}
