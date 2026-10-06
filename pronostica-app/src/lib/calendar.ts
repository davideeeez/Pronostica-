import { supabase } from './supabaseClient';

export type RoundStatus = 'giocato' | 'corrente' | 'futuro';

export interface CalendarMatch {
  matchId: string;
  roundNumber: number;
  home: string;
  away: string;
  kickoff: string;
  homeGoals: number | null;
  awayGoals: number | null;
  locksAt: string;
  roundStatus: RoundStatus;
}

interface CalendarMatchDb {
  match_id: string;
  round_number: number;
  home: string;
  away: string;
  kickoff: string;
  home_goals: number | null;
  away_goals: number | null;
  locks_at: string;
  round_status: RoundStatus;
}

function mapMatch(r: CalendarMatchDb): CalendarMatch {
  return {
    matchId: r.match_id,
    roundNumber: r.round_number,
    home: r.home,
    away: r.away,
    kickoff: r.kickoff,
    homeGoals: r.home_goals,
    awayGoals: r.away_goals,
    locksAt: r.locks_at,
    roundStatus: r.round_status,
  };
}

/** Intero calendario (squadre, orari, risultati, stato turno) in un'unica query. */
export async function fetchCalendar(): Promise<CalendarMatch[]> {
  const { data, error } = await supabase.from('calendar').select('*').order('round_number').order('kickoff');
  if (error) throw error;
  return (data ?? []).map(mapMatch);
}

export interface RoundSummary {
  roundNumber: number;
  locksAt: string;
  status: RoundStatus;
  matches: CalendarMatch[];
}

export function groupByRound(matches: CalendarMatch[]): RoundSummary[] {
  const map = new Map<number, RoundSummary>();
  for (const m of matches) {
    let r = map.get(m.roundNumber);
    if (!r) {
      r = { roundNumber: m.roundNumber, locksAt: m.locksAt, status: m.roundStatus, matches: [] };
      map.set(m.roundNumber, r);
    }
    r.matches.push(m);
  }
  return [...map.values()].sort((a, b) => a.roundNumber - b.roundNumber);
}

const dayFmt = new Intl.DateTimeFormat('it-IT', { timeZone: 'Europe/Rome', day: 'numeric' });
const monthFmt = new Intl.DateTimeFormat('it-IT', { timeZone: 'Europe/Rome', month: 'long' });
const yearFmt = new Intl.DateTimeFormat('it-IT', { timeZone: 'Europe/Rome', year: 'numeric' });

/** "22–24 agosto 2026" (o "30 agosto – 2 settembre 2026" se il turno attraversa due mesi), da kickoff, fuso Europe/Rome. */
export function formatRoundDateRange(matches: CalendarMatch[]): string {
  if (matches.length === 0) return '';
  const times = matches.map((m) => new Date(m.kickoff).getTime());
  const min = new Date(Math.min(...times));
  const max = new Date(Math.max(...times));
  const minMonth = monthFmt.format(min);
  const maxMonth = monthFmt.format(max);
  const year = yearFmt.format(max);
  if (minMonth === maxMonth) {
    return `${dayFmt.format(min)}–${dayFmt.format(max)} ${minMonth} ${year}`;
  }
  return `${dayFmt.format(min)} ${minMonth} – ${dayFmt.format(max)} ${maxMonth} ${year}`;
}
