create function public.round_is_predictable(p_match_id text) returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce((select m.round_number = public.open_round_number()
                          and public.round_live_number() is null
                   from public.matches m where m.id = p_match_id), false) $$;
revoke execute on function public.round_is_predictable(text) from public, anon;
grant execute on function public.round_is_predictable(text) to authenticated;
alter policy "predictions insert own while open" on public.predictions
  with check ((select auth.uid()) = user_id and public.round_is_predictable(match_id));
alter policy "predictions update own while open" on public.predictions
  using ((select auth.uid()) = user_id and public.round_is_predictable(match_id))
  with check ((select auth.uid()) = user_id and public.round_is_predictable(match_id));
