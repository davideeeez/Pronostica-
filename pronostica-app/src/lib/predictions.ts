import { supabase } from './supabaseClient';

export interface MyPrediction {
  matchId: string;
  homeGoals: number;
  awayGoals: number;
  /** Punti già calcolati dal database (prediction_points via prediction_scores); null finché la partita non ha un risultato. */
  points: number | null;
}

/** Tutti i pronostici dell'utente, con il punteggio già calcolato dal database — una sola query. */
export async function fetchMyPredictions(userId: string): Promise<Record<string, MyPrediction>> {
  const { data, error } = await supabase
    .from('prediction_scores')
    .select('match_id, pred_home, pred_away, points')
    .eq('user_id', userId);
  if (error) throw error;
  const map: Record<string, MyPrediction> = {};
  for (const row of data ?? []) {
    map[row.match_id] = { matchId: row.match_id, homeGoals: row.pred_home, awayGoals: row.pred_away, points: row.points };
  }
  return map;
}

export interface MyScoreStats {
  totalPoints: number;
  exactResults: number;
  correctOutcomes: number;
  matchesScored: number;
}

/**
 * Statistiche personali calcolate da prediction_scores (mai dalla classifica
 * generale, sospesa fino a gennaio e non più leggibile da authenticated).
 */
export async function fetchMyScoreStats(userId: string): Promise<MyScoreStats> {
  const { data, error } = await supabase
    .from('prediction_scores')
    .select('points')
    .eq('user_id', userId)
    .not('points', 'is', null);
  if (error) throw error;
  const rows = data ?? [];
  return {
    totalPoints: rows.reduce((sum, r) => sum + (r.points ?? 0), 0),
    exactResults: rows.filter((r) => r.points === 3).length,
    correctOutcomes: rows.filter((r) => r.points === 1).length,
    matchesScored: rows.length,
  };
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
