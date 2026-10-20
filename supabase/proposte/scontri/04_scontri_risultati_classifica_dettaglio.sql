-- PROPOSTA 4/4 — NON APPLICATA. Lettura degli scontri: elenco, risultati, classifica, dettaglio.
-- Tutte le funzioni sono SECURITY INVOKER: la RLS decide cosa si vede (abbinamenti
-- solo ai membri; pronostici altrui solo dopo il blocco del turno e tra chi
-- condivide una lega). Nessuna scrive: il calendario nasce in h2h_league_state.

-- 1) elenco degli scontri: il mio per primo in ogni turno -----------------------------------
create or replace function public.h2h_pairings(p_league_id uuid)
returns table (
  round_number int,
  slot smallint,
  user_a uuid,
  username_a text,
  user_b uuid,
  username_b text,
  is_rest boolean,
  is_mine boolean
)
language sql
stable
set search_path = public
as $$
  select p.round_number, p.slot, p.user_a, pa.username, p.user_b, pb.username,
         (p.user_b is null),
         coalesce((select auth.uid()) in (p.user_a, p.user_b), false)
  from public.league_h2h_pairings p
  join public.profiles pa on pa.id = p.user_a
  left join public.profiles pb on pb.id = p.user_b
  where p.league_id = p_league_id
  order by p.round_number,
           coalesce((select auth.uid()) in (p.user_a, p.user_b), false) desc,
           p.slot
$$;

-- 2) risultati degli scontri (calcolati, mai salvati) ---------------------------------------
-- prov_* = punti del turno con le partite in corso e finite; final_* = solo partite finite.
-- h2h_pts_* (3/1/0) solo a turno 'concluso' (tutte le partite finite); il riposo vale 0.
create or replace function public.h2h_results(p_league_id uuid)
returns table (
  round_number int,
  slot smallint,
  user_a uuid,
  user_b uuid,
  is_rest boolean,
  round_state text,
  prov_a int,
  prov_b int,
  final_a int,
  final_b int,
  h2h_pts_a int,
  h2h_pts_b int
)
language sql
stable
set search_path = public
as $$
  with p as (
    select * from public.league_h2h_pairings where league_id = p_league_id
  ),
  pts as (
    select ps.user_id, ps.round_number,
           coalesce(sum(ps.points), 0)::int as prov,
           coalesce(sum(ps.points_final), 0)::int as fin
    from public.prediction_scores ps
    where ps.user_id in (select user_a from p union select user_b from p where user_b is not null)
      and ps.round_number in (select round_number from p)
    group by ps.user_id, ps.round_number
  )
  select p.round_number, p.slot, p.user_a, p.user_b, (p.user_b is null), st.s,
         coalesce(a.prov, 0), coalesce(b.prov, 0), coalesce(a.fin, 0), coalesce(b.fin, 0),
         case when p.user_b is null then 0
              when st.s <> 'concluso' then null
              when coalesce(a.fin, 0) > coalesce(b.fin, 0) then 3
              when coalesce(a.fin, 0) = coalesce(b.fin, 0) then 1
              else 0 end,
         case when p.user_b is null then 0
              when st.s <> 'concluso' then null
              when coalesce(b.fin, 0) > coalesce(a.fin, 0) then 3
              when coalesce(a.fin, 0) = coalesce(b.fin, 0) then 1
              else 0 end
  from p
  cross join lateral (select public.round_play_state(p.round_number) as s) st
  left join pts a on a.user_id = p.user_a and a.round_number = p.round_number
  left join pts b on b.user_id = p.user_b and b.round_number = p.round_number
  order by p.round_number, p.slot
$$;

-- 3) segnaposto per gli spareggi 3 e 4 (pronostici stagionali non ancora esistenti) --------------
-- Quando arrivano i pronostici stagionali cambiano SOLO questi tre corpi (e i loro test).
create or replace function public.h2h_season_winner_ok(p_league_id uuid, p_user_id uuid)
returns boolean language sql stable set search_path = public as $$ select false $$;
create or replace function public.h2h_season_scorer_ok(p_league_id uuid, p_user_id uuid)
returns boolean language sql stable set search_path = public as $$ select false $$;
create or replace function public.h2h_season_ready(p_league_id uuid)
returns boolean language sql stable set search_path = public as $$ select false $$;

