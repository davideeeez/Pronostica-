/**
 * Classifica generale SOSPESA fino a gennaio (si riattiva dopo la giornata 19):
 * il SELECT su general_leaderboard è stato revocato anche ad authenticated,
 * quindi fetchLeaderboard() fallirebbe se chiamata ora. Nessun componente la
 * importa finché la vista non viene riattivata — file tenuto pronto, non
 * cancellato, esattamente come la vista nel database.
 */
import { supabase } from './supabaseClient';
import type { CrestPattern } from '../data/mock';

export interface LeaderboardRow {
  userId: string;
  username: string;
  crestPattern: CrestPattern;
  totalPoints: number;
  exactResults: number;
  correctOutcomes: number;
  rank: number;
}

interface LeaderboardRowDb {
  user_id: string;
  username: string;
  crest_pattern: CrestPattern;
  total_points: number;
  exact_results: number;
  correct_outcomes: number;
  rank: number;
}

function mapRow(r: LeaderboardRowDb): LeaderboardRow {
  return {
    userId: r.user_id,
    username: r.username,
    crestPattern: r.crest_pattern,
    totalPoints: r.total_points,
    exactResults: r.exact_results,
    correctOutcomes: r.correct_outcomes,
    rank: r.rank,
  };
}

/** Classifica generale completa, già ordinata (rank, poi ordine di iscrizione a parità). */
export async function fetchLeaderboard(): Promise<LeaderboardRow[]> {
  const { data, error } = await supabase.from('general_leaderboard').select('*');
  if (error) throw error;
  return (data ?? []).map(mapRow);
}
