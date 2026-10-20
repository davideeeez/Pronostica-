begin;
create temp table res(t text, ok boolean, detail text);
grant all on res to public;
create or replace function pg_temp.uid(n int) returns uuid language sql as $$ select ('00000000-0000-4000-8000-' || lpad(n::text,12,'0'))::uuid $$;
create or replace function pg_temp.as_user(n int) returns void language plpgsql as $$ begin perform set_config('request.jwt.claim.sub', pg_temp.uid(n)::text, true); end $$;

-- turno 8 bloccato (kickoff ieri), lega a 4 membri che parte dall'8
update matches set kickoff = now() - interval '1 day' + (substr(id, 5)::int) * interval '1 minute' where round_number = 8;
insert into leagues (name, visibility, mode, start_round, created_by) values ('Lega4','private','scontri',8,pg_temp.uid(1));
insert into league_members (league_id,user_id,role,joined_at) select (select id from leagues where name='Lega4'), pg_temp.uid(g), case when g=1 then 'owner' else 'member' end, now()-interval '2 days'+g*interval '1 minute' from generate_series(1,4) g;
create temp table lg as select id from leagues where name='Lega4';
grant select on lg to public;
set local role authenticated;
select pg_temp.as_user(1) \gset
select count(*) as gen from h2h_league_state((select id from lg)) \gset
reset role;

-- pronostici: u1 esatto (1-0) su tutto il turno 8, u2 sbagliato (0-1); u3 e u4 nulla
insert into predictions (user_id, match_id, home_goals, away_goals)
select pg_temp.uid(1), id, 1, 0 from matches where round_number=8
union all select pg_temp.uid(2), id, 0, 1 from matches where round_number=8;
-- 9 partite finite 1-0, la decima NON iniziata -> turno non concluso
update matches set status='finita', home_goals=1, away_goals=0 where round_number=8 and id <> 'r8-m10';
update matches set status='non_iniziata', home_goals=null, away_goals=null where id='r8-m10';

-- (1) standings: turno non concluso -> pt_totali/esatti/esiti/pt_scontri tutti a 0
set local role authenticated;
select pg_temp.as_user(1) \gset
create temp table s_a as select * from h2h_standings((select id from lg));
reset role;
insert into res select '1a turno non concluso: pt_totali, esatti, esiti, pt_scontri tutti 0',
  (select bool_and(pt_totali=0 and esatti=0 and esiti=0 and pt_scontri=0) from s_a), (select string_agg(pt_totali||'/'||esatti||'/'||pt_scontri,' ') from s_a);
-- concludo il turno
update matches set status='finita', home_goals=1, away_goals=0 where id='r8-m10';
set local role authenticated;
select pg_temp.as_user(1) \gset
create temp table s_b as select * from h2h_standings((select id from lg));
reset role;
insert into res select '1b turno concluso: u1 pt_totali=30, esatti=10',
  (select pt_totali=30 and esatti=10 from s_b where user_id=pg_temp.uid(1)), (select pt_totali||'/'||esatti from s_b where user_id=pg_temp.uid(1));

-- (2) general_leaderboard: partita in corso non conta
update matches set status='in_corso', home_goals=1, away_goals=0 where id='r8-m1';
insert into res select '2 general_leaderboard usa points_final (u1: 27, non 30)',
  (select total_points from general_leaderboard where user_id=pg_temp.uid(1)) = 27
  and (select sum(points) from prediction_scores where user_id=pg_temp.uid(1) and round_number=8) = 30,
  (select total_points::text from general_leaderboard where user_id=pg_temp.uid(1));
update matches set status='finita' where id='r8-m1';

-- (3) h2h_is_locked con clock_timestamp: now() congelato prima del blocco, clock_timestamp dopo
update matches set kickoff = clock_timestamp() + interval '700 milliseconds' where round_number = 9;
insert into leagues (name, visibility, mode, start_round, created_by) values ('Lega9','private','scontri',9,pg_temp.uid(1));
insert into league_members (league_id,user_id,role) select id, pg_temp.uid(1), 'owner' from leagues where name='Lega9';
insert into league_invites (league_id, code) select id, 'CODE9XYZ' from leagues where name='Lega9';
create temp table pre as select now() < (select locks_at from rounds where round_number=9) as now_prima, h2h_is_locked((select id from leagues where name='Lega9')) as locked_prima;
select pg_sleep(1.2);
set local role authenticated;
select pg_temp.as_user(10) \gset
create temp table late as select outcome from join_private_league('CODE9XYZ');
reset role;
insert into res select '3 now() congelato prima del blocco ma clock_timestamp dopo: ingresso rifiutato (closed)',
  (select now_prima from pre) and not (select locked_prima from pre) and (select outcome from late)='closed'
  and not exists (select 1 from league_members where user_id=pg_temp.uid(10) and league_id=(select id from leagues where name='Lega9')),
  'now_prima='||(select now_prima from pre)||' locked_prima='||(select locked_prima from pre)||' esito='||(select outcome from late);

