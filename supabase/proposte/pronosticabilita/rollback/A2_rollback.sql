-- Rollback di A2: CREATE OR REPLACE VIEW non puo' togliere una colonna, quindi serve DROP + CREATE della vista
-- (DROP VIEW non passa dallo strumento delle migrazioni: applicare a mano dal SQL editor, in una transazione).
begin;
drop view public.calendar;
create view public.calendar with (security_invoker = true) as
select m.id as match_id, m.round_number, m.home, m.away, m.kickoff, m.home_goals, m.away_goals, r.locks_at,
       case
         when not exists (select 1 from public.matches m2
                          where m2.round_number = m.round_number and m2.status <> 'finita') then 'giocato'
         when m.round_number = public.open_round_number() then 'corrente'
         when r.locks_at <= now() then 'in_corso'
         else 'futuro'
       end as round_status,
       m.status as match_status
from public.matches m join public.rounds r on r.round_number = m.round_number;
revoke all on public.calendar from anon, public;
grant select on public.calendar to authenticated;
commit;