-- 4) classifica scontri: si aggiorna SOLO a turno concluso ----------------------------------------
-- Ordine: 1 punti scontri, 2 punti pronostici totali dal turno di partenza (solo partite
-- finite, turni conclusi), 3 vincitore, 4 capocannoniere (segnaposto), 5 risultati esatti, 6 esiti.
-- Pari merito su tutti i criteri = stesso rank e tied = true (7: premio diviso).
-- `giocati` esclude i turni di riposo; `riposi` li conta (solo turni conclusi).
create or replace function public.h2h_standings(p_league_id uuid)
returns table (
  user_id uuid,
  username text,
  crest_pattern text,
  pt_scontri int,
  giocati int,
  vinti int,
  pareggiati int,
  persi int,
  riposi int,
  pt_totali int,
  esatti int,
  esiti int,
  winner_ok boolean,
  scorer_ok boolean,
  rank bigint,
  tied boolean,
  is_final boolean
)
language sql
stable
set search_path = public
as $$
  with sched as (
    select s.start_round from public.league_h2h_schedule s
    where s.league_id = p_league_id and s.status = 'avviata'
  ),
  res as (select * from public.h2h_results(p_league_id)),
  sides as (
    select r.user_a as uid, r.is_rest, r.round_state, r.h2h_pts_a as pts from res r
    union all
    select r.user_b, false, r.round_state, r.h2h_pts_b from res r where r.user_b is not null
  ),
  h as (
    select uid,
           coalesce(sum(pts) filter (where round_state = 'concluso' and not is_rest), 0)::int as pt_scontri,
           (count(*) filter (where round_state = 'concluso' and not is_rest))::int as giocati,
           (count(*) filter (where round_state = 'concluso' and not is_rest and pts = 3))::int as vinti,
           (count(*) filter (where round_state = 'concluso' and not is_rest and pts = 1))::int as pareggiati,
           (count(*) filter (where round_state = 'concluso' and not is_rest and pts = 0))::int as persi,
           (count(*) filter (where round_state = 'concluso' and is_rest))::int as riposi
    from sides group by uid
  ),
  t as (
    -- criteri 2, 5 e 6: solo turni 'concluso' (altrimenti l'ordine cambierebbe partita per partita)
    select ps.user_id as uid,
           coalesce(sum(ps.points_final), 0)::int as pt_totali,
           (count(*) filter (where ps.points_final = 3))::int as esatti,
           (count(*) filter (where ps.points_final = 1))::int as esiti
    from public.prediction_scores ps, sched
    where ps.round_number >= sched.start_round
      and ps.round_number in (select r.round_number from public.rounds r where public.round_play_state(r.round_number) = 'concluso')
      and ps.user_id in (select lm.user_id from public.league_members lm where lm.league_id = p_league_id)
    group by ps.user_id
  ),
  base as (
    select lm.user_id, pr.username, pr.crest_pattern,
           coalesce(h.pt_scontri, 0) as pt_scontri, coalesce(h.giocati, 0) as giocati,
           coalesce(h.vinti, 0) as vinti, coalesce(h.pareggiati, 0) as pareggiati,
           coalesce(h.persi, 0) as persi, coalesce(h.riposi, 0) as riposi,
           coalesce(t.pt_totali, 0) as pt_totali, coalesce(t.esatti, 0) as esatti, coalesce(t.esiti, 0) as esiti,
           public.h2h_season_winner_ok(p_league_id, lm.user_id) as winner_ok,
           public.h2h_season_scorer_ok(p_league_id, lm.user_id) as scorer_ok
    from public.league_members lm
    join public.profiles pr on pr.id = lm.user_id
    left join h on h.uid = lm.user_id
    left join t on t.uid = lm.user_id
    where lm.league_id = p_league_id and exists (select 1 from sched)
  )
  select b.user_id, b.username, b.crest_pattern, b.pt_scontri, b.giocati, b.vinti, b.pareggiati, b.persi, b.riposi,
         b.pt_totali, b.esatti, b.esiti, b.winner_ok, b.scorer_ok,
         rank() over (order by b.pt_scontri desc, b.pt_totali desc, b.winner_ok desc, b.scorer_ok desc, b.esatti desc, b.esiti desc),
         (count(*) over (partition by b.pt_scontri, b.pt_totali, b.winner_ok, b.scorer_ok, b.esatti, b.esiti)) > 1,
         ((select bool_and(r.round_state = 'concluso') from res r) is true) and public.h2h_season_ready(p_league_id)
  from base b
  order by 15, b.pt_scontri desc, b.pt_totali desc, b.username
$$;

-- 5) dettaglio di uno scontro: partita per partita ------------------------------------------------
-- points = provvisori (in corso e finite), points_final = solo finite. Mai calcolati dal client.
--  - partita finita senza pronostico: points = points_final = 0 (mai null)
--  - partita non finita senza pronostico: null
--  - pronostico dell'altro nascosto (turno non ancora bloccato) o non fatto: pred_* null in
--    entrambi i casi; li distingue `round_locked` (prima del blocco = nascosto, dopo = non fatto).
create or replace function public.h2h_match_detail(p_league_id uuid, p_round int, p_slot smallint)
returns table (
  match_id text,
  home text,
  away text,
  kickoff timestamptz,
  match_status text,
  actual_home int,
  actual_away int,
  round_locked boolean,
  pred_home_a int,
  pred_away_a int,
  points_a int,
  points_final_a int,
  pred_home_b int,
  pred_away_b int,
  points_b int,
  points_final_b int
)
language sql
stable
set search_path = public
as $$
  select m.id, m.home, m.away, m.kickoff, m.status, m.home_goals, m.away_goals,
         (now() >= r.locks_at),
         pa.pred_home, pa.pred_away,
         coalesce(pa.points, case when m.status = 'finita' then 0 end),
         coalesce(pa.points_final, case when m.status = 'finita' then 0 end),
         pb.pred_home, pb.pred_away,
         case when p.user_b is not null then coalesce(pb.points, case when m.status = 'finita' then 0 end) end,
         case when p.user_b is not null then coalesce(pb.points_final, case when m.status = 'finita' then 0 end) end
  from public.league_h2h_pairings p
  join public.rounds r on r.round_number = p.round_number
  join public.matches m on m.round_number = p.round_number
  left join public.prediction_scores pa on pa.match_id = m.id and pa.user_id = p.user_a
  left join public.prediction_scores pb on pb.match_id = m.id and pb.user_id = p.user_b
  where p.league_id = p_league_id and p.round_number = p_round and p.slot = p_slot
  order by m.kickoff, m.id
$$;

-- 6) privilegi -----------------------------------------------------------------------------------
revoke all on function public.h2h_pairings(uuid) from public, anon;
revoke all on function public.h2h_results(uuid) from public, anon;
revoke all on function public.h2h_standings(uuid) from public, anon;
revoke all on function public.h2h_match_detail(uuid, int, smallint) from public, anon;
revoke all on function public.h2h_season_winner_ok(uuid, uuid) from public, anon;
revoke all on function public.h2h_season_scorer_ok(uuid, uuid) from public, anon;
revoke all on function public.h2h_season_ready(uuid) from public, anon;
grant execute on function public.h2h_pairings(uuid) to authenticated;
grant execute on function public.h2h_results(uuid) to authenticated;
grant execute on function public.h2h_standings(uuid) to authenticated;
grant execute on function public.h2h_match_detail(uuid, int, smallint) to authenticated;
grant execute on function public.h2h_season_winner_ok(uuid, uuid) to authenticated;
grant execute on function public.h2h_season_scorer_ok(uuid, uuid) to authenticated;
grant execute on function public.h2h_season_ready(uuid) to authenticated;
