-- PROPOSTA 3b/5 — NON APPLICATA. Blocco di uscite e rimozioni (solo leghe a scontri, dopo il blocco).
-- Si applica con apply_migration (il DELETE nel corpo funzione non va provato via execute_sql).
-- Stesso tipo di ritorno di prima: CREATE OR REPLACE, nessun DROP; i grant esistenti restano.

create or replace function public.leave_league(p_league_id uuid)
returns text -- 'ok' | 'not_member' | 'owner_cannot_leave' | 'locked'
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
  perform 1 from public.leagues where id = p_league_id for update;
  if public.h2h_is_locked(p_league_id) then
    return 'locked';
  end if;
  delete from public.league_members where league_id = p_league_id and user_id = v_uid;
  return 'ok';
end;
$$;

create or replace function public.remove_league_member(p_league_id uuid, p_user_id uuid)
returns text -- 'ok' | 'forbidden' | 'target_is_owner' | 'not_member' | 'locked'
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
  perform 1 from public.leagues where id = p_league_id for update;
  if public.h2h_is_locked(p_league_id) then
    return 'locked';
  end if;
  delete from public.league_members where league_id = p_league_id and user_id = p_user_id;
  return 'ok';
end;
$$;
