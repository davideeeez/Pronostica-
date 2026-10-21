-- Applicata in produzione il 2026-10-21 (MCP apply_migration). Definizioni di turno, creazione, calendario a cerchio e blocco degli ingressi.

-- 1) definizioni di turno (una sola volta, riusate ovunque) ------------------------------
-- Stato di gioco di un turno, per le CLASSIFICHE: 'concluso' solo se tutte e 10 le
-- partite sono in `matches` e finite (anche un recupero rinviato lontano tiene il turno aperto).
create or replace function public.round_play_state(p_round int)
returns text
language sql
stable
set search_path = public
as $$
  select case
    when r.locks_at is null or now() < r.locks_at then 'non_disputato'
    when (select count(*) from public.matches m where m.round_number = p_round) = 10
         and not exists (select 1 from public.matches m where m.round_number = p_round and m.status <> 'finita')
      then 'concluso'
    when exists (select 1 from public.matches m where m.round_number = p_round) then 'in_corso'
    else 'non_disputato'
  end
  from (select 1) x
  left join public.rounds r on r.round_number = p_round
$$;

-- Turno "in svolgimento" per la HOME: l'ultimo turno bloccato con almeno una partita
-- non finita il cui calcio d'inizio cade NELLA FINESTRA NORMALE (dal blocco a +96 ore).
-- Nessuna soglia sull'orario: finché il risultato non è inserito (e i punti assegnati)
-- la Home resta su "Segui lo scontro". Una partita rinviata e riprogrammata oltre la
-- finestra non conta.
create or replace function public.round_live_number()
returns int
language sql
stable
set search_path = public
as $$
  select max(r.round_number)
  from public.rounds r
  where r.locks_at <= now()
    and exists (
      select 1 from public.matches m
      where m.round_number = r.round_number
        and m.kickoff <= r.locks_at + interval '96 hours'
        and m.status <> 'finita'
    )
$$;

-- 2) lega bloccata? (solo scontri, dopo locks_at del turno di partenza) ---------------------
-- clock_timestamp() e non now(): una transazione iniziata prima del blocco e rimasta in
-- attesa del lock di riga ha now() "congelato" prima di locks_at, e potrebbe inserire un
-- membro dopo la generazione del calendario.
create or replace function public.h2h_is_locked(p_league_id uuid)
returns boolean
language sql
volatile
set search_path = public
as $$
  select coalesce(
    (select l.mode = 'scontri' and clock_timestamp() >= r.locks_at
     from public.leagues l join public.rounds r on r.round_number = l.start_round
     where l.id = p_league_id),
    false)
$$;

-- 3) creazione: nuova funzione, create_league resta com'è (niente overload) ----------------
create or replace function public.create_h2h_league(p_name text, p_start_round int)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
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
  if char_length(v_name) < 3 or char_length(v_name) > 40 then
    raise exception 'il nome deve essere tra 3 e 40 caratteri';
  end if;
  if p_start_round is null or p_start_round < 1 or p_start_round > 38 then
    raise exception 'turno di partenza non valido';
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

  insert into public.leagues (name, visibility, mode, start_round, created_by)
  values (v_name, 'private', 'scontri', p_start_round, v_uid)
  returning id into v_league_id;

  insert into public.league_members (league_id, user_id, role)
  values (v_league_id, v_uid, 'owner');

  loop
    v_code := public.generate_invite_code();
    begin
      insert into public.league_invites (league_id, code) values (v_league_id, v_code);
      exit;
    exception when unique_violation then
      null; -- codice già usato altrove: riprova con uno nuovo
    end;
  end loop;

  return v_league_id;
end;
$$;

