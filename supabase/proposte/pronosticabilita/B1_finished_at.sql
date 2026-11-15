alter table public.matches add column finished_at timestamptz;

create function public.matches_set_finished_at() returns trigger
language plpgsql set search_path = public as $$
begin
  if new.status = 'finita' then
    if tg_op = 'INSERT' or old.status is distinct from 'finita' then
      new.finished_at := clock_timestamp();
    else
      new.finished_at := old.finished_at;
    end if;
  else
    new.finished_at := null;
  end if;
  return new;
end $$;

create trigger matches_set_finished_at before insert or update on public.matches
  for each row execute function public.matches_set_finished_at();

revoke execute on function public.matches_set_finished_at() from public, anon, authenticated;

create function public.round_concluded_at(p_round int) returns timestamptz
language sql stable set search_path = public as $$
  select case when public.round_play_state(p_round) = 'concluso'
              then (select max(m.finished_at) from public.matches m where m.round_number = p_round) end $$;

revoke execute on function public.round_concluded_at(int) from public, anon, authenticated;
