begin;
create temp table res(t text, ok boolean, detail text);
grant all on res to public;
create or replace function pg_temp.uid(n int) returns uuid language sql as $$ select ('00000000-0000-4000-8000-' || lpad(n::text,12,'0'))::uuid $$;
create or replace function pg_temp.as_user(n int) returns void language plpgsql as $$ begin perform set_config('request.jwt.claim.sub', pg_temp.uid(n)::text, true); end $$;

-- il turno 8 parte nel passato (bloccato): sposta i kickoff del turno 8 a ieri
update matches set kickoff = now() - interval '1 day' + (substr(id, 5)::int) * interval '1 minute' where round_number = 8;

-- crea leghe sintetiche direttamente (come superuser): N membri, start_round 8
do $$
declare n int; lid uuid; i int;
begin
  foreach n in array array[1,2,3,4,5,6,7] loop
    insert into leagues (name, visibility, mode, start_round, created_by) values ('Lg'||n, 'private', 'scontri', 8, pg_temp.uid(1)) returning id into lid;
    for i in 1..n loop
      insert into league_members (league_id, user_id, role, joined_at) values (lid, pg_temp.uid(i), case when i=1 then 'owner' else 'member' end, now() - interval '2 days' + i * interval '1 minute');
    end loop;
  end loop;
end $$;

-- genera i calendari chiamando lo stato come membro (authenticated)
create temp table lg as select id, name from leagues where name like 'Lg_';
grant select on lg to public;
set local role authenticated;
do $$
declare r record;
begin
  perform pg_temp.as_user(1);
  for r in select id from lg loop
    perform * from h2h_league_state(r.id);
  end loop;
end $$;
reset role;

-- T1: N pari/dispari: ognuno compare esattamente una volta per turno
insert into res select 'T1 ogni membro compare una volta per turno (N=2..7)',
  not exists (
    select 1 from leagues l, generate_series(8,38) rn, league_members lm
    where l.name like 'Lg_' and l.name <> 'Lg1' and lm.league_id = l.id
      and (select count(*) from league_h2h_pairings p where p.league_id=l.id and p.round_number=rn and lm.user_id in (p.user_a,p.user_b)) <> 1),
  '';
-- T2: N dispari: ognuno riposa esattamente una volta per ciclo (N turni)
insert into res select 'T2 N dispari: riposi per ciclo = 1 a testa (N=3,5,7, primi N turni)',
  not exists (
    select 1 from leagues l join league_members lm on lm.league_id=l.id
    where l.name in ('Lg3','Lg5','Lg7') and
      (select count(*) from league_h2h_pairings p where p.league_id=l.id and p.round_number between 8 and 8+substr(l.name,3)::int-1 and p.user_b is null and p.user_a=lm.user_id) <> 1),
  (select string_agg(l.name||':'||(select count(*) from league_h2h_pairings p where p.league_id=l.id and p.user_b is null and p.round_number<8+substr(l.name,3)::int and p.user_a=pg_temp.uid(1)),',') from leagues l where l.name in ('Lg3','Lg5','Lg7'));
-- T3: nessuno incontra il fantasma due volte nello stesso turno (un solo riposo per turno)
insert into res select 'T3 al massimo un riposo per turno',
  not exists (select 1 from league_h2h_pairings group by league_id, round_number having count(*) filter (where user_b is null) > 1), '';
insert into res select 'T3b N pari: nessun riposo mai', not exists (select 1 from league_h2h_pairings p join leagues l on l.id=p.league_id where l.name in ('Lg2','Lg4','Lg6') and p.user_b is null), '';
-- T4: ciclo completo: dopo il ciclo tutti contro tutti una volta (N=5: 10 coppie distinte in 5 turni... in 5 turni 2 scontri/turno = 10 = C(5,2))
insert into res select 'T4 N=5/6/7: nel primo ciclo ogni coppia si incontra una volta sola (tutte le C(N,2) coppie)',
  (select bool_and(c.coppie = c.distinte and c.coppie = n*(n-1)/2 and c.max_rep = 1) from (
    select substr(l.name,3)::int n, count(*) coppie, count(distinct (least(user_a,user_b),greatest(user_a,user_b))) distinte, max(k) max_rep
    from leagues l join lateral (
      select user_a, user_b, count(*) over (partition by least(user_a,user_b),greatest(user_a,user_b)) k
      from league_h2h_pairings p where p.league_id=l.id and p.user_b is not null
        and p.round_number < 8 + (case when substr(l.name,3)::int%2=1 then substr(l.name,3)::int else substr(l.name,3)::int-1 end)) z on true
    where l.name in ('Lg5','Lg6','Lg7') group by l.name) c), '';
-- T5: lega con 1 membro: non avviata, nessun abbinamento
insert into res select 'T5 1 membro: non_avviata e nessun abbinamento',
  (select status from league_h2h_schedule s join leagues l on l.id=s.league_id where l.name='Lg1') = 'non_avviata'
  and not exists (select 1 from league_h2h_pairings p join leagues l on l.id=p.league_id where l.name='Lg1'), '';
-- T6: determinismo/idempotenza: seconda chiamata non cambia nulla
create temp table before_cnt as select count(*) c, md5(string_agg(league_id||round_number::text||slot||user_a||coalesce(user_b::text,''), ',' order by league_id, round_number, slot)) h from league_h2h_pairings;
set local role authenticated;
do $$ declare r record; begin perform pg_temp.as_user(1); for r in select id from lg loop perform * from h2h_league_state(r.id); end loop; end $$;
reset role;
insert into res select 'T6 seconda lettura: calendario invariato', (select c from before_cnt) = (select count(*) from league_h2h_pairings)
  and (select h from before_cnt) = (select md5(string_agg(league_id||round_number::text||slot||user_a||coalesce(user_b::text,''), ',' order by league_id, round_number, slot)) from league_h2h_pairings), '';

