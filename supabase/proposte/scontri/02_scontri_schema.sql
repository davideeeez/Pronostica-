-- PROPOSTA 2/4 — NON APPLICATA. Schema delle leghe a scontri diretti.
-- Il tipo di lega non cambia mai. Il calendario è indicizzato per numero di
-- turno SENZA foreign key: i turni 10-38 non esistono ancora in `rounds`.

-- 1) tipo di lega -------------------------------------------------------------
alter table public.leagues add column mode text not null default 'classifica';
alter table public.leagues
  add constraint leagues_mode_check check (mode in ('classifica', 'scontri')),
  add constraint leagues_scontri_solo_private check (mode = 'classifica' or visibility = 'private');

create or replace function public.leagues_mode_immutable()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if new.mode is distinct from old.mode then
    raise exception 'il tipo di lega non si cambia';
  end if;
  return new;
end;
$$;

revoke all on function public.leagues_mode_immutable() from public, anon, authenticated;

create trigger leagues_mode_immutable
before update on public.leagues
for each row execute function public.leagues_mode_immutable();

-- 2) calendario: una riga per lega, scritta alla prima lettura dopo il blocco ------
create table public.league_h2h_schedule (
  league_id uuid primary key references public.leagues(id) on delete cascade,
  status text not null check (status in ('avviata', 'non_avviata')),
  start_round int not null,
  member_count int not null check (member_count >= 0),
  cycle_length int not null check (cycle_length >= 0),
  generated_at timestamptz not null default now()
);

-- 3) abbinamenti: user_b NULL = user_a riposa in quel turno --------------------------
create table public.league_h2h_pairings (
  league_id uuid not null references public.leagues(id) on delete cascade,
  round_number int not null check (round_number between 1 and 38), -- nessuna FK su rounds
  slot smallint not null check (slot >= 0),
  user_a uuid not null references public.profiles(id),
  user_b uuid references public.profiles(id),
  primary key (league_id, round_number, slot),
  constraint pairings_no_self check (user_b is null or user_a <> user_b),
  constraint pairings_user_a_once unique (league_id, round_number, user_a),
  constraint pairings_user_b_once unique (league_id, round_number, user_b)
);
-- un solo riposo per turno (con N dispari, esattamente uno)
create unique index league_h2h_pairings_one_rest on public.league_h2h_pairings (league_id, round_number) where user_b is null;
create index league_h2h_pairings_user_a_idx on public.league_h2h_pairings (user_a);
create index league_h2h_pairings_user_b_idx on public.league_h2h_pairings (user_b) where user_b is not null;

-- nessuno compare due volte nello stesso turno, nemmeno una volta come user_a e
-- una come user_b (le unique sopra non lo coprono)
create or replace function public.league_h2h_pairings_check()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if exists (
    select 1 from public.league_h2h_pairings p
    where p.league_id = new.league_id and p.round_number = new.round_number and p.slot <> new.slot
      and (p.user_a in (new.user_a, new.user_b) or p.user_b in (new.user_a, new.user_b))
  ) then
    raise exception 'un membro compare due volte nello stesso turno';
  end if;
  return null;
end;
$$;

revoke all on function public.league_h2h_pairings_check() from public, anon, authenticated;

create trigger league_h2h_pairings_check
after insert on public.league_h2h_pairings
for each row execute function public.league_h2h_pairings_check();

-- 4) accesso: solo lettura ai membri della lega, nessuna scrittura diretta ------------
alter table public.league_h2h_schedule enable row level security;
alter table public.league_h2h_pairings enable row level security;
revoke all on public.league_h2h_schedule from anon, public, authenticated;
revoke all on public.league_h2h_pairings from anon, public, authenticated;
grant select on public.league_h2h_schedule to authenticated;
grant select on public.league_h2h_pairings to authenticated;

create policy "h2h schedule select if member" on public.league_h2h_schedule
for select to authenticated
using (public.is_league_member(league_id));

create policy "h2h pairings select if member" on public.league_h2h_pairings
for select to authenticated
using (public.is_league_member(league_id));
