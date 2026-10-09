/**
 * Accesso al database per le leghe. Usa SOLO le 9 funzioni RPC create dalla
 * migrazione Fase 4 e le letture permesse di leagues/league_members/
 * league_invites (RLS: visibili solo se membro, o pubbliche per leagues).
 * Nessuna scrittura diretta sulle tabelle qui: ogni mutazione passa da una
 * funzione SECURITY DEFINER che ritorna un esito sentinella.
 */
import { supabase } from './supabaseClient';
import type { CrestPattern } from '../data/mock';

export type LeagueVisibility = 'private' | 'public';

export interface MyLeague {
  id: string;
  name: string;
  visibility: LeagueVisibility;
  startRound: number;
  role: 'owner' | 'member';
  memberCount: number;
}

interface MyLeagueRow {
  league_id: string;
  role: 'owner' | 'member';
  leagues: { id: string; name: string; visibility: LeagueVisibility; start_round: number } | null;
}

/** Le leghe di cui l'utente è membro, con il numero di partecipanti di ciascuna. */
export async function fetchMyLeagues(userId: string): Promise<MyLeague[]> {
  const { data, error } = await supabase
    .from('league_members')
    .select('league_id, role, leagues(id, name, visibility, start_round)')
    .eq('user_id', userId);
  if (error) throw error;

  const rows = (data ?? []) as unknown as MyLeagueRow[];
  const leagueIds = rows.map((r) => r.league_id);
  const counts = await fetchMemberCounts(leagueIds);

  return rows
    .filter((r): r is MyLeagueRow & { leagues: NonNullable<MyLeagueRow['leagues']> } => r.leagues !== null)
    .map((r) => ({
      id: r.leagues.id,
      name: r.leagues.name,
      visibility: r.leagues.visibility,
      startRound: r.leagues.start_round,
      role: r.role,
      memberCount: counts.get(r.league_id) ?? 1,
    }));
}

async function fetchMemberCounts(leagueIds: string[]): Promise<Map<string, number>> {
  const counts = new Map<string, number>();
  if (leagueIds.length === 0) return counts;
  const { data, error } = await supabase.from('league_members').select('league_id').in('league_id', leagueIds);
  if (error) throw error;
  for (const row of data ?? []) {
    counts.set(row.league_id, (counts.get(row.league_id) ?? 0) + 1);
  }
  return counts;
}

export interface LeagueDetail {
  id: string;
  name: string;
  visibility: LeagueVisibility;
  startRound: number;
  createdBy: string;
}

/** Dettaglio di una singola lega (null se non esiste o non è visibile: privata e non membro). */
export async function fetchLeague(leagueId: string): Promise<LeagueDetail | null> {
  const { data, error } = await supabase
    .from('leagues')
    .select('id, name, visibility, start_round, created_by')
    .eq('id', leagueId)
    .maybeSingle();
  if (error) throw error;
  if (!data) return null;
  return {
    id: data.id,
    name: data.name,
    visibility: data.visibility,
    startRound: data.start_round,
    createdBy: data.created_by,
  };
}

export interface LeagueMemberRow {
  userId: string;
  role: 'owner' | 'member';
  joinedAt: string;
  username: string;
  crestPattern: CrestPattern;
}

interface LeagueMemberDbRow {
  user_id: string;
  role: 'owner' | 'member';
  joined_at: string;
  profiles: { username: string; crest_pattern: CrestPattern } | null;
}

/** Membri di una lega (RLS: solo se l'utente stesso è membro). */
export async function fetchLeagueMembers(leagueId: string): Promise<LeagueMemberRow[]> {
  const { data, error } = await supabase
    .from('league_members')
    .select('user_id, role, joined_at, profiles(username, crest_pattern)')
    .eq('league_id', leagueId)
    .order('joined_at');
  if (error) throw error;
  return ((data ?? []) as unknown as LeagueMemberDbRow[]).map((r) => ({
    userId: r.user_id,
    role: r.role,
    joinedAt: r.joined_at,
    username: r.profiles?.username ?? '—',
    crestPattern: r.profiles?.crest_pattern ?? 'star',
  }));
}

/** Codice invito di una lega privata (RLS: solo il creatore lo legge; null altrimenti/se pubblica). */
export async function fetchLeagueInviteCode(leagueId: string): Promise<string | null> {
  const { data, error } = await supabase.from('league_invites').select('code').eq('league_id', leagueId).maybeSingle();
  if (error) throw error;
  return data?.code ?? null;
}

export interface LeaderboardRow {
  userId: string;
  username: string;
  crestPattern: CrestPattern;
  totalPoints: number;
  exactResults: number;
  correctOutcomes: number;
  rank: number;
}

