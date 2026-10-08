-- Fase 4: leghe private e pubbliche, classifica per lega.
--
-- apply_migration è andato in timeout (file troppo grande / troppe
-- CREATE FUNCTION in una volta, non un lock: verificato con pg_stat_activity
-- e nessun oggetto risultava creato). Da incollare a mano nell'SQL Editor di
-- Supabase, in un colpo solo (è già tutto in una transazione implicita: se
-- una riga fallisce, nulla viene applicato).

-- ===================== TABELLE =====================

create table public.leagues (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(name) >= 3 and char_length(name) <= 40),
  visibility text not null check (visibility in ('private','public')),
  start_round int not null references public.rounds(round_number),
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now()
);

create table public.league_members (
  league_id uuid not null references public.leagues(id) on delete cascade,
  user_id uuid not null references public.profiles(id),
  role text not null check (role in ('owner','member')),
  joined_at timestamptz not null default now(),
  primary key (league_id, user_id)
);
create index league_members_user_id_idx on public.league_members(user_id);

create table public.league_invites (
  league_id uuid primary key references public.leagues(id) on delete cascade,
  code text not null unique
);

-- Interna: nessun accesso a authenticated/anon, nemmeno in lettura. Solo le
-- funzioni SECURITY DEFINER (eseguite come owner della tabella) la toccano.
create table public.league_join_attempts (
  user_id uuid not null,
  attempted_at timestamptz not null default now()
);
create index league_join_attempts_user_window_idx on public.league_join_attempts(user_id, attempted_at);

alter table public.leagues enable row level security;
alter table public.league_members enable row level security;
alter table public.league_invites enable row level security;
alter table public.league_join_attempts enable row level security;

revoke all on public.leagues from anon, public, authenticated;
revoke all on public.league_members from anon, public, authenticated;
revoke all on public.league_invites from anon, public, authenticated;
revoke all on public.league_join_attempts from anon, public, authenticated;

grant select on public.leagues to authenticated;
grant select on public.league_members to authenticated;
grant select on public.league_invites to authenticated;
-- league_join_attempts: nessun grant ad authenticated/anon, di proposito.


-- ===================== FUNZIONI HELPER (anti-ricorsione RLS) =====================

create or replace function public.is_league_member(p_league_id uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from public.league_members
    where league_id = p_league_id and user_id = (select auth.uid())
  );
$$;

create or replace function public.is_league_owner(p_league_id uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from public.league_members
    where league_id = p_league_id and user_id = (select auth.uid()) and role = 'owner'
  );
$$;

-- Non serve security definer: si appoggia alla RLS di league_members, che
-- lascia vedere la propria riga e quella di "theirs" per lo stesso league_id
-- (stesso league_id => is_league_member vero per il chiamante su entrambe).
create or replace function public.shares_league_with(p_other_user uuid)
returns boolean
language sql
security invoker
set search_path = public
stable
as $$
  select exists (
    select 1
    from public.league_members mine
    join public.league_members theirs on theirs.league_id = mine.league_id
    where mine.user_id = (select auth.uid())
      and theirs.user_id = p_other_user
  );
$$;

revoke all on function public.is_league_member(uuid) from public, anon;
revoke all on function public.is_league_owner(uuid) from public, anon;
revoke all on function public.shares_league_with(uuid) from public, anon;
grant execute on function public.is_league_member(uuid) to authenticated;
grant execute on function public.is_league_owner(uuid) to authenticated;
grant execute on function public.shares_league_with(uuid) to authenticated;


-- ===================== POLICY (solo SELECT, nessuna scrittura diretta) =====================

create policy "leagues select public or member" on public.leagues
for select to authenticated
using ( visibility = 'public' or public.is_league_member(id) );

create policy "league_members select if member" on public.league_members
for select to authenticated
using ( public.is_league_member(league_id) );

create policy "league_invites select if owner" on public.league_invites
for select to authenticated
using ( public.is_league_owner(league_id) );


-- ===================== FUNZIONI DI SCRITTURA (security definer, no policy diretta) =====================

create or replace function public.generate_invite_code()
returns text
language sql
set search_path = public
as $$
  -- floor(), non ::int: il cast arrotonda (es. random()=0.999... * 31 = 31.0
  -- troncato male), facendo saltare un carattere circa 1 volta su 8.
  select string_agg(substr(alphabet, floor(random() * length(alphabet))::int + 1, 1), '')
  from (select 'ABCDEFGHJKMNPQRSTUVWXYZ23456789' as alphabet) a,
       generate_series(1, 8);
$$;
revoke all on function public.generate_invite_code() from public, anon, authenticated;

create or replace function public.create_league(p_name text, p_visibility text, p_start_round int)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := (select auth.uid());
  v_name text := trim(p_name);
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
  if p_start_round < public.current_round_number() then
    raise exception 'il turno di partenza non può essere nel passato';
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
$$;

