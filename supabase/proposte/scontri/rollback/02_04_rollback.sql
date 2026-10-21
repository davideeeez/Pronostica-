-- RIPRISTINO delle migrazioni 02, 03a e 04 (oggetti NUOVI: non c'era nulla da conservare).
-- Eseguire PRIMA 03_rollback.sql e 01_rollback.sql solo se serve tornare del tutto indietro.
-- Cancella anche i calendari delle leghe a scontri già avviate.
drop function if exists public.h2h_match_detail(uuid, int, smallint);
drop function if exists public.h2h_standings(uuid);
drop function if exists public.h2h_results(uuid);
drop function if exists public.h2h_pairings(uuid);
drop function if exists public.h2h_season_ready(uuid);
drop function if exists public.h2h_season_scorer_ok(uuid, uuid);
drop function if exists public.h2h_season_winner_ok(uuid, uuid);
drop function if exists public.h2h_league_state(uuid);
drop function if exists public.h2h_generate_schedule(uuid);
drop function if exists public.create_h2h_league(text, int);
drop function if exists public.h2h_is_locked(uuid);
drop function if exists public.round_live_number();
drop function if exists public.round_play_state(int);
drop table if exists public.league_h2h_pairings;
drop table if exists public.league_h2h_schedule;
drop function if exists public.league_h2h_pairings_check();
drop trigger if exists leagues_mode_immutable on public.leagues;
drop function if exists public.leagues_mode_immutable();
alter table public.leagues drop constraint if exists leagues_scontri_solo_private;
alter table public.leagues drop constraint if exists leagues_mode_check;
alter table public.leagues drop column if exists mode;
