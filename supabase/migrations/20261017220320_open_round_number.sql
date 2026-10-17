-- APPLICATA al database il 2026-10-17 (apply_migration, versione 20261017220320).
-- Dopo l'applicazione: security.sql aggiornato e rilanciato per intero (159 test,
-- 0 falliti), advisor di sicurezza e performance lanciati.
--
-- Introduce open_round_number() = turno aperto ai pronostici (il più basso con
-- locks_at nel futuro, NULL se non ce ne sono) e la usa in create_league e nella
-- vista calendar. current_round_number() resta com'è (primo turno non completato)
-- ma non è più usata per decidere dove si pronostica.
--
-- Contenuto:
--   1) open_round_number()
--   2) create_league: start_round >= open_round_number()
--   3) vista calendar: 'corrente' = open_round_number(); nuovo stato 'in_corso'
--   4) EXECUTE solo ad authenticated su current_round_number() e open_round_number()
--
-- I test di supabase/tests/security.sql sono stati aggiornati di conseguenza
-- (create_league sul turno aperto, P4a, N1-N4, matrici di privilegi).

-- 1) turno aperto ai pronostici --------------------------------------------

create or replace function public.open_round_number()
returns integer
language sql
stable
set search_path to 'public'
as $function$
  select min(r.round_number) from public.rounds r where r.locks_at > now()
$function$;

-- 2) create_league: il turno di partenza deve essere aperto -----------------

create or replace function public.create_league(p_name text, p_visibility text, p_start_round integer)
returns uuid
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_uid uuid := (select auth.uid());
  v_name text := trim(p_name);
  v_open int := public.open_round_number();
  v_league_id uuid;
  v_code text;
begin
  if v_uid is null then
    raise exception 'non autenticato';
  end if;
  if p_visibility not in ('private','public') then
    raise exception 'visibilità non valida';
  end if;
  if char_length(v_name) < 3 or char_length(v_name) > 40 then
    raise exception 'il nome deve essere tra 3 e 40 caratteri';
  end if;
  if not exists (select 1 from public.rounds where round_number = p_start_round) then
    raise exception 'turno di partenza inesistente';
  end if;
  if v_open is null then
    raise exception 'nessun turno aperto: impossibile creare una lega';
  end if;
  if p_start_round < v_open then
    raise exception 'il turno di partenza non può essere già chiuso';
  end if;

  insert into public.leagues (name, visibility, start_round, created_by)
  values (v_name, p_visibility, p_start_round, v_uid)
  returning id into v_league_id;

  insert into public.league_members (league_id, user_id, role)
  values (v_league_id, v_uid, 'owner');

  if p_visibility = 'private' then
    loop
      v_code := public.generate_invite_code();
      begin
        insert into public.league_invites (league_id, code) values (v_league_id, v_code);
        exit;
      exception when unique_violation then
        -- codice già usato altrove: riprova con uno nuovo
      end;
    end loop;
  end if;

  return v_league_id;
end;
$function$;

-- 3) vista calendar: un solo turno 'corrente' (= aperto) + stato 'in_corso' --
-- Colonne e ordine invariati. Stati:
--   giocato   tutte le partite del turno hanno un risultato
--   corrente  open_round_number() (aperto ai pronostici)
--   in_corso  turno chiuso (locks_at passato) ma con partite senza risultato
--   futuro    tutti gli altri (non ancora aperti)

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
      where m2.round_number = m.round_number and m2.home_goals is null
    ) then 'giocato'
    when m.round_number = public.open_round_number() then 'corrente'
    when r.locks_at <= now() then 'in_corso'
    else 'futuro'
  end as round_status
from public.matches m
join public.rounds r on r.round_number = m.round_number;

-- 4) privilegi: solo authenticated (mai anon/public) -------------------------

revoke all on function public.open_round_number() from public, anon;
grant execute on function public.open_round_number() to authenticated;

revoke all on function public.current_round_number() from public, anon;
grant execute on function public.current_round_number() to authenticated;

revoke all on function public.create_league(text, text, integer) from public, anon;
grant execute on function public.create_league(text, text, integer) to authenticated;

revoke all on public.calendar from anon, public;
grant select on public.calendar to authenticated;
