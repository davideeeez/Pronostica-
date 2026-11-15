-- Rollback di A1 (round_is_predictable): ripristina le policy di scrittura sui pronostici com'erano
-- (solo "ora < locks_at", cioe' round_is_open). La funzione round_is_predictable resta (inerte) e va
-- eliminata a mano solo se serve (DROP FUNCTION non passa dallo strumento delle migrazioni).
alter policy "predictions insert own while open" on public.predictions
  with check (((select auth.uid()) = user_id) and public.round_is_open(match_id));
alter policy "predictions update own while open" on public.predictions
  using (((select auth.uid()) = user_id) and public.round_is_open(match_id))
  with check (((select auth.uid()) = user_id) and public.round_is_open(match_id));
