import { supabase } from './supabaseClient';

export interface RoundLock {
  roundNumber: number;
  locksAt: string;
}

export async function fetchRoundLock(roundNumber: number): Promise<RoundLock | null> {
  const { data, error } = await supabase
    .from('rounds')
    .select('round_number, locks_at')
    .eq('round_number', roundNumber)
    .maybeSingle();
  if (error) throw error;
  if (!data) return null;
  return { roundNumber: data.round_number, locksAt: data.locks_at };
}

/** Pronostici dell'utente per gli id partita indicati, come mappa match_id -> "home-away". */
export async function fetchMyPredictions(userId: string, matchIds: string[]): Promise<Record<string, string>> {
  if (matchIds.length === 0) return {};
  const { data, error } = await supabase
    .from('predictions')
    .select('match_id, home_goals, away_goals')
    .eq('user_id', userId)
    .in('match_id', matchIds);
  if (error) throw error;
  const map: Record<string, string> = {};
  for (const row of data ?? []) {
    map[row.match_id] = `${row.home_goals}-${row.away_goals}`;
  }
  return map;
}

export interface PredictionEntry {
  matchId: string;
  homeGoals: number;
  awayGoals: number;
}

/** Upsert in blocco: un solo pronostico per partita, riscrivibile finché il turno è aperto. */
export async function saveMyPredictions(userId: string, entries: PredictionEntry[]): Promise<void> {
  if (entries.length === 0) return;
  const rows = entries.map((e) => ({
    user_id: userId,
    match_id: e.matchId,
    home_goals: e.homeGoals,
    away_goals: e.awayGoals,
  }));
  const { error } = await supabase.from('predictions').upsert(rows, { onConflict: 'user_id,match_id' });
  if (error) throw error;
}
