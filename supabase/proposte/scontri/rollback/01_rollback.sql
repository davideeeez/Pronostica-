-- RIPRISTINO della migrazione 01 (stato di produzione al 2026-10-21, prima dell'applicazione).
-- Ordine: viste -> funzioni -> trigger/colonna -> privilegi.
-- ATTENZIONE: tornando indietro si perde `matches.status` (le partite "in corso" tornano ambigue).

-- viste: prima si ricreano nella forma precedente (le colonne in coda vanno tolte con DROP VIEW)
drop view if exists public.general_leaderboard;
drop view if exists public.calendar;
drop view if exists public.prediction_scores;

create view public.prediction_scores with (security_invoker = true) as
 SELECT p.id, p.user_id, p.match_id, m.round_number,
    p.home_goals AS pred_home, p.away_goals AS pred_away,
    m.home_goals AS actual_home, m.away_goals AS actual_away,
    prediction_points(m.home_goals, m.away_goals, p.home_goals, p.away_goals) AS points
   FROM (predictions p JOIN matches m ON ((m.id = p.match_id)));

create view public.calendar with (security_invoker = true) as
 SELECT m.id AS match_id, m.round_number, m.home, m.away, m.kickoff, m.home_goals, m.away_goals, r.locks_at,
        CASE
            WHEN (NOT (EXISTS ( SELECT 1 FROM matches m2 WHERE ((m2.round_number = m.round_number) AND (m2.home_goals IS NULL))))) THEN 'giocato'::text
            WHEN (m.round_number = open_round_number()) THEN 'corrente'::text
            WHEN (r.locks_at <= now()) THEN 'in_corso'::text
            ELSE 'futuro'::text
        END AS round_status
   FROM (matches m JOIN rounds r ON ((r.round_number = m.round_number)));

create view public.general_leaderboard with (security_invoker = true) as
 SELECT pr.id AS user_id, pr.username, pr.crest_pattern,
    (COALESCE(sum(ps.points), (0)::bigint))::integer AS total_points,
    (COALESCE(count(*) FILTER (WHERE (ps.points = 3)), (0)::bigint))::integer AS exact_results,
    (COALESCE(count(*) FILTER (WHERE (ps.points = 1)), (0)::bigint))::integer AS correct_outcomes,
    rank() OVER (ORDER BY COALESCE(sum(ps.points), (0)::bigint) DESC, COALESCE(count(*) FILTER (WHERE (ps.points = 3)), (0)::bigint) DESC, COALESCE(count(*) FILTER (WHERE (ps.points = 1)), (0)::bigint) DESC) AS rank
   FROM (profiles pr LEFT JOIN prediction_scores ps ON ((ps.user_id = pr.id)))
  WHERE (pr.username IS NOT NULL)
  GROUP BY pr.id, pr.username, pr.crest_pattern, pr.created_at
  ORDER BY ((COALESCE(sum(ps.points), (0)::bigint))::integer) DESC, ((COALESCE(count(*) FILTER (WHERE (ps.points = 3)), (0)::bigint))::integer) DESC, ((COALESCE(count(*) FILTER (WHERE (ps.points = 1)), (0)::bigint))::integer) DESC, pr.created_at;

-- privilegi delle viste (come in produzione: general_leaderboard NON leggibile da authenticated)
revoke all on public.prediction_scores, public.calendar, public.general_leaderboard from anon, public;
grant all on public.prediction_scores, public.calendar to authenticated, service_role;
grant all on public.general_leaderboard to service_role;
grant insert, update, delete, truncate, references, trigger on public.general_leaderboard to authenticated;

create or replace function public.current_round_number()
returns integer language sql stable set search_path to 'public' as $function$
  select coalesce(
    (select min(m.round_number) from public.matches m where m.home_goals is null),
    (select max(round_number) from public.rounds)
  )
$function$;

create or replace function public.league_leaderboard(p_league_id uuid)
returns table(user_id uuid, username text, crest_pattern text, total_points bigint, exact_results bigint, correct_outcomes bigint, joined_at timestamp with time zone, rank bigint)
language sql stable set search_path to 'public' as $function$
  select
    lm.user_id,
    pr.username,
    pr.crest_pattern,
    coalesce(sum(ps.points), 0) as total_points,
    count(*) filter (where ps.points = 3) as exact_results,
    count(*) filter (where ps.points = 1) as correct_outcomes,
    lm.joined_at,
    rank() over (
      order by coalesce(sum(ps.points), 0) desc,
               count(*) filter (where ps.points = 3) desc,
               count(*) filter (where ps.points = 1) desc
    ) as rank
  from public.league_members lm
  join public.profiles pr on pr.id = lm.user_id
  left join public.prediction_scores ps
    on ps.user_id = lm.user_id
   and ps.round_number >= (select l.start_round from public.leagues l where l.id = p_league_id)
  where lm.league_id = p_league_id
  group by lm.user_id, pr.username, pr.crest_pattern, lm.joined_at
  order by rank asc,
           total_points desc,
           exact_results desc,
           correct_outcomes desc,
           lm.joined_at asc;
$function$;

-- stato partita
drop trigger if exists matches_default_status on public.matches;
drop function if exists public.matches_default_status();
alter table public.matches drop constraint if exists matches_status_goals_check;
alter table public.matches drop constraint if exists matches_status_check;
alter table public.matches drop column if exists status;

-- privilegi di tabella come in produzione (authenticated: arwdDxtm su tutte e 4)
grant insert, update, delete, truncate, references, trigger on public.matches to authenticated;
grant insert, update, delete, truncate, references, trigger on public.rounds to authenticated;
grant delete, truncate, references, trigger on public.predictions to authenticated;
grant delete, truncate, references, trigger on public.profiles to authenticated;

-- (01b) privilegi sulle viste come in produzione prima di 01b: authenticated aveva anche
-- INSERT/UPDATE/DELETE/TRUNCATE/REFERENCES/TRIGGER su calendar e prediction_scores (SELECT incluso),
-- e tutto tranne SELECT su general_leaderboard.
grant insert, update, delete, truncate, references, trigger on public.calendar, public.prediction_scores, public.general_leaderboard to authenticated;

-- (01c) MAINTAIN su tutte le relazioni che lo avevano per authenticated in produzione prima di 01c.
grant maintain on public.matches, public.rounds, public.predictions, public.profiles,
  public.calendar, public.prediction_scores, public.general_leaderboard to authenticated;