-- 4) calendario a cerchio (interna: la chiama solo h2h_league_state) -------------------------
-- Membri ordinati per (joined_at, user_id). Con N dispari si aggiunge un membro
-- fantasma in coda: chi lo incontra riposa; il ciclo dura N turni (N-1 se pari).
-- Posizione 0 fissa, le altre ruotano a destra di (turno - partenza) mod ciclo;
-- si accoppia la posizione i con la size-1-i. Dal turno di partenza al 38; finito
-- il ciclo si riparte dal primo abbinamento (l'ultimo ciclo può restare parziale).
create or replace function public.h2h_generate_schedule(p_league_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_start int;
  v_members uuid[];
  v_n int;
  v_size int;
  v_cycle int;
  v_k int;
  v_c int;
  v_i int;
  v_arr uuid[];
  v_a uuid;
  v_b uuid;
begin
  -- serializza con ingressi/uscite e con un'altra prima lettura
  perform 1 from public.leagues where id = p_league_id for update;
  if exists (select 1 from public.league_h2h_schedule where league_id = p_league_id) then
    return;
  end if;
  if not public.h2h_is_locked(p_league_id) then
    raise exception 'lega non ancora bloccata';
  end if;

  select l.start_round into v_start from public.leagues l where l.id = p_league_id;
  select array_agg(m.user_id order by m.joined_at, m.user_id) into v_members
  from public.league_members m where m.league_id = p_league_id;
  v_n := coalesce(array_length(v_members, 1), 0);

  if v_n < 2 then
    insert into public.league_h2h_schedule (league_id, status, start_round, member_count, cycle_length)
    values (p_league_id, 'non_avviata', v_start, v_n, 0);
    return;
  end if;

  v_size := v_n + (v_n % 2);
  v_cycle := v_size - 1;
  insert into public.league_h2h_schedule (league_id, status, start_round, member_count, cycle_length)
  values (p_league_id, 'avviata', v_start, v_n, v_cycle);

  for v_k in 0 .. (38 - v_start) loop
    v_c := v_k % v_cycle;
    v_arr := array[v_members[1]];
    for v_i in 2 .. v_size loop
      v_arr := array_append(v_arr, v_members[((v_i - 2 - v_c) % (v_size - 1) + (v_size - 1)) % (v_size - 1) + 2]);
    end loop;
    for v_i in 1 .. v_size / 2 loop
      v_a := v_arr[v_i];
      v_b := v_arr[v_size + 1 - v_i];
      insert into public.league_h2h_pairings (league_id, round_number, slot, user_a, user_b)
      values (p_league_id, v_start + v_k, v_i - 1,
              coalesce(v_a, v_b),
              case when v_a is null or v_b is null then null else v_b end);
    end loop;
  end loop;
end;
$$;

-- 5) stato della lega a scontri: è anche il punto in cui il calendario viene creato ------------
-- Va chiamata (POST) all'apertura della lega: dopo il blocco genera il calendario una
-- volta sola. Solo membri. Per la Home restituisce anche lo stato e lo scontro da seguire.
create or replace function public.h2h_league_state(p_league_id uuid)
returns table (
  mode text,
  start_round int,
  locks_at timestamptz,
  is_locked boolean,
  status text,            -- 'in_attesa' | 'avviata' | 'non_avviata' (null per le leghe a classifica)
  member_count int,
  warn_not_starting boolean,
  home_state text,        -- 'pronostica' | 'segui' | 'riposo' | 'non_avviata' (null per le leghe a classifica)
  live_round int,
  live_slot smallint
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := (select auth.uid());
  v_mode text;
  v_start int;
  v_locks timestamptz;
  v_locked boolean;
  v_members int;
  v_sched text;
  v_home text := 'pronostica';
  v_live int;
  v_live_round int;
  v_live_slot smallint;
  v_is_rest boolean;
begin
  if v_uid is null or not public.is_league_member(p_league_id) then
    return;
  end if;

  select l.mode, l.start_round, r.locks_at into v_mode, v_start, v_locks
  from public.leagues l join public.rounds r on r.round_number = l.start_round
  where l.id = p_league_id;
  if v_mode is null then
    return;
  end if;

  select count(*) into v_members from public.league_members lm where lm.league_id = p_league_id;

  if v_mode <> 'scontri' then
    return query select v_mode, v_start, v_locks, (clock_timestamp() >= v_locks), null::text, v_members, false, null::text, null::int, null::smallint;
    return;
  end if;

  v_locked := clock_timestamp() >= v_locks;
  if v_locked then
    perform public.h2h_generate_schedule(p_league_id);
    select s.status into v_sched from public.league_h2h_schedule s where s.league_id = p_league_id;
    if v_sched = 'non_avviata' then
      v_home := 'non_avviata';
    else
      v_live := public.round_live_number();
      if v_live is not null and v_live >= v_start then
        select p.slot, (p.user_b is null) into v_live_slot, v_is_rest
        from public.league_h2h_pairings p
        where p.league_id = p_league_id and p.round_number = v_live and v_uid in (p.user_a, p.user_b);
        if found then
          v_live_round := v_live;
          v_home := case when v_is_rest then 'riposo' else 'segui' end;
        end if;
      end if;
    end if;
  end if;

  return query select v_mode, v_start, v_locks, v_locked,
                      case when not v_locked then 'in_attesa' else v_sched end,
                      v_members, (not v_locked and v_members < 2),
                      v_home, v_live_round, v_live_slot;
end;
$$;

-- 6) blocco di ingressi, uscite e rimozioni (solo leghe a scontri, dopo il blocco) -------------
-- Stesso tipo di ritorno di prima: CREATE OR REPLACE, nessun DROP.
create or replace function public.join_private_league(p_code text)
returns table (outcome text, league_id uuid)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := (select auth.uid());
  v_league_id uuid;
  v_recent_failures int;
begin
  if v_uid is null then
    return query select 'invalid'::text, null::uuid;
    return;
  end if;

  select count(*) into v_recent_failures
  from public.league_join_attempts lja
  where lja.user_id = v_uid and lja.attempted_at > now() - interval '10 minutes';

  if v_recent_failures >= 10 then
    return query select 'invalid'::text, null::uuid;
    return;
  end if;

  select li.league_id into v_league_id from public.league_invites li where li.code = upper(trim(p_code));

  if v_league_id is null then
    insert into public.league_join_attempts (user_id) values (v_uid);
    return query select 'invalid'::text, null::uuid;
    return;
  end if;

  perform 1 from public.leagues l where l.id = v_league_id for update;

  if exists (select 1 from public.league_members lm where lm.league_id = v_league_id and lm.user_id = v_uid) then
    return query select 'already_member'::text, v_league_id;
    return;
  end if;

  -- iscrizioni chiuse: la lega a scontri è partita (non è un tentativo fallito)
  if public.h2h_is_locked(v_league_id) then
    return query select 'closed'::text, null::uuid;
    return;
  end if;

  insert into public.league_members (league_id, user_id, role) values (v_league_id, v_uid, 'member');
  return query select 'ok'::text, v_league_id;
end;
$$;

-- 7) privilegi ----------------------------------------------------------------------------------
-- interne: nessun client (le chiamano solo funzioni SECURITY DEFINER dello stesso proprietario)
revoke all on function public.round_live_number() from public, anon, authenticated;
revoke all on function public.h2h_is_locked(uuid) from public, anon, authenticated;
revoke all on function public.h2h_generate_schedule(uuid) from public, anon, authenticated;
-- chiamabili dai client (round_play_state serve alle funzioni di lettura INVOKER della proposta 4)
revoke all on function public.round_play_state(int) from public, anon;
revoke all on function public.create_h2h_league(text, int) from public, anon;
revoke all on function public.h2h_league_state(uuid) from public, anon;
grant execute on function public.round_play_state(int) to authenticated;
grant execute on function public.create_h2h_league(text, int) to authenticated;
grant execute on function public.h2h_league_state(uuid) to authenticated;
-- join_private_league, leave_league, remove_league_member: CREATE OR REPLACE conserva i grant esistenti
