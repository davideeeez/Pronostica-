-- PROPOSTA 1/4 — NON APPLICATA. Stato delle partite e punti provvisori/definitivi.
--
-- Oggi un risultato non nullo vale come finale: un 1-0 al 20' manderebbe il
-- turno in "concluso". Si aggiunge lo stato della partita e si separano i punti.
-- Il flusso manuale resta identico: inserire home_goals/away_goals a fine
-- partita = partita finita (lo stato passa a 'finita' da solo).

-- 1) stato della partita ----------------------------------------------------
alter table public.matches add column status text not null default 'non_iniziata';

-- chi ha già un risultato è finito (nessun risultato è mai stato parziale finora)
update public.matches set status = 'finita' where home_goals is not null and away_goals is not null;

alter table public.matches
  add constraint matches_status_check check (status in ('non_iniziata', 'in_corso', 'finita')),
  add constraint matches_status_goals_check check (
    (status = 'non_iniziata' and home_goals is null and away_goals is null)
    or (status in ('in_corso', 'finita') and home_goals is not null and away_goals is not null)
  );

-- inserire solo il risultato (flusso manuale di oggi) = partita finita
create or replace function public.matches_default_status()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if new.status = 'non_iniziata' and new.home_goals is not null and new.away_goals is not null then
    new.status := 'finita';
  end if;
  return new;
end;
$$;

create trigger matches_default_status
before insert or update on public.matches
for each row execute function public.matches_default_status();

-- 2) "turno corrente" (una sola definizione): primo turno con una partita non finita
create or replace function public.current_round_number()
returns integer
language sql
stable
set search_path = public
as $$
  select coalesce(
    (select min(m.round_number) from public.matches m where m.status <> 'finita'),
    (select max(round_number) from public.rounds)
  )
$$;

-- 3) viste: colonne esistenti invariate, nuove in coda ---------------------------
create or replace view public.calendar
with (security_invoker = true)
as
select
  m.id as match_id,
  m.round_number,
  m.home,
  m.away,
  m.kickoff,
  m.home_goals,
  m.away_goals,
  r.locks_at,
  case
    when not exists (
      select 1 from public.matches m2
      where m2.round_number = m.round_number and m2.status <> 'finita'
    ) then 'giocato'
    when m.round_number = public.open_round_number() then 'corrente'
    when r.locks_at <= now() then 'in_corso'
    else 'futuro'
  end as round_status,
  m.status as match_status
from public.matches m
join public.rounds r on r.round_number = m.round_number;

-- points = provvisori (partite in corso e finite); points_final = solo partite finite
create or replace view public.prediction_scores
with (security_invoker = true)
as
select
  p.id,
  p.user_id,
  p.match_id,
  m.round_number,
  p.home_goals as pred_home,
  p.away_goals as pred_away,
  m.home_goals as actual_home,
  m.away_goals as actual_away,
  public.prediction_points(m.home_goals, m.away_goals, p.home_goals, p.away_goals) as points,
  m.status as match_status,
  case when m.status = 'finita'
       then public.prediction_points(m.home_goals, m.away_goals, p.home_goals, p.away_goals)
  end as points_final
from public.predictions p
join public.matches m on m.id = p.match_id;

-- 4) classifica di lega (leghe a classifica): solo punti definitivi ---------------
-- Oggi nessun effetto (i risultati si inseriscono a fine partita). Con il feed
-- live eviterebbe che un 1-0 al 20' entri in classifica.
create or replace function public.league_leaderboard(p_league_id uuid)
returns table (
  user_id uuid,
  username text,
  crest_pattern text,
  total_points bigint,
  exact_results bigint,
  correct_outcomes bigint,
  joined_at timestamptz,
  rank bigint
)
language sql
security invoker
set search_path = public
stable
as $$
  select
    lm.user_id,
    pr.username,
    pr.crest_pattern,
    coalesce(sum(ps.points_final), 0) as total_points,
    count(*) filter (where ps.points_final = 3) as exact_results,
    count(*) filter (where ps.points_final = 1) as correct_outcomes,
    lm.joined_at,
    rank() over (
      order by coalesce(sum(ps.points_final), 0) desc,
               count(*) filter (where ps.points_final = 3) desc,
               count(*) filter (where ps.points_final = 1) desc
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
$$;

-- 5) igiene dei privilegi (indipendente dagli scontri) ---------------------------
-- authenticated oggi ha anche INSERT/UPDATE/DELETE/TRUNCATE/TRIGGER/REFERENCES
-- su matches e rounds, e DELETE/TRUNCATE/TRIGGER/REFERENCES su predictions e
-- profiles: a fermare le scritture c'è solo la RLS, e TRUNCATE non è soggetto
-- alla RLS (PostgREST non lo espone, ma non deve restare concesso).
-- Le scritture legittime dell'app (predictions e profiles: insert/update, filtrate
-- dalla RLS) restano.
revoke insert, update, delete, truncate, references, trigger on public.matches from authenticated;
revoke insert, update, delete, truncate, references, trigger on public.rounds from authenticated;
revoke delete, truncate, references, trigger on public.predictions from authenticated;
revoke delete, truncate, references, trigger on public.profiles from authenticated;