interface LeaderboardDbRow {
  user_id: string;
  username: string;
  crest_pattern: CrestPattern;
  total_points: number;
  exact_results: number;
  correct_outcomes: number;
  joined_at: string;
  rank: number;
}

/** Classifica di una lega (già ordinata per rank, poi iscrizione a parità). */
export async function fetchLeagueLeaderboard(leagueId: string): Promise<LeaderboardRow[]> {
  const { data, error } = await supabase.rpc('league_leaderboard', { p_league_id: leagueId });
  if (error) throw error;
  return ((data ?? []) as LeaderboardDbRow[]).map((r) => ({
    userId: r.user_id,
    username: r.username,
    crestPattern: r.crest_pattern,
    totalPoints: r.total_points,
    exactResults: r.exact_results,
    correctOutcomes: r.correct_outcomes,
    rank: r.rank,
  }));
}

export interface ExploreLeague {
  id: string;
  name: string;
  memberCount: number;
  ownerUsername: string;
  startRound: number;
}

/** Leghe pubbliche esplorabili (list_public_leagues: mai un codice invito). */
export async function fetchExploreLeagues(): Promise<ExploreLeague[]> {
  const { data, error } = await supabase.rpc('list_public_leagues');
  if (error) throw error;
  return ((data ?? []) as { id: string; name: string; member_count: number; owner_username: string; start_round: number }[]).map((r) => ({
    id: r.id,
    name: r.name,
    memberCount: r.member_count,
    ownerUsername: r.owner_username,
    startRound: r.start_round,
  }));
}

/** Crea una lega e ritorna il suo id. create_league lancia un'eccezione Postgres su input non valido. */
export async function createLeague(name: string, visibility: LeagueVisibility, startRound: number): Promise<string> {
  const { data, error } = await supabase.rpc('create_league', {
    p_name: name,
    p_visibility: visibility,
    p_start_round: startRound,
  });
  if (error) throw error;
  return data as string;
}

export type JoinPrivateOutcome = 'ok' | 'already_member' | 'invalid';

export interface JoinPrivateResult {
  outcome: JoinPrivateOutcome;
  leagueId: string | null;
}

/** Unisciti con codice invito. league_id è valorizzato solo per 'ok'/'already_member'. */
export async function joinPrivateLeague(code: string): Promise<JoinPrivateResult> {
  const { data, error } = await supabase.rpc('join_private_league', { p_code: code });
  if (error) throw error;
  const row = (Array.isArray(data) ? data[0] : data) as { outcome: JoinPrivateOutcome; league_id: string | null } | undefined;
  return { outcome: row?.outcome ?? 'invalid', leagueId: row?.league_id ?? null };
}

export type JoinPublicOutcome = 'ok' | 'already_member' | 'not_found';

/** Unisciti a una lega pubblica già nota (id preso da list_public_leagues). */
export async function joinPublicLeague(leagueId: string): Promise<JoinPublicOutcome> {
  const { data, error } = await supabase.rpc('join_public_league', { p_league_id: leagueId });
  if (error) throw error;
  return data as JoinPublicOutcome;
}

export type LeaveLeagueOutcome = 'ok' | 'not_member' | 'owner_cannot_leave';

export async function leaveLeague(leagueId: string): Promise<LeaveLeagueOutcome> {
  const { data, error } = await supabase.rpc('leave_league', { p_league_id: leagueId });
  if (error) throw error;
  return data as LeaveLeagueOutcome;
}

export type RemoveMemberOutcome = 'ok' | 'forbidden' | 'target_is_owner' | 'not_member';

export async function removeLeagueMember(leagueId: string, userId: string): Promise<RemoveMemberOutcome> {
  const { data, error } = await supabase.rpc('remove_league_member', { p_league_id: leagueId, p_user_id: userId });
  if (error) throw error;
  return data as RemoveMemberOutcome;
}

export type RegenerateCodeResult = { ok: true; code: string } | { ok: false; outcome: 'forbidden' | 'not_private' };

export async function regenerateInviteCode(leagueId: string): Promise<RegenerateCodeResult> {
  const { data, error } = await supabase.rpc('regenerate_invite_code', { p_league_id: leagueId });
  if (error) throw error;
  const result = data as string;
  if (result === 'forbidden' || result === 'not_private') {
    return { ok: false, outcome: result };
  }
  return { ok: true, code: result };
}

export type DeleteLeagueOutcome = 'ok' | 'forbidden';

export async function deleteLeague(leagueId: string): Promise<DeleteLeagueOutcome> {
  const { data, error } = await supabase.rpc('delete_league', { p_league_id: leagueId });
  if (error) throw error;
  return data as DeleteLeagueOutcome;
}
