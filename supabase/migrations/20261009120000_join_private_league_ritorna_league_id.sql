-- Fase 4: join_private_league ritorna anche league_id (non solo l'esito),
-- per permettere al frontend di aprire la lega appena raggiunta dopo "Ho un
-- codice" senza dover rileggere league_invites (vietato ai non-owner dalla
-- RLS esistente, per disegno: solo il creatore legge il codice).
--
-- Cambia il TIPO di ritorno (da text a table), quindi non basta CREATE OR
-- REPLACE: va fatto DROP + CREATE. Stessa logica di prima, stesso
-- SECURITY DEFINER/search_path, stessi grant: solo il return cambia forma.

drop function public.join_private_league(text);

-- 'ok' | 'already_member' | 'invalid'. league_id valorizzato SOLO per 'ok'
-- e 'already_member'; NULL per 'invalid' (nessuna informazione aggiuntiva
-- rivelata su un tentativo falliente, come già per l'esito testuale).
create function public.join_private_league(p_code text)
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

  if exists (select 1 from public.league_members lm where lm.league_id = v_league_id and lm.user_id = v_uid) then
    return query select 'already_member'::text, v_league_id;
    return;
  end if;

  insert into public.league_members (league_id, user_id, role) values (v_league_id, v_uid, 'member');
  return query select 'ok'::text, v_league_id;
end;
$$;

revoke all on function public.join_private_league(text) from public, anon;
grant execute on function public.join_private_league(text) to authenticated;
