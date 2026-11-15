-- Rollback di B1: richiede DROP (trigger, funzioni, colonna): applicare a mano dal SQL editor, in una transazione.
-- Si perdono gli orari di fine partita scritti dal trigger.
begin;
drop trigger matches_set_finished_at on public.matches;
drop function public.matches_set_finished_at();
drop function public.round_concluded_at(int);
alter table public.matches drop column finished_at;
commit;
