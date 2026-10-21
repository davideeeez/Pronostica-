-- RIPRISTINO delle migrazioni 03a/03b (stato di produzione al 2026-10-21).
-- Prima si ripristinano le funzioni sostituite, poi (opzionale) si tolgono le nuove.
create or replace function public.join_private_league(p_code text)
returns table(outcome text, league_id uuid)
language plpgsql security definer set search_path to 'public' as $function$
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

  if exists (select 1 from public.league_members lm where lm.league_id = v_league_id and lm.user_id = v_uid) then
    return query select 'already_member'::text, v_league_id;
    return;
  end if;

  insert into public.league_members (league_id, user_id, role) values (v_league_id, v_uid, 'member');
  return query select 'ok'::text, v_league_id;
end;
$function$;

create or replace function public.leave_league(p_league_id uuid)
returns text language plpgsql security definer set search_path to 'public' as $function$
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
$function$;

create or replace function public.remove_league_member(p_league_id uuid, p_user_id uuid)
returns text language plpgsql security definer set search_path to 'public' as $function$
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
$function$;