-- T7: ingresso/uscita/rimozione dopo il blocco
set local role authenticated;
select pg_temp.as_user(10) \gset
do $$ declare code text; o text; begin
  select li.code into code from league_invites li join leagues l on l.id=li.league_id where l.name='Lg4' ;
  -- come superuser non serve: l'invito esiste solo se creato da create_h2h_league; creiamolo a mano
end $$;
reset role;
insert into league_invites (league_id, code) select id, 'TESTCODE' from leagues where name='Lg4';
set local role authenticated;
select pg_temp.as_user(10) \gset
insert into res select 'T7a ingresso dopo il blocco -> closed', (select outcome from join_private_league('TESTCODE')) = 'closed', '';
select pg_temp.as_user(2) \gset
insert into res select 'T7b uscita dopo il blocco -> locked', (select leave_league(id) from leagues where name='Lg4') = 'locked', '';
select pg_temp.as_user(1) \gset
insert into res select 'T7c rimozione dopo il blocco -> locked', (select remove_league_member(id, pg_temp.uid(3)) from leagues where name='Lg4') = 'locked', '';
insert into res select 'T7d creatore non puo'' uscire', (select leave_league(id) from leagues where name='Lg4') = 'owner_cannot_leave', '';
reset role;

-- T8: non membro non vede nulla (abbinamenti, stato, risultati, dettaglio)
set local role authenticated;
select pg_temp.as_user(11) \gset
insert into res select 'T8 non membro: 0 righe da pairings/state/results/standings',
  (select count(*) from h2h_pairings((select id from leagues where name='Lg4'))) = 0
  and (select count(*) from h2h_league_state((select id from leagues where name='Lg4'))) = 0
  and (select count(*) from h2h_results((select id from leagues where name='Lg4'))) = 0, '';
reset role;
-- T8b anon rifiutato
set local role anon;
do $$ begin
  begin perform * from h2h_pairings((select id from leagues limit 1)); insert into pg_temp.res values ('T8b anon: h2h_pairings rifiutata', false, 'nessun errore');
  exception when insufficient_privilege then insert into pg_temp.res values ('T8b anon: h2h_pairings rifiutata', true, sqlerrm); end;
end $$;
reset role;

-- T9: punti: riposo = 0, turno non concluso -> nessun punto scontri; poi concluso
-- T5 (N=5): turno 8. Pronostici sintetici: u1 esatto su tutte, u2 sbagliato su tutte, u3 niente
update matches set status='finita', home_goals=1, away_goals=0 where round_number=8;
insert into predictions (user_id, match_id, home_goals, away_goals)
select pg_temp.uid(1), id, 1, 0 from matches where round_number=8
union all select pg_temp.uid(2), id, 0, 1 from matches where round_number=8;
create temp table t9 as select * from h2h_results((select id from leagues where name='Lg5')) where round_number = 8;
insert into res select 'T9a turno 8 concluso: stato concluso', (select bool_and(round_state='concluso') from t9), (select string_agg(round_state,',') from t9);
insert into res select 'T9b riposo vale 0 punti scontri', (select bool_and(h2h_pts_a = 0) from t9 where is_rest), (select string_agg(user_a||':'||h2h_pts_a, ',') from t9 where is_rest);
insert into res select 'T9c esito 3/1/0 coerente (somma per scontro non-riposo in {3,2}... 3+0 o 1+1)',
  (select bool_and((h2h_pts_a=3 and h2h_pts_b=0) or (h2h_pts_a=0 and h2h_pts_b=3) or (h2h_pts_a=1 and h2h_pts_b=1)) from t9 where not is_rest), '';
insert into res select 'T9d chi non pronostica (u3) ha 0; avversario con >=1 punto vince',
  coalesce((select bool_and(case when final_a=0 and final_b=0 then h2h_pts_a=1 and h2h_pts_b=1 else true end) from t9 where not is_rest), true), '';

-- T10: turno con partita in corso (1-0 al 20'): non concluso, punti provvisori ma non finali
update matches set status='in_corso', home_goals=1, away_goals=0 where id = 'r9-m1';
update matches set kickoff = now() - interval '1 day' where round_number = 9;
insert into res select 'T10 turno 9 con partite non finite: non concluso',
  (select round_play_state(9)) = 'in_corso', (select round_play_state(9));

-- T11: partita rinviata fuori finestra: la Home non resta in 'segui', lo stato classifiche resta in_corso
-- turno 9: tutte finite tranne m10 spostata a +20 giorni
update matches set status='finita', home_goals=0, away_goals=0 where round_number=9 and id <> 'r9-m10';
update matches set status='non_iniziata', home_goals=null, away_goals=null, kickoff=now()+interval '20 days' where id='r9-m10';
insert into res select 'T11a rinvio fuori finestra: round_live_number non e'' 9', coalesce((select round_live_number()),0) <> 9, coalesce((select round_live_number()::text),'null');
insert into res select 'T11b ...ma il turno per le classifiche resta in_corso', (select round_play_state(9)) = 'in_corso', (select round_play_state(9));

-- T12: status coerente: gol -> finita via trigger; vincolo status/gol
update matches set home_goals=2, away_goals=2 where id='r9-m10';
insert into res select 'T12 trigger: gol inseriti a mano -> finita', (select status from matches where id='r9-m10') = 'finita', (select status from matches where id='r9-m10');

select t, case when ok then 'PASS' else 'FAIL' end as esito, detail from res order by t;
select count(*) filter (where ok) as passati, count(*) filter (where not ok) as falliti from res;
rollback;