-- (4) round_live_number senza soglia 4h: turno 7 con partita non finita da settimane NON e' nella finestra (kickoff oltre +96h dal blocco)
-- turno 8: sposto una partita non finita a 6 ore fa, dentro la finestra -> live=8
update matches set status='non_iniziata', home_goals=null, away_goals=null, kickoff=now()-interval '6 hours' where id='r8-m2';
update matches set kickoff=(select locks_at from rounds where round_number=8)+interval '1 hour' where id='r8-m3' and false;
insert into res select '4 partita non finita da 6 ore, nella finestra: round_live_number = 8 (prima della modifica: null)',
  (select round_live_number()) = 8, coalesce(round_live_number()::text,'null');
update matches set status='finita', home_goals=1, away_goals=0 where id='r8-m2';

-- (5) h2h_match_detail: scontro di u1 nel turno 8
create temp table mine as select slot, user_a, user_b from league_h2h_pairings where league_id=(select id from lg) and round_number=8 and pg_temp.uid(1) in (user_a,user_b);
-- u3/u4 non hanno pronostici: li guardo se u1 li affronta, altrimenti guardo lo scontro di u3
create temp table d_all as
select p.slot, d.* from league_h2h_pairings p, lateral (select * from h2h_match_detail(p.league_id, 8, p.slot)) d where p.league_id=(select id from lg) and p.round_number=8;
-- u3/u4 senza pronostici su partite finite -> 0/0 mai null
insert into res select '5a finita senza pronostico: points=points_final=0 (mai null)',
  not exists (select 1 from league_h2h_pairings p join d_all d on d.slot=p.slot where p.league_id=(select id from lg) and p.round_number=8 and d.match_status='finita'
              and ((p.user_a in (pg_temp.uid(3),pg_temp.uid(4)) and (d.points_a is distinct from 0 or d.points_final_a is distinct from 0))
                or (p.user_b in (pg_temp.uid(3),pg_temp.uid(4)) and (d.points_b is distinct from 0 or d.points_final_b is distinct from 0)))), '';
-- partita non finita senza pronostico -> null
update matches set status='non_iniziata', home_goals=null, away_goals=null where id='r8-m4';
create temp table d2 as select p.user_a, p.user_b, d.* from league_h2h_pairings p, lateral (select * from h2h_match_detail(p.league_id, 8, p.slot) where match_id='r8-m4') d where p.league_id=(select id from lg) and p.round_number=8;
insert into res select '5b non finita senza pronostico: points e points_final null',
  (select bool_and(case when user_a in (pg_temp.uid(3),pg_temp.uid(4)) then points_a is null and points_final_a is null else true end
                  and case when user_b in (pg_temp.uid(3),pg_temp.uid(4)) then points_b is null and points_final_b is null else true end) from d2), '';
-- non finita con pronostico: points valorizzato solo se c'e' risultato parziale, points_final null
update matches set status='in_corso', home_goals=0, away_goals=0 where id='r8-m4';
create temp table d3 as select p.user_a, d.* from league_h2h_pairings p, lateral (select * from h2h_match_detail(p.league_id, 8, p.slot) where match_id='r8-m4') d where p.league_id=(select id from lg) and p.round_number=8;
insert into res select '5c in corso con pronostico: points provvisorio presente, points_final null',
  (select bool_and(points_final_a is null and (user_a not in (pg_temp.uid(1),pg_temp.uid(2)) or points_a is not null)) from d3), '';
-- 5d avversario nascosto prima del blocco: turno 9 (non bloccato in questo scenario? e' bloccato per il test 3): uso round_locked
insert into res select '5d round_locked true per turno 8, colonna presente', (select bool_and(round_locked) from d_all), '';

select t, case when ok then 'PASS' else 'FAIL' end as esito, detail from res order by t;
select count(*) filter (where ok) as passati, count(*) filter (where not ok) as falliti from res;
rollback;
