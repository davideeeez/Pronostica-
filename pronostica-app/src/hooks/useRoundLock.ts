import { useEffect, useState } from 'react';

const DAYS = ['DOM', 'LUN', 'MAR', 'MER', 'GIO', 'VEN', 'SAB'];

function formatCountdown(ms: number): string {
  if (ms <= 0) return '00:00:00';
  const totalSeconds = Math.floor(ms / 1000);
  // Oltre le 24 ore mostriamo giorni+ore (il secondo non è significativo a quella scala);
  // sotto le 24 ore torna il countdown preciso HH:MM:SS che scorre ogni secondo.
  if (totalSeconds >= 86400) {
    const days = Math.floor(totalSeconds / 86400);
    const hours = Math.floor((totalSeconds % 86400) / 3600);
    return `${days}G ${String(hours).padStart(2, '0')}H`;
  }
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

/**
 * Countdown live verso `locksAt` (preso dal calendario, già caricato da
 * `useCalendar` — nessuna query propria: eviterebbe di duplicare quella che
 * la vista `calendar` fa già in un'unica interrogazione).
 */
export function useRoundLock(locksAt: string | null) {
  const [now, setNow] = useState(() => new Date());

  useEffect(() => {
    const id = setInterval(() => setNow(new Date()), 1000);
    return () => clearInterval(id);
  }, []);

  const locksAtDate = locksAt ? new Date(locksAt) : null;
  const isOpen = locksAtDate !== null && now < locksAtDate;

  return {
    locksAt: locksAtDate,
    isOpen,
    countdownLabel: locksAtDate ? formatCountdown(locksAtDate.getTime() - now.getTime()) : null,
    closesLabel: locksAtDate ? formatCloses(locksAtDate) : null,
  };
}