-- 'ok' | 'already_member' | 'invalid' (codice errato e limite tentativi
-- restituiscono lo stesso esito 'invalid': nessuna eccezione, altrimenti il
-- rollback automatico annullerebbe anche l'insert del tentativo falliente.
-- Il codice è normalizzato con upper(trim(...)) prima del confronto: minuscole
-- o spazi incollati per errore non devono contare come tentativo falliente.
create or replace function public.join_private_league(p_code text)
returns text
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
    return 'invalid';
  end if;

  select count(*) into v_recent_failures
  from public.league_join_attempts
  where user_id = v_uid and attempted_at > now() - interval '10 minutes';

  if v_recent_failures >= 10 then
    return 'invalid';
  end if;

  select league_id into v_league_id from public.league_invites where code = upper(trim(p_code));

  if v_league_id is null then
    insert into public.league_join_attempts (user_id) values (v_uid);
    return 'invalid';
  end if;

  if exists (select 1 from public.league_members where league_id = v_league_id and user_id = v_uid) then
    return 'already_member';
  end if;

  insert into public.league_members (league_id, user_id, role) values (v_league_id, v_uid, 'member');
  return 'ok';
end;
$$;

create or replace function public.join_public_league(p_league_id uuid)
returns text -- 'ok' | 'already_member' | 'not_found' (anche per una lega privata: non si rivela la sua esistenza/visibilità a chi tenta di unirsi senza codice)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := (select auth.uid());
  v_visibility text;
begin
  if v_uid is null then
    return 'not_found';
  end if;

  select visibility into v_visibility from public.leagues where id = p_league_id;

  if v_visibility is null then
    return 'not_found';
  end if;
  if v_visibility <> 'public' then
    return 'not_found';
  end if;
  if exists (select 1 from public.league_members where league_id = p_league_id and user_id = v_uid) then
    return 'already_member';
  end if;

  insert into public.league_members (league_id, user_id, role) values (p_league_id, v_uid, 'member');
  return 'ok';
end;
$$;

create or replace function public.leave_league(p_league_id uuid)
returns text -- 'ok' | 'not_member' | 'owner_cannot_leave'
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := (select auth.uid());
  v_role text;
begin
  select role into v_role from public.league_members where league_id = p_league_id and user_id = v_uid;
  if v_role is null then
    return 'not_member';
  end if;
  if v_role = 'owner' then
    return 'owner_cannot_leave';
  end if;
  delete from public.league_members where league_id = p_league_id and user_id = v_uid;
  return 'ok';
end;
$$;

create or replace function public.remove_league_member(p_league_id uuid, p_user_id uuid)
returns text -- 'ok' | 'forbidden' | 'target_is_owner' | 'not_member'
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := (select auth.uid());
begin
  if not public.is_league_owner(p_league_id) then
    return 'forbidden';
  end if;
  if p_user_id = v_uid then
    return 'forbidden';
  end if;
  if not exists (select 1 from public.league_members where league_id = p_league_id and user_id = p_user_id) then
    return 'not_member';
  end if;
  if exists (select 1 from public.league_members where league_id = p_league_id and user_id = p_user_id and role = 'owner') then
    return 'target_is_owner';
  end if;
  delete from public.league_members where league_id = p_league_id and user_id = p_user_id;
  return 'ok';
end;
$$;

-- Ritorna il nuovo codice (8 caratteri dall'alfabeto senza ambigui, non può
-- collidere con i sentinel 'forbidden'/'not_private') oppure il sentinel di errore.
create or replace function public.regenerate_invite_code(p_league_id uuid)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_visibility text;
  v_new_code text;
begin
  if not public.is_league_owner(p_league_id) then
    return 'forbidden';
  end if;
  select visibility into v_visibility from public.leagues where id = p_league_id;
  if v_visibility <> 'private' then
    return 'not_private';
  end if;
  loop
    v_new_code := public.generate_invite_code();
    begin
      update public.league_invites set code = v_new_code where league_id = p_league_id;
      exit;
    exception when unique_violation then
    end;
  end loop;
  return v_new_code;
end;
$$;

create or replace function public.delete_league(p_league_id uuid)
returns text -- 'ok' | 'forbidden'
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_league_owner(p_league_id) then
    return 'forbidden';
  end if;
  delete from public.leagues where id = p_league_id;
  return 'ok';
end;
$$;

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
$$;

create or replace function public.list_public_leagues()
returns table (
  id uuid,
  name text,
  member_count bigint,
  owner_username text,
  start_round int
)
language sql
security definer
set search_path = public
stable
as $$
  select l.id, l.name, count(m.user_id) as member_count,
    max(pr.username) filter (where m.role = 'owner') as owner_username,
    l.start_round
  from public.leagues l
  join public.league_members m on m.league_id = l.id
  join public.profiles pr on pr.id = m.user_id
  where l.visibility = 'public'
  group by l.id, l.name, l.start_round;
$$;

revoke all on function public.create_league(text, text, int) from public, anon;
revoke all on function public.join_private_league(text) from public, anon;
revoke all on function public.join_public_league(uuid) from public, anon;
revoke all on function public.leave_league(uuid) from public, anon;
revoke all on function public.remove_league_member(uuid, uuid) from public, anon;
revoke all on function public.regenerate_invite_code(uuid) from public, anon;
revoke all on function public.delete_league(uuid) from public, anon;
revoke all on function public.league_leaderboard(uuid) from public, anon;
revoke all on function public.list_public_leagues() from public, anon;

grant execute on function public.create_league(text, text, int) to authenticated;
grant execute on function public.join_private_league(text) to authenticated;
grant execute on function public.join_public_league(uuid) to authenticated;
grant execute on function public.leave_league(uuid) to authenticated;
grant execute on function public.remove_league_member(uuid, uuid) to authenticated;
grant execute on function public.regenerate_invite_code(uuid) to authenticated;
grant execute on function public.delete_league(uuid) to authenticated;
grant execute on function public.league_leaderboard(uuid) to authenticated;
grant execute on function public.list_public_leagues() to authenticated;


-- ===================== AGGIORNA POLICY ESISTENTE: predictions dopo il lock solo tra chi condivide una lega =====================

alter policy "predictions select own or after lock" on public.predictions
using ( (select auth.uid()) = user_id or (not round_is_open(match_id) and public.shares_league_with(user_id)) );
