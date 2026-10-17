-- Test di sicurezza Pronostica! — rilanciabile per intero dopo ogni
-- migrazione che tocca schema/policy (vedi CLAUDE.md).
--
-- Tutto gira in UNA transazione annullata in fondo (rollback): non lascia
-- dati nel database, può essere rilanciato quante volte serve. Ogni test che
-- deve essere RIFIUTATO è avvolto in un blocco DO con EXCEPTION, così
-- un'eccezione attesa non aborta il resto dello script; i test che devono
-- invece RIUSCIRE girano normalmente (se falliscono, lo script si ferma con
-- un errore reale, cosa voluta).
--
-- Utenti reali usati per i test (già esistenti in auth.users/profiles):
--   A = davidezotti  560f6bd4-6070-4f6a-a78e-676cb4b8c7c4
--   B = utente reale 31e2df43-b49a-4b56-af0a-78aff50a9dd6 (il profilo viene
--       creato/aggiornato dentro la transazione se non esiste già, e annullato
--       col rollback finale)
--
-- Esegui con un client Postgres diretto (es. Supabase MCP execute_sql) come
-- ruolo privilegiato: lo script stesso passa a `authenticated`/`anon` dove
-- serve con SET LOCAL ROLE + request.jwt.claim.sub.
--
-- NIENTE DELETE in questo script (nemmeno per pulizia infra-transazione):
-- lo strumento MCP execute_sql tratta DELETE come statement distruttivo e
-- attende una conferma interattiva che in questa sessione non arriva mai,
-- causando un timeout di 60s indistinguibile da un vero blocco/lock (stesso
-- comportamento già noto per DROP TRIGGER/DROP FUNCTION). Il ROLLBACK finale
-- basta da solo ad annullare ogni riga scritta durante i test.

begin;

create temporary table test_results (
  seq int generated always as identity,
  test text primary key,
  expected text not null,
  actual text not null,
  passed boolean not null
);

insert into public.profiles (id, username, crest_pattern) values
  ('560f6bd4-6070-4f6a-a78e-676cb4b8c7c4', 'davidezotti', 'star'),
  ('31e2df43-b49a-4b56-af0a-78aff50a9dd6', 'utente_test_b', 'leaf')
on conflict (id) do update set username = excluded.username;

-- Utente sintetico C: esiste solo dentro questa transazione (annullata dal
-- rollback finale), non appartiene a nessuna lega. Serve dove il test richiede
-- "due utenti senza leghe in comune": gli utenti reali stanno ormai tutti nella
-- stessa lega, e senza DELETE non si possono sfilare dai membri.
--   C = 00000000-0000-4000-8000-0000000000c1
insert into auth.users (id) values ('00000000-0000-4000-8000-0000000000c1');
insert into public.profiles (id, username, crest_pattern)
values ('00000000-0000-4000-8000-0000000000c1', 'utente_test_c', 'leaf');

-- D ed E: coppia sintetica per P6f (classifica di lega), isolata dai dati reali.
--   D = 00000000-0000-4000-8000-0000000000d1   E = 00000000-0000-4000-8000-0000000000e1
insert into auth.users (id) values
  ('00000000-0000-4000-8000-0000000000d1'),
  ('00000000-0000-4000-8000-0000000000e1');
insert into public.profiles (id, username, crest_pattern) values
  ('00000000-0000-4000-8000-0000000000d1', 'utente_test_d', 'star'),
  ('00000000-0000-4000-8000-0000000000e1', 'utente_test_e', 'leaf');


-- ========== FASE 2: predictions ==========

-- P2a: insert su turno chiuso -> rifiutato
do $$
begin
  set local role authenticated;
  set local request.jwt.claim.sub = '560f6bd4-6070-4f6a-a78e-676cb4b8c7c4';
  insert into public.predictions (user_id, match_id, home_goals, away_goals)
  values ('560f6bd4-6070-4f6a-a78e-676cb4b8c7c4', 'r1-udinese-como', 2, 1);
  insert into test_results(test, expected, actual, passed)
    values ('P2a insert su turno chiuso', 'rifiutato', 'NON rifiutato (BUG)', false);
exception when insufficient_privilege then
  insert into test_results(test, expected, actual, passed)
    values ('P2a insert su turno chiuso', 'rifiutato', 'rifiutato: ' || sqlerrm, true);
end $$;
reset role;

-- P2b: predictions non ha round_number (il turno si ricava solo da matches)
do $$
declare
  v_exists boolean;
begin
  select exists(
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'predictions' and column_name = 'round_number'
  ) into v_exists;
  insert into test_results(test, expected, actual, passed)
    values ('P2b predictions senza round_number', 'colonna assente', case when v_exists then 'PRESENTE (BUG)' else 'assente' end, not v_exists);
end $$;

-- P2c: update dopo la chiusura del turno -> nessun effetto
do $$
declare
  v_before text;
  v_after text;
begin
  insert into public.predictions (user_id, match_id, home_goals, away_goals)
  values ('560f6bd4-6070-4f6a-a78e-676cb4b8c7c4', 'r1-inter-monza', 4, 1);
  select home_goals || '-' || away_goals into v_before from public.predictions
    where user_id = '560f6bd4-6070-4f6a-a78e-676cb4b8c7c4' and match_id = 'r1-inter-monza';

  set local role authenticated;
  set local request.jwt.claim.sub = '560f6bd4-6070-4f6a-a78e-676cb4b8c7c4';
  update public.predictions set home_goals = 9 where match_id = 'r1-inter-monza';
  reset role;

  select home_goals || '-' || away_goals into v_after from public.predictions
    where user_id = '560f6bd4-6070-4f6a-a78e-676cb4b8c7c4' and match_id = 'r1-inter-monza';
  -- niente DELETE di pulizia qui: l'intero script gira in una transazione
  -- annullata con ROLLBACK in fondo, quindi non serve (e il tool MCP tratta
  -- DELETE come statement distruttivo che richiede conferma interattiva,
  -- mai disponibile in questa sessione: va evitato, non solo DROP).

  insert into test_results(test, expected, actual, passed)
    values ('P2c update dopo chiusura', v_before || ' (invariato)', v_after, v_before = v_after);
end $$;

-- P2d: A non legge il pronostico di B su turno aperto. Su turno chiuso,
-- AGGIORNATO per la Fase 4: visibile solo se A e B condividono una lega
-- (prima era visibile a chiunque autenticato) -- qui A e B non condividono
-- ancora nulla, quindi deve essere invisibile anche a turno chiuso.
do $$
declare
  v_open_visible boolean;
  v_closed_visible boolean;
  v_open_match text;
begin
  -- partita di un turno ancora APERTO: mai un id scritto a mano, il calendario
  -- avanza. Il turno aperto e' open_round_number() (non current_round_number(),
  -- che puo' essere gia' chiuso).
  select m.id into v_open_match
  from public.matches m
  where m.round_number = public.open_round_number()
  order by m.kickoff limit 1;

  -- B (serve a P2d-bis, che lo mette in lega con A) e C (nessuna lega)
  insert into public.predictions (user_id, match_id, home_goals, away_goals) values
    ('31e2df43-b49a-4b56-af0a-78aff50a9dd6', v_open_match, 1, 1),
    ('31e2df43-b49a-4b56-af0a-78aff50a9dd6', 'r1-udinese-como', 1, 1),
    ('00000000-0000-4000-8000-0000000000c1', v_open_match, 1, 1),
    ('00000000-0000-4000-8000-0000000000c1', 'r1-udinese-como', 1, 1);

  set local role authenticated;
  set local request.jwt.claim.sub = '560f6bd4-6070-4f6a-a78e-676cb4b8c7c4';

  select exists(select 1 from public.predictions where user_id = '31e2df43-b49a-4b56-af0a-78aff50a9dd6' and match_id = v_open_match) into v_open_visible;
  select exists(select 1 from public.predictions where user_id = '00000000-0000-4000-8000-0000000000c1' and match_id = 'r1-udinese-como') into v_closed_visible;
  reset role;

  insert into test_results(test, expected, actual, passed)
    values ('P2d B su turno aperto invisibile ad A', 'false', v_open_visible::text, v_open_visible = false);
  insert into test_results(test, expected, actual, passed)
    values ('P2d C su turno chiuso invisibile ad A (nessuna lega in comune)', 'false', v_closed_visible::text, v_closed_visible = false);
end $$;

-- P2d-bis: stesso scenario, ma A e B condividono una lega pubblica -> ora
-- il pronostico di B su turno chiuso diventa visibile ad A.
do $$
declare
  v_league_id uuid;
  v_closed_visible boolean;
begin
  set local role authenticated;
  set local request.jwt.claim.sub = '560f6bd4-6070-4f6a-a78e-676cb4b8c7c4';
  v_league_id := public.create_league('Test lega condivisa P2d-bis', 'public', public.open_round_number());

  set local request.jwt.claim.sub = '31e2df43-b49a-4b56-af0a-78aff50a9dd6';
  perform public.join_public_league(v_league_id);

  -- torna al sub di A prima di verificare cosa VEDE A: senza questo reset
  -- la select girerebbe ancora come B, che vede sempre le proprie righe.
  set local request.jwt.claim.sub = '560f6bd4-6070-4f6a-a78e-676cb4b8c7c4';
  select exists(select 1 from public.predictions where user_id = '31e2df43-b49a-4b56-af0a-78aff50a9dd6' and match_id = 'r1-udinese-como') into v_closed_visible;
  reset role;

  insert into test_results(test, expected, actual, passed)
    values ('P2d-bis B su turno chiuso visibile ad A (lega in comune)', 'true', v_closed_visible::text, v_closed_visible = true);
end $$;

-- P2e: A non può scrivere un pronostico a nome di B
do $$
declare
  v_open_match text;
begin
  select m.id into v_open_match
  from public.matches m
  where m.round_number = public.open_round_number()
  order by m.kickoff limit 1;

  set local role authenticated;
  set local request.jwt.claim.sub = '560f6bd4-6070-4f6a-a78e-676cb4b8c7c4';
  insert into public.predictions (user_id, match_id, home_goals, away_goals)
  values ('31e2df43-b49a-4b56-af0a-78aff50a9dd6', v_open_match, 3, 0);
  insert into test_results(test, expected, actual, passed)
    values ('P2e A scrive a nome di B', 'rifiutato', 'NON rifiutato (BUG)', false);
exception when insufficient_privilege then
  insert into test_results(test, expected, actual, passed)
    values ('P2e A scrive a nome di B', 'rifiutato', 'rifiutato: ' || sqlerrm, true);
end $$;
reset role;


-- ========== FASE 3: punteggio, matches/rounds, classifica ==========

-- P3a: funzione punteggio, 5 casi
do $$
declare
  v_esatto int := public.prediction_points(2,1,2,1);
  v_esito int := public.prediction_points(3,0,2,1);
  v_sbagliato int := public.prediction_points(1,0,0,1);
  v_pareggio_diverso int := public.prediction_points(2,2,1,1);
  v_senza_risultato int := public.prediction_points(null,null,1,1);
begin
  insert into test_results(test, expected, actual, passed) values
    ('P3a esatto', '3', v_esatto::text, v_esatto = 3),
    ('P3a esito corretto', '1', v_esito::text, v_esito = 1),
    ('P3a sbagliato', '0', v_sbagliato::text, v_sbagliato = 0),
    ('P3a pareggio diverso', '1', v_pareggio_diverso::text, v_pareggio_diverso = 1),
    ('P3a senza risultato', 'NULL', coalesce(v_senza_risultato::text, 'NULL'), v_senza_risultato is null);
end $$;

-- P3b: authenticated non scrive risultati su matches
do $$
declare
  v_before text;
  v_after text;
begin
  select home_goals || '-' || away_goals into v_before from public.matches where id = 'r1-inter-monza';

  set local role authenticated;
  set local request.jwt.claim.sub = '560f6bd4-6070-4f6a-a78e-676cb4b8c7c4';
  update public.matches set home_goals = 9, away_goals = 9 where id = 'r1-inter-monza';
  reset role;

  select home_goals || '-' || away_goals into v_after from public.matches where id = 'r1-inter-monza';
  insert into test_results(test, expected, actual, passed)
    values ('P3b authenticated update matches', v_before || ' (invariato)', v_after, v_before = v_after);
exception when insufficient_privilege then
  insert into test_results(test, expected, actual, passed)
    values ('P3b authenticated update matches', 'invariato o rifiutato', 'rifiutato: ' || sqlerrm, true);
end $$;
reset role;

do $$
begin
  set local role authenticated;
  set local request.jwt.claim.sub = '560f6bd4-6070-4f6a-a78e-676cb4b8c7c4';
  insert into public.matches (id, round_number, home, away, kickoff) values ('test-security-sql', 1, 'X', 'Y', now());
  insert into test_results(test, expected, actual, passed)
    values ('P3b authenticated insert matches', 'rifiutato', 'NON rifiutato (BUG)', false);
exception when insufficient_privilege then
  insert into test_results(test, expected, actual, passed)
    values ('P3b authenticated insert matches', 'rifiutato', 'rifiutato: ' || sqlerrm, true);
end $$;
reset role;

-- P3d: colonne esposte da general_leaderboard (nessun dato sensibile)
do $$
declare
  v_cols text;
begin
  select string_agg(column_name, ', ' order by ordinal_position) into v_cols
  from information_schema.columns where table_schema = 'public' and table_name = 'general_leaderboard';
  insert into test_results(test, expected, actual, passed)
    values ('P3d colonne general_leaderboard', 'nessuna email/dato Google', v_cols, v_cols !~* 'email|google|provider');
end $$;


-- ========== FASE 4: calendario unico, anon ovunque, locks_at ==========

-- P4a: il turno 'corrente' della vista calendar e' open_round_number();
-- current_round_number() resta il primo turno non completato.
do $$
declare
  v_open int := public.open_round_number();
  v_cur int := public.current_round_number();
  v_expected_cur int;
  v_calendar int;
  v_n int;
begin
  select min(round_number) into v_expected_cur from public.matches where home_goals is null;
  select min(round_number), count(distinct round_number) into v_calendar, v_n from public.calendar where round_status = 'corrente';
  insert into test_results(test, expected, actual, passed)
    values ('P4a calendar corrente = open_round_number()', coalesce(v_open::text,'NULL'), coalesce(v_calendar::text,'nessuno'), v_open is not distinct from v_calendar);
  insert into test_results(test, expected, actual, passed)
    values ('P4a current_round_number() = primo turno con partite senza risultato', coalesce(v_expected_cur::text,'ultimo turno'), v_cur::text, v_expected_cur is null or v_cur = v_expected_cur);
end $$;

-- P4b: locks_at coerente con min(kickoff) per ogni turno
do $$
declare
  v_mismatches int;
begin
  select count(*) into v_mismatches
  from public.rounds r
  join (select round_number, min(kickoff) as mn from public.matches group by round_number) m
    on m.round_number = r.round_number
  where r.locks_at <> m.mn;
  insert into test_results(test, expected, actual, passed)
    values ('P4b locks_at = min(kickoff) per tutti i turni', '0 discrepanze', v_mismatches::text, v_mismatches = 0);
end $$;

-- anon su tutte le tabelle/viste con dati utente o calendario
do $$
declare
  t text;
  rejected boolean;
begin
  foreach t in array array['predictions','profiles','prediction_scores','general_leaderboard','matches','rounds','calendar']
  loop
    rejected := false;
    begin
      set local role anon;
      execute format('select count(*) from public.%I', t);
      reset role;
    exception when insufficient_privilege then
      rejected := true;
      reset role;
    end;
    insert into test_results(test, expected, actual, passed)
      values ('P4 anon su ' || t, 'rifiutato', case when rejected then 'rifiutato' else 'NON rifiutato (BUG)' end, rejected);
  end loop;
end $$;

-- authenticated su general_leaderboard (sospesa fino a gennaio: deve essere rifiutata anche a loggati)
do $$
begin
  set local role authenticated;
  set local request.jwt.claim.sub = '560f6bd4-6070-4f6a-a78e-676cb4b8c7c4';
  perform count(*) from public.general_leaderboard;
  insert into test_results(test, expected, actual, passed)
    values ('P4 authenticated general_leaderboard (sospesa)', 'rifiutato', 'NON rifiutato (BUG)', false);
exception when insufficient_privilege then
  insert into test_results(test, expected, actual, passed)
    values ('P4 authenticated general_leaderboard (sospesa)', 'rifiutato', 'rifiutato: ' || sqlerrm, true);
end $$;
reset role;

-- locks_at: modifica libera prima della chiusura (turno aperto)
do $$
declare
  v_before timestamptz;
  v_after timestamptz;
  v_round int;
  v_match text;
begin
  select r.round_number, r.locks_at into v_round, v_before
  from public.rounds r where r.round_number = public.open_round_number();
  select id into v_match from public.matches where round_number = v_round order by kickoff limit 1;
  update public.matches set kickoff = v_before - interval '1 hour' where id = v_match;
  select locks_at into v_after from public.rounds where round_number = v_round;
  update public.matches set kickoff = v_before where id = v_match;
  insert into test_results(test, expected, actual, passed)
    values ('P4 locks_at si aggiorna prima della chiusura', 'aggiornato', case when v_after = v_before - interval '1 hour' then 'aggiornato' else 'NON aggiornato (BUG)' end, v_after = v_before - interval '1 hour');
end $$;

-- locks_at: non si può spostare avanti dopo la chiusura (round 3, già chiuso)
do $$
begin
  update public.matches set kickoff = '2026-09-06 20:00:00+00' where id = 'r3-genoa-como';
  insert into test_results(test, expected, actual, passed)
    values ('P4 locks_at bloccato dopo la chiusura', 'rifiutato', 'NON rifiutato (BUG)', false);
exception when raise_exception then
  insert into test_results(test, expected, actual, passed)
    values ('P4 locks_at bloccato dopo la chiusura', 'rifiutato', 'rifiutato: ' || sqlerrm, true);
end $$;


-- ========== FASE 4: leghe (migrazione 20261007234129 applicata) ==========

-- P5i: 10 codici sbagliati di fila -> tutti rifiutati, poi anche il codice
-- giusto rifiutato (rate limit attivo); fuori dalla finestra (simulata
-- spostando indietro i tentativi con UPDATE, non DELETE) il codice giusto entra.
do $$
declare
  v_league_id uuid;
  v_code text;
  i int;
  v_result text;
  v_rejected_wrong int := 0;
begin
  set local role authenticated;
  set local request.jwt.claim.sub = '560f6bd4-6070-4f6a-a78e-676cb4b8c7c4';
  v_league_id := public.create_league('Test lega rate limit', 'private', public.open_round_number());
  reset role;

  select code into v_code from public.league_invites where league_id = v_league_id;

  set local role authenticated;
  set local request.jwt.claim.sub = '31e2df43-b49a-4b56-af0a-78aff50a9dd6';
  for i in 1..10 loop
    select outcome into v_result from public.join_private_league('XXXXXXX' || i::text);
    if v_result = 'invalid' then
      v_rejected_wrong := v_rejected_wrong + 1;
    end if;
  end loop;

  -- 11esimo tentativo, codice giusto ma ancora dentro la finestra
  select outcome into v_result from public.join_private_league(v_code);
  reset role;

  insert into test_results(test, expected, actual, passed)
    values ('P5i 10 codici sbagliati rifiutati', '10', v_rejected_wrong::text, v_rejected_wrong = 10);
  insert into test_results(test, expected, actual, passed)
    values ('P5i codice giusto rifiutato dentro la finestra', 'invalid', v_result, v_result = 'invalid');

  update public.league_join_attempts set attempted_at = now() - interval '11 minutes'
  where user_id = '31e2df43-b49a-4b56-af0a-78aff50a9dd6';

  set local role authenticated;
  set local request.jwt.claim.sub = '31e2df43-b49a-4b56-af0a-78aff50a9dd6';
  select outcome into v_result from public.join_private_league(v_code);
  reset role;

  insert into test_results(test, expected, actual, passed)
    values ('P5i codice giusto entra fuori dalla finestra', 'ok', v_result, v_result = 'ok');
end $$;

-- P5j: list_public_leagues non restituisce leghe private né colonne di codice
do $$
declare
  v_private_id uuid;
  v_public_id uuid;
  v_private_leaked boolean;
  v_public_found boolean;
  v_cols text;
begin
  set local role authenticated;
  set local request.jwt.claim.sub = '560f6bd4-6070-4f6a-a78e-676cb4b8c7c4';
  v_private_id := public.create_league('Test privata per j', 'private', public.open_round_number());
  v_public_id := public.create_league('Test pubblica per j', 'public', public.open_round_number());

  select exists(select 1 from public.list_public_leagues() where id = v_private_id) into v_private_leaked;
  select exists(select 1 from public.list_public_leagues() where id = v_public_id) into v_public_found;
  reset role;

  select array_to_string(proargnames, ',') into v_cols from pg_proc where proname = 'list_public_leagues';

  insert into test_results(test, expected, actual, passed)
    values ('P5j list_public_leagues non espone la privata', 'false', v_private_leaked::text, v_private_leaked = false);
  insert into test_results(test, expected, actual, passed)
    values ('P5j list_public_leagues include la pubblica', 'true', v_public_found::text, v_public_found = true);
  insert into test_results(test, expected, actual, passed)
    values ('P5j list_public_leagues nessuna colonna codice', 'nessun "code"', v_cols, v_cols !~* 'code');
end $$;

-- P5k: entrare due volte nella stessa lega (pubblica e privata) -> esito
-- chiaro, nessuna riga duplicata in league_members.
do $$
declare
  v_pub_id uuid;
  v_priv_id uuid;
  v_code text;
  v_result1 text;
  v_result2 text;
  v_count int;
begin
  set local role authenticated;
  set local request.jwt.claim.sub = '560f6bd4-6070-4f6a-a78e-676cb4b8c7c4';
  v_pub_id := public.create_league('Test pubblica per k', 'public', public.open_round_number());
  v_priv_id := public.create_league('Test privata per k', 'private', public.open_round_number());
  reset role;

  select code into v_code from public.league_invites where league_id = v_priv_id;

  set local role authenticated;
  set local request.jwt.claim.sub = '31e2df43-b49a-4b56-af0a-78aff50a9dd6';
  v_result1 := public.join_public_league(v_pub_id);
  v_result2 := public.join_public_league(v_pub_id);
  reset role;

  select count(*) into v_count from public.league_members where league_id = v_pub_id and user_id = '31e2df43-b49a-4b56-af0a-78aff50a9dd6';

  insert into test_results(test, expected, actual, passed)
    values ('P5k join_public_league due volte: esiti', 'ok, already_member', v_result1 || ', ' || v_result2, v_result1 = 'ok' and v_result2 = 'already_member');
  insert into test_results(test, expected, actual, passed)
    values ('P5k join_public_league due volte: nessun duplicato', '1', v_count::text, v_count = 1);

  set local role authenticated;
  set local request.jwt.claim.sub = '31e2df43-b49a-4b56-af0a-78aff50a9dd6';
  select outcome into v_result1 from public.join_private_league(v_code);
  select outcome into v_result2 from public.join_private_league(v_code);
  reset role;

  select count(*) into v_count from public.league_members where league_id = v_priv_id and user_id = '31e2df43-b49a-4b56-af0a-78aff50a9dd6';

  insert into test_results(test, expected, actual, passed)
    values ('P5k join_private_league due volte: esiti', 'ok, already_member', v_result1 || ', ' || v_result2, v_result1 = 'ok' and v_result2 = 'already_member');
  insert into test_results(test, expected, actual, passed)
    values ('P5k join_private_league due volte: nessun duplicato', '1', v_count::text, v_count = 1);
end $$;

-- P5l: league_join_attempts non leggibile né scrivibile da authenticated o anon
do $$
begin
  set local role authenticated;
  set local request.jwt.claim.sub = '560f6bd4-6070-4f6a-a78e-676cb4b8c7c4';
  perform count(*) from public.league_join_attempts;
  insert into test_results(test, expected, actual, passed)
    values ('P5l authenticated select league_join_attempts', 'rifiutato', 'NON rifiutato (BUG)', false);
exception when insufficient_privilege then
  insert into test_results(test, expected, actual, passed)
    values ('P5l authenticated select league_join_attempts', 'rifiutato', 'rifiutato: ' || sqlerrm, true);
end $$;
reset role;

do $$
begin
  set local role authenticated;
  set local request.jwt.claim.sub = '560f6bd4-6070-4f6a-a78e-676cb4b8c7c4';
  insert into public.league_join_attempts (user_id) values ('560f6bd4-6070-4f6a-a78e-676cb4b8c7c4');
  insert into test_results(test, expected, actual, passed)
    values ('P5l authenticated insert league_join_attempts', 'rifiutato', 'NON rifiutato (BUG)', false);
exception when insufficient_privilege then
  insert into test_results(test, expected, actual, passed)
    values ('P5l authenticated insert league_join_attempts', 'rifiutato', 'rifiutato: ' || sqlerrm, true);
end $$;
reset role;

do $$
begin
  set local role anon;
  perform count(*) from public.league_join_attempts;
  insert into test_results(test, expected, actual, passed)
    values ('P5l anon select league_join_attempts', 'rifiutato', 'NON rifiutato (BUG)', false);
exception when insufficient_privilege then
  insert into test_results(test, expected, actual, passed)
    values ('P5l anon select league_join_attempts', 'rifiutato', 'rifiutato: ' || sqlerrm, true);
end $$;
reset role;

-- P5m: start_round nel passato o inesistente -> create_league rifiutata
do $$
begin
  set local role authenticated;
  set local request.jwt.claim.sub = '560f6bd4-6070-4f6a-a78e-676cb4b8c7c4';
  perform public.create_league('Test start_round passato', 'public', 1);
  insert into test_results(test, expected, actual, passed)
    values ('P5m start_round nel passato', 'rifiutato', 'NON rifiutato (BUG)', false);
exception when raise_exception then
  insert into test_results(test, expected, actual, passed)
    values ('P5m start_round nel passato', 'rifiutato', 'rifiutato: ' || sqlerrm, true);
end $$;
reset role;

do $$
begin
  set local role authenticated;
  set local request.jwt.claim.sub = '560f6bd4-6070-4f6a-a78e-676cb4b8c7c4';
  perform public.create_league('Test start_round inesistente', 'public', 999);
  insert into test_results(test, expected, actual, passed)
    values ('P5m start_round inesistente', 'rifiutato', 'NON rifiutato (BUG)', false);
exception when raise_exception then
  insert into test_results(test, expected, actual, passed)
    values ('P5m start_round inesistente', 'rifiutato', 'rifiutato: ' || sqlerrm, true);
end $$;
reset role;

-- P5n: generate_invite_code produce sempre 8 caratteri dall'alfabeto senza
-- ambigui, su un campione ampio (regressione del bug ::int vs floor()).
do $$
declare
  i int;
  v_code text;
  v_bad_length int := 0;
  v_bad_chars int := 0;
begin
  for i in 1..5000 loop
    v_code := public.generate_invite_code();
    if char_length(v_code) <> 8 then
      v_bad_length := v_bad_length + 1;
    end if;
    if v_code !~ '^[ABCDEFGHJKMNPQRSTUVWXYZ23456789]{8}$' then
      v_bad_chars := v_bad_chars + 1;
    end if;
  end loop;
  insert into test_results(test, expected, actual, passed)
    values ('P5n generate_invite_code: 5000 codici validi', '0 anomalie lunghezza, 0 anomalie caratteri',
            v_bad_length::text || ' lunghezza, ' || v_bad_chars::text || ' caratteri',
            v_bad_length = 0 and v_bad_chars = 0);
end $$;

-- P5o: codice in minuscolo e con spazi entra comunque, e non viene contato
-- come tentativo falliente in league_join_attempts.
do $$
declare
  v_code text;
  v_league_id uuid;
  v_result text;
  v_attempts_before int;
  v_attempts_after int;
begin
  set local role authenticated;
  set local request.jwt.claim.sub = '560f6bd4-6070-4f6a-a78e-676cb4b8c7c4';
  v_league_id := public.create_league('Test lega minuscole', 'private', public.open_round_number());
  reset role;

  select code into v_code from public.league_invites where league_id = v_league_id;
  select count(*) into v_attempts_before from public.league_join_attempts where user_id = '31e2df43-b49a-4b56-af0a-78aff50a9dd6';

  set local role authenticated;
  set local request.jwt.claim.sub = '31e2df43-b49a-4b56-af0a-78aff50a9dd6';
  select outcome into v_result from public.join_private_league('  ' || lower(v_code) || '  ');
  reset role;

  select count(*) into v_attempts_after from public.league_join_attempts where user_id = '31e2df43-b49a-4b56-af0a-78aff50a9dd6';

  insert into test_results(test, expected, actual, passed)
    values ('P5o codice minuscolo/spazi entra senza contare come fallito', 'ok, 0 nuovi tentativi falliti',
            v_result || ', ' || (v_attempts_after - v_attempts_before)::text || ' nuovi tentativi',
            v_result = 'ok' and v_attempts_after = v_attempts_before);
end $$;

-- P5p: join_public_league su una lega privata -> 'not_found' (non 'private':
-- non deve rivelare che la lega esiste/è privata a chi non ha il codice).
do $$
declare
  v_league_id uuid;
  v_result text;
begin
  set local role authenticated;
  set local request.jwt.claim.sub = '560f6bd4-6070-4f6a-a78e-676cb4b8c7c4';
  v_league_id := public.create_league('Test lega privata per p', 'private', public.open_round_number());
  set local request.jwt.claim.sub = '31e2df43-b49a-4b56-af0a-78aff50a9dd6';
  v_result := public.join_public_league(v_league_id);
  reset role;

  insert into test_results(test, expected, actual, passed)
    values ('P5p join_public_league su lega privata', 'not_found', v_result, v_result = 'not_found');
end $$;

-- P5q: join_private_league ritorna anche league_id (migrazione
-- 20261009120000) — NULL su 'invalid', valorizzato e corretto su 'ok' e
-- 'already_member'.
do $$
declare
  v_league_id uuid;
  v_code text;
  v_outcome_invalid text;
  v_league_id_invalid uuid;
  v_outcome_ok text;
  v_league_id_ok uuid;
  v_outcome_again text;
  v_league_id_again uuid;
begin
  set local role authenticated;
  set local request.jwt.claim.sub = '560f6bd4-6070-4f6a-a78e-676cb4b8c7c4';
  v_league_id := public.create_league('Test lega join_private_league id q', 'private', public.open_round_number());
  reset role;

  select code into v_code from public.league_invites where league_id = v_league_id;

  set local role authenticated;
  set local request.jwt.claim.sub = '31e2df43-b49a-4b56-af0a-78aff50a9dd6';
  select outcome, league_id into v_outcome_invalid, v_league_id_invalid from public.join_private_league('CODICESBAGLIATOQ');
  select outcome, league_id into v_outcome_ok, v_league_id_ok from public.join_private_league(v_code);
  select outcome, league_id into v_outcome_again, v_league_id_again from public.join_private_league(v_code);
  reset role;

  insert into test_results(test, expected, actual, passed) values
    ('P5q join_private_league invalid: outcome', 'invalid', v_outcome_invalid, v_outcome_invalid = 'invalid'),
    ('P5q join_private_league invalid: league_id NULL', 'NULL', coalesce(v_league_id_invalid::text,'NULL'), v_league_id_invalid is null),
    ('P5q join_private_league ok: outcome', 'ok', v_outcome_ok, v_outcome_ok = 'ok'),
    ('P5q join_private_league ok: league_id corretto', v_league_id::text, coalesce(v_league_id_ok::text,'NULL'), v_league_id_ok = v_league_id),
    ('P5q join_private_league already_member: outcome', 'already_member', v_outcome_again, v_outcome_again = 'already_member'),
    ('P5q join_private_league already_member: league_id corretto', v_league_id::text, coalesce(v_league_id_again::text,'NULL'), v_league_id_again = v_league_id);
end $$;


-- ========== FASE 4: leghe, test a-h (visibilità, owner, scritture dirette, classifica) ==========

-- P6a: un non membro (B, su una NUOVA lega privata di A) non legge la lega,
-- i suoi membri, il codice, né la sua league_leaderboard.
do $$
declare
  v_league_id uuid;
  v_leagues_visible boolean;
  v_members_count int;
  v_invite_visible boolean;
  v_leaderboard_count int;
begin
  set local role authenticated;
  set local request.jwt.claim.sub = '560f6bd4-6070-4f6a-a78e-676cb4b8c7c4';
  v_league_id := public.create_league('Test lega privata non membro a', 'private', public.open_round_number());
  reset role;

  set local role authenticated;
  set local request.jwt.claim.sub = '31e2df43-b49a-4b56-af0a-78aff50a9dd6';
  select exists(select 1 from public.leagues where id = v_league_id) into v_leagues_visible;
  select count(*) into v_members_count from public.league_members where league_id = v_league_id;
  select exists(select 1 from public.league_invites where league_id = v_league_id) into v_invite_visible;
  select count(*) into v_leaderboard_count from public.league_leaderboard(v_league_id);
  reset role;

  insert into test_results(test, expected, actual, passed) values
    ('P6a non membro: lega privata invisibile', 'false', v_leagues_visible::text, v_leagues_visible = false),
    ('P6a non membro: membri = 0 righe', '0', v_members_count::text, v_members_count = 0),
    ('P6a non membro: codice invisibile', 'false', v_invite_visible::text, v_invite_visible = false),
    ('P6a non membro: league_leaderboard 0 righe', '0', v_leaderboard_count::text, v_leaderboard_count = 0);
end $$;

-- P6b: B, membro non-owner, non vede il codice e ottiene 'forbidden' dalle
-- tre azioni riservate all'owner.
do $$
declare
  v_league_id uuid;
  v_code text;
  v_join_result text;
  v_invite_visible boolean;
  v_remove_result text;
  v_regen_result text;
  v_delete_result text;
begin
  set local role authenticated;
  set local request.jwt.claim.sub = '560f6bd4-6070-4f6a-a78e-676cb4b8c7c4';
  v_league_id := public.create_league('Test lega B membro non owner b', 'private', public.open_round_number());
  reset role;

  select code into v_code from public.league_invites where league_id = v_league_id;

  set local role authenticated;
  set local request.jwt.claim.sub = '31e2df43-b49a-4b56-af0a-78aff50a9dd6';
  select outcome into v_join_result from public.join_private_league(v_code);
  select exists(select 1 from public.league_invites where league_id = v_league_id) into v_invite_visible;
  v_remove_result := public.remove_league_member(v_league_id, '560f6bd4-6070-4f6a-a78e-676cb4b8c7c4');
  v_regen_result := public.regenerate_invite_code(v_league_id);
  v_delete_result := public.delete_league(v_league_id);
  reset role;

  insert into test_results(test, expected, actual, passed) values
    ('P6b B entra nella lega', 'ok', v_join_result, v_join_result = 'ok'),
    ('P6b B (non owner): league_invites vuota', 'false', v_invite_visible::text, v_invite_visible = false),
    ('P6b B: remove_league_member -> forbidden', 'forbidden', v_remove_result, v_remove_result = 'forbidden'),
    ('P6b B: regenerate_invite_code -> forbidden', 'forbidden', v_regen_result, v_regen_result = 'forbidden'),
    ('P6b B: delete_league -> forbidden', 'forbidden', v_delete_result, v_delete_result = 'forbidden');
end $$;

-- P6c: insert/update diretti da authenticated su leagues, league_members e
-- league_invites rifiutati (permission denied). DELETE verificato solo in
-- modo statico con has_table_privilege, mai eseguito: anche dentro un blocco
-- con EXCEPTION, il tool MCP tratta un DELETE letterale come statement
-- distruttivo e va in timeout. In contrasto, la via corretta (le funzioni)
-- funziona: codice sbagliato -> 'invalid', codice giusto -> 'ok'.
do $$
declare
  v_league_id uuid;
  v_public_league_id uuid;
  v_code text;
  v_result_ok text;
  v_result_bad text;
begin
  set local role authenticated;
  set local request.jwt.claim.sub = '560f6bd4-6070-4f6a-a78e-676cb4b8c7c4';
  v_league_id := public.create_league('Test lega scritture dirette c', 'private', public.open_round_number());
  v_public_league_id := public.create_league('Test lega pubblica scritture dirette c', 'public', public.open_round_number());
  reset role;

  select code into v_code from public.league_invites where league_id = v_league_id;

  insert into test_results(test, expected, actual, passed) values
    ('P6c authenticated: nessun privilegio DELETE su leagues (statico)', 'false', has_table_privilege('authenticated','public.leagues','DELETE')::text, not has_table_privilege('authenticated','public.leagues','DELETE')),
    ('P6c authenticated: nessun privilegio DELETE su league_members (statico)', 'false', has_table_privilege('authenticated','public.league_members','DELETE')::text, not has_table_privilege('authenticated','public.league_members','DELETE')),
    ('P6c authenticated: nessun privilegio DELETE su league_invites (statico)', 'false', has_table_privilege('authenticated','public.league_invites','DELETE')::text, not has_table_privilege('authenticated','public.league_invites','DELETE'));

  begin
    set local role authenticated;
    set local request.jwt.claim.sub = '560f6bd4-6070-4f6a-a78e-676cb4b8c7c4';
    insert into public.leagues (name, visibility, start_round, created_by) values ('Insert diretto c', 'public', public.open_round_number(), '560f6bd4-6070-4f6a-a78e-676cb4b8c7c4');
    reset role;
    insert into test_results(test, expected, actual, passed) values ('P6c insert diretto su leagues', 'rifiutato', 'NON rifiutato (BUG)', false);
  exception when insufficient_privilege then
    reset role;
    insert into test_results(test, expected, actual, passed) values ('P6c insert diretto su leagues', 'rifiutato', 'rifiutato: ' || sqlerrm, true);
  end;

  begin
    set local role authenticated;
    set local request.jwt.claim.sub = '560f6bd4-6070-4f6a-a78e-676cb4b8c7c4';
    update public.leagues set name = 'Hackerato' where id = v_league_id;
    reset role;
    insert into test_results(test, expected, actual, passed) values ('P6c update diretto su leagues', 'rifiutato', 'NON rifiutato (BUG)', false);
  exception when insufficient_privilege then
    reset role;
    insert into test_results(test, expected, actual, passed) values ('P6c update diretto su leagues', 'rifiutato', 'rifiutato: ' || sqlerrm, true);
  end;

  begin
    set local role authenticated;
    set local request.jwt.claim.sub = '31e2df43-b49a-4b56-af0a-78aff50a9dd6';
    insert into public.league_members (league_id, user_id, role) values (v_public_league_id, '31e2df43-b49a-4b56-af0a-78aff50a9dd6', 'member');
    reset role;
    insert into test_results(test, expected, actual, passed) values ('P6c insert diretto su league_members', 'rifiutato', 'NON rifiutato (BUG)', false);
  exception when insufficient_privilege then
    reset role;
    insert into test_results(test, expected, actual, passed) values ('P6c insert diretto su league_members', 'rifiutato', 'rifiutato: ' || sqlerrm, true);
  end;

  begin
    set local role authenticated;
    set local request.jwt.claim.sub = '560f6bd4-6070-4f6a-a78e-676cb4b8c7c4';
    update public.league_members set role = 'owner' where league_id = v_league_id and user_id = '560f6bd4-6070-4f6a-a78e-676cb4b8c7c4';
    reset role;
    insert into test_results(test, expected, actual, passed) values ('P6c update diretto su league_members', 'rifiutato', 'NON rifiutato (BUG)', false);
  exception when insufficient_privilege then
    reset role;
    insert into test_results(test, expected, actual, passed) values ('P6c update diretto su league_members', 'rifiutato', 'rifiutato: ' || sqlerrm, true);
  end;

  begin
    set local role authenticated;
    set local request.jwt.claim.sub = '560f6bd4-6070-4f6a-a78e-676cb4b8c7c4';
    insert into public.league_invites (league_id, code) values (v_public_league_id, 'HACKEDXXX');
    reset role;
    insert into test_results(test, expected, actual, passed) values ('P6c insert diretto su league_invites', 'rifiutato', 'NON rifiutato (BUG)', false);
  exception when insufficient_privilege then
    reset role;
    insert into test_results(test, expected, actual, passed) values ('P6c insert diretto su league_invites', 'rifiutato', 'rifiutato: ' || sqlerrm, true);
  end;

  begin
    set local role authenticated;
    set local request.jwt.claim.sub = '560f6bd4-6070-4f6a-a78e-676cb4b8c7c4';
    update public.league_invites set code = 'HACKEDXXX' where league_id = v_league_id;
    reset role;
    insert into test_results(test, expected, actual, passed) values ('P6c update diretto su league_invites', 'rifiutato', 'NON rifiutato (BUG)', false);
  exception when insufficient_privilege then
    reset role;
    insert into test_results(test, expected, actual, passed) values ('P6c update diretto su league_invites', 'rifiutato', 'rifiutato: ' || sqlerrm, true);
  end;

  set local role authenticated;
  set local request.jwt.claim.sub = '31e2df43-b49a-4b56-af0a-78aff50a9dd6';
  select outcome into v_result_bad from public.join_private_league('CODICESBAGLIATOX');
  select outcome into v_result_ok from public.join_private_league(v_code);
  reset role;

  insert into test_results(test, expected, actual, passed) values
    ('P6c join_private_league codice sbagliato -> invalid', 'invalid', v_result_bad, v_result_bad = 'invalid'),
    ('P6c join_private_league codice giusto -> ok', 'ok', v_result_ok, v_result_ok = 'ok');
end $$;

-- P6d: chi entra (codice o lega pubblica) ha sempre ruolo 'member'; update
-- diretto del ruolo rifiutato.
do $$
declare
  v_pub_id uuid;
  v_priv_id uuid;
  v_code text;
  v_role_after_public text;
  v_role_after_private text;
begin
  set local role authenticated;
  set local request.jwt.claim.sub = '560f6bd4-6070-4f6a-a78e-676cb4b8c7c4';
  v_pub_id := public.create_league('Test lega pubblica ruolo d', 'public', public.open_round_number());
  v_priv_id := public.create_league('Test lega privata ruolo d', 'private', public.open_round_number());
  reset role;

  select code into v_code from public.league_invites where league_id = v_priv_id;

  set local role authenticated;
  set local request.jwt.claim.sub = '31e2df43-b49a-4b56-af0a-78aff50a9dd6';
  perform public.join_public_league(v_pub_id);
  perform public.join_private_league(v_code);
  reset role;

  select role into v_role_after_public from public.league_members where league_id = v_pub_id and user_id = '31e2df43-b49a-4b56-af0a-78aff50a9dd6';
  select role into v_role_after_private from public.league_members where league_id = v_priv_id and user_id = '31e2df43-b49a-4b56-af0a-78aff50a9dd6';

  insert into test_results(test, expected, actual, passed) values
    ('P6d ruolo dopo join pubblica = member', 'member', v_role_after_public, v_role_after_public = 'member'),
    ('P6d ruolo dopo join privata (codice) = member', 'member', v_role_after_private, v_role_after_private = 'member');

  begin
    set local role authenticated;
    set local request.jwt.claim.sub = '31e2df43-b49a-4b56-af0a-78aff50a9dd6';
    update public.league_members set role = 'owner' where league_id = v_pub_id and user_id = '31e2df43-b49a-4b56-af0a-78aff50a9dd6';
    reset role;
    insert into test_results(test, expected, actual, passed) values ('P6d update diretto del ruolo', 'rifiutato', 'NON rifiutato (BUG)', false);
  exception when insufficient_privilege then
    reset role;
    insert into test_results(test, expected, actual, passed) values ('P6d update diretto del ruolo', 'rifiutato', 'rifiutato: ' || sqlerrm, true);
  end;
end $$;

-- P6e: azioni dell'owner complete (remove membro, remove owner, leave come
-- owner/membro, rigenera codice, elimina lega con pulizia a cascata).
do $$
declare
  v_league_id uuid;
  v_code_old text;
  v_code_new text;
  v_remove_result text;
  v_remove_owner_result text;
  v_leave_owner_result text;
  v_leave_member_result text;
  v_old_code_join_result text;
  v_delete_result text;
  v_members_after int;
  v_invites_after int;
begin
  set local role authenticated;
  set local request.jwt.claim.sub = '560f6bd4-6070-4f6a-a78e-676cb4b8c7c4';
  v_league_id := public.create_league('Test lega azioni owner e', 'private', public.open_round_number());
  reset role;

  select code into v_code_old from public.league_invites where league_id = v_league_id;

  set local role authenticated;
  set local request.jwt.claim.sub = '31e2df43-b49a-4b56-af0a-78aff50a9dd6';
  perform public.join_private_league(v_code_old);
  reset role;

  set local role authenticated;
  set local request.jwt.claim.sub = '560f6bd4-6070-4f6a-a78e-676cb4b8c7c4';
  v_remove_result := public.remove_league_member(v_league_id, '31e2df43-b49a-4b56-af0a-78aff50a9dd6');
  v_remove_owner_result := public.remove_league_member(v_league_id, '560f6bd4-6070-4f6a-a78e-676cb4b8c7c4');
  v_leave_owner_result := public.leave_league(v_league_id);
  reset role;

  set local role authenticated;
  set local request.jwt.claim.sub = '31e2df43-b49a-4b56-af0a-78aff50a9dd6';
  perform public.join_private_league(v_code_old);
  v_leave_member_result := public.leave_league(v_league_id);
  reset role;

  set local role authenticated;
  set local request.jwt.claim.sub = '560f6bd4-6070-4f6a-a78e-676cb4b8c7c4';
  v_code_new := public.regenerate_invite_code(v_league_id);
  reset role;

  set local role authenticated;
  set local request.jwt.claim.sub = '31e2df43-b49a-4b56-af0a-78aff50a9dd6';
  select outcome into v_old_code_join_result from public.join_private_league(v_code_old);
  reset role;

  set local role authenticated;
  set local request.jwt.claim.sub = '560f6bd4-6070-4f6a-a78e-676cb4b8c7c4';
  v_delete_result := public.delete_league(v_league_id);
  reset role;

  select count(*) into v_members_after from public.league_members where league_id = v_league_id;
  select count(*) into v_invites_after from public.league_invites where league_id = v_league_id;

  insert into test_results(test, expected, actual, passed) values
    ('P6e remove_league_member su un membro -> ok', 'ok', v_remove_result, v_remove_result = 'ok'),
    ('P6e remove_league_member sull''owner -> forbidden', 'forbidden', v_remove_owner_result, v_remove_owner_result = 'forbidden'),
    ('P6e leave_league come owner -> owner_cannot_leave', 'owner_cannot_leave', v_leave_owner_result, v_leave_owner_result = 'owner_cannot_leave'),
    ('P6e leave_league come membro -> ok', 'ok', v_leave_member_result, v_leave_member_result = 'ok'),
    ('P6e regenerate_invite_code: nuovo codice 8 caratteri', '8', char_length(v_code_new)::text, char_length(v_code_new) = 8),
    ('P6e regenerate_invite_code: nuovo diverso dal vecchio', 'true', (v_code_new <> v_code_old)::text, v_code_new <> v_code_old),
    ('P6e vecchio codice non entra più', 'invalid', v_old_code_join_result, v_old_code_join_result = 'invalid'),
    ('P6e delete_league -> ok', 'ok', v_delete_result, v_delete_result = 'ok'),
    ('P6e dopo delete_league: 0 righe league_members', '0', v_members_after::text, v_members_after = 0),
    ('P6e dopo delete_league: 0 righe league_invites', '0', v_invites_after::text, v_invites_after = 0);
end $$;

-- ========== open_round_number(): turno aperto, stati della vista calendar ==========
-- (N1-N3 girano PRIMA di P6f: P6f blocca in transazione il turno aperto, e dopo non
--  ci sarebbero turni 'futuro' da verificare.)

-- N1: coerenza degli stati della vista calendar con le due definizioni di turno.
-- Nessun id o numero di turno scritto a mano: tutto derivato dal DB.
do $$
declare
  v_open int := public.open_round_number();
  v_bad int;
  v_n_correnti int;
  v_correnti_ok boolean;
  v_n_futuri int;
begin
  select count(*) into v_bad
  from public.calendar c
  where (c.round_status = 'giocato' and exists (
           select 1 from public.matches m where m.round_number = c.round_number and m.home_goals is null))
     or (c.round_status = 'in_corso' and (c.locks_at > now() or not exists (
           select 1 from public.matches m where m.round_number = c.round_number and m.home_goals is null)))
     or (c.round_status = 'futuro' and (c.locks_at <= now() or (v_open is not null and c.round_number <= v_open)))
     or (c.round_status = 'corrente' and c.round_number is distinct from v_open);
  insert into test_results(test, expected, actual, passed)
    values ('N1 stati calendar coerenti (giocato / in_corso / corrente / futuro)', '0 righe incoerenti', v_bad::text, v_bad = 0);

  select count(distinct round_number) into v_n_correnti from public.calendar where round_status = 'corrente';
  v_correnti_ok := v_n_correnti = case when v_open is null then 0 else 1 end;
  insert into test_results(test, expected, actual, passed)
    values ('N1 al massimo un turno corrente (uno se esiste un turno aperto)', case when v_open is null then '0' else '1' end, v_n_correnti::text, v_correnti_ok);
  select count(distinct round_number) into v_n_futuri from public.calendar where round_status = 'futuro';
  insert into test_results(test, expected, actual, passed)
    values ('N1 copertura: esiste almeno un turno futuro da verificare', '>= 1', v_n_futuri::text, v_n_futuri >= 1);
end $$;

-- N2: open_round_number() e' il piu' basso con locks_at futuro; tutti i turni piu' bassi sono bloccati.
do $$
declare
  v_open int := public.open_round_number();
  v_lower_open int;
begin
  select count(*) into v_lower_open from public.rounds where round_number < v_open and locks_at > now();
  insert into test_results(test, expected, actual, passed)
    values ('N2 nessun turno piu'' basso di open_round_number() e'' ancora aperto', '0', v_lower_open::text, v_lower_open = 0);
  insert into test_results(test, expected, actual, passed)
    values ('N2 open_round_number() ha locks_at nel futuro', 'true',
            (select (locks_at > now())::text from public.rounds where round_number = v_open),
            (select locks_at > now() from public.rounds where round_number = v_open));
end $$;

-- N3: create_league sul turno chiuso (quello subito prima del turno aperto) rifiutata;
-- sul turno aperto e sul successivo accettata.
do $$
declare
  v_open int := public.open_round_number();
  v_closed int := v_open - 1;
  v_next int;
  v_rejected boolean := false;
  v_msg text := '';
  v_ok_open boolean := false;
  v_ok_next boolean := false;
begin
  select min(round_number) into v_next from public.rounds where round_number > v_open;

  if v_closed >= 1 then
    begin
      set local role authenticated;
      set local request.jwt.claim.sub = '560f6bd4-6070-4f6a-a78e-676cb4b8c7c4';
      perform public.create_league('Test turno chiuso N3', 'public', v_closed);
    exception when raise_exception then
      v_rejected := true;
      v_msg := sqlerrm;
    end;
    reset role;
    insert into test_results(test, expected, actual, passed)
      values ('N3 create_league su turno chiuso -> rifiutata', 'rifiutata: turno chiuso', case when v_rejected then 'rifiutata: ' || v_msg else 'NON rifiutata (BUG)' end,
              v_rejected and v_msg like '%già chiuso%');
  end if;

  set local role authenticated;
  set local request.jwt.claim.sub = '560f6bd4-6070-4f6a-a78e-676cb4b8c7c4';
  perform public.create_league('Test turno aperto N3', 'public', v_open);
  v_ok_open := true;
  if v_next is not null then
    perform public.create_league('Test turno successivo N3', 'public', v_next);
    v_ok_next := true;
  end if;
  reset role;
  insert into test_results(test, expected, actual, passed)
    values ('N3 create_league sul turno aperto -> accettata', 'true', v_ok_open::text, v_ok_open);
  if v_next is not null then
    insert into test_results(test, expected, actual, passed)
      values ('N3 create_league sul turno successivo -> accettata', 'true', v_ok_next::text, v_ok_next);
  end if;
end $$;

-- P6f: league_leaderboard con start_round = primo turno APERTO, utenti
-- sintetici D ed E (creati in cima, vivono solo in questa transazione) e
-- risultati FINTI scritti sulle partite del turno aperto (annullati dal
-- rollback finale). Cosi' i dati reali (pronostici veri di A/B, risultati
-- veri, leghe vere) non entrano mai nei punti attesi, e il test non si rompe
-- quando qualcuno pronostica per davvero il turno aperto. Se non ci sono turni
-- aperti (fine stagione) si usa l'ultimo turno: con utenti sintetici e
-- risultati finti la scelta e' indifferente.
-- Le leghe sono create con un INSERT diretto da amministratore (non con
-- create_league): qui l'oggetto del test e' league_leaderboard, non la
-- validazione dello start_round (gia' coperta da P5m). D resta owner, E entra
-- via funzione.
-- I pronostici sono globali (non per lega, vedi CLAUDE.md): i tre scenari
-- condividono lo stesso stato cumulativo, quindi l'ordine conta ed e':
--   1) scenario 3 (E senza pronostici) va fatto PRIMA che E riceva punti;
--   2) scenario 1 (pareggio) si ottiene facendo pronosticare a E la STESSA
--      partita con lo STESSO risultato di D, cosi' il pareggio e' vero
--      (stesso totale E stessa composizione esatti/esiti);
--   3) scenario 2 aggiunge un secondo esatto a D e tre esiti a E: stesso
--      totale, D avanti per piu' esatti.
-- Il turno precedente a start_round riceve pronostici con punti DIVERSI per D
-- ed E: non deve contare (verifica del filtro start_round).
-- Risultati finti: m1 2-0, m2 3-0, m3/m4/m5 1-1 (turno aperto); p1 5-3
-- (turno precedente).
do $$
declare
  v_start int;
  v_prev int;
  m1 text; m2 text; m3 text; m4 text; m5 text; p1 text;
  v_league_f3 uuid;
  v_league_f1 uuid;
  v_league_f2 uuid;
  r record;
  v_rows_f3 text := '';
  v_rows_f1 text := '';
  v_rows_f2 text := '';
begin
  select coalesce(
           public.open_round_number(),
           (select max(round_number) from public.rounds)
         ) into v_start;
  v_prev := v_start - 1;

  select (array_agg(id order by kickoff, id))[1], (array_agg(id order by kickoff, id))[2],
         (array_agg(id order by kickoff, id))[3], (array_agg(id order by kickoff, id))[4],
         (array_agg(id order by kickoff, id))[5]
    into m1, m2, m3, m4, m5
  from public.matches where round_number = v_start;
  select id into p1 from public.matches where round_number = v_prev order by kickoff, id limit 1;

  if m5 is null or p1 is null then
    raise exception 'P6f: servono >=5 partite nel turno % e >=1 nel turno %', v_start, v_prev;
  end if;

  -- Simula il blocco del turno scelto: i risultati esistono solo dopo il
  -- blocco e la RLS nasconde i pronostici altrui finche' il turno e' aperto
  -- (comportamento corretto, vedi P2d). Anticipare i kickoff e' consentito dal
  -- trigger (rifiuta solo di spostarli piu' avanti) e locks_at si ricalcola.
  update public.matches set kickoff = kickoff - interval '60 days' where round_number = v_start;

  -- risultati finti (solo in questa transazione)
  update public.matches set home_goals = 2, away_goals = 0 where id = m1;
  update public.matches set home_goals = 3, away_goals = 0 where id = m2;
  update public.matches set home_goals = 1, away_goals = 1 where id in (m3, m4, m5);
  update public.matches set home_goals = 5, away_goals = 3 where id = p1;

  -- D pronostica esatto su m1 (2-0) -> 3 punti
  insert into public.predictions (user_id, match_id, home_goals, away_goals)
  values ('00000000-0000-4000-8000-0000000000d1', m1, 2, 0);

  -- scenario 3: lega f3 (insert diretto, start_round = turno aperto), E si unisce ma non pronostica nulla
  insert into public.leagues (name, visibility, start_round, created_by)
  values ('Test leaderboard f3 zero punti', 'public', v_start, '00000000-0000-4000-8000-0000000000d1')
  returning id into v_league_f3;
  insert into public.league_members (league_id, user_id, role) values (v_league_f3, '00000000-0000-4000-8000-0000000000d1', 'owner');

  set local role authenticated;
  set local request.jwt.claim.sub = '00000000-0000-4000-8000-0000000000e1';
  perform public.join_public_league(v_league_f3);

  -- lettura come D (authenticated), non come amministratore: altrimenti si
  -- bypassa la RLS sottostante (league_leaderboard e' security invoker) e il
  -- test non dimostra cosa vede davvero un utente normale.
  set local request.jwt.claim.sub = '00000000-0000-4000-8000-0000000000d1';
  for r in select * from public.league_leaderboard(v_league_f3) order by rank, user_id loop
    v_rows_f3 := v_rows_f3 || format('%s: %s pt, %s esatti, %s esiti, rank %s | ', r.username, r.total_points, r.exact_results, r.correct_outcomes, r.rank);
  end loop;
  reset role;
  insert into test_results(test, expected, actual, passed)
    values ('P6f scenario3 (E senza pronostici): D>0 rank1, E=0 rank2 — letto da D/authenticated', 'D=3 rank1, E=0 rank2', v_rows_f3, v_rows_f3 like '%3 pt%rank 1%' and v_rows_f3 like '%0 pt%rank 2%');

  -- admin: E pronostica la STESSA partita, stesso risultato esatto di D -> pareggio vero
  insert into public.predictions (user_id, match_id, home_goals, away_goals)
  values ('00000000-0000-4000-8000-0000000000e1', m1, 2, 0);

  -- admin: turno precedente con punti DIVERSI per D ed E, non deve contare (start_round = turno aperto)
  insert into public.predictions (user_id, match_id, home_goals, away_goals) values
    ('00000000-0000-4000-8000-0000000000d1', p1, 5, 3),
    ('00000000-0000-4000-8000-0000000000e1', p1, 0, 0);

  insert into public.leagues (name, visibility, start_round, created_by)
  values ('Test leaderboard f1 pareggio', 'public', v_start, '00000000-0000-4000-8000-0000000000d1')
  returning id into v_league_f1;
  insert into public.league_members (league_id, user_id, role) values (v_league_f1, '00000000-0000-4000-8000-0000000000d1', 'owner');

  set local role authenticated;
  set local request.jwt.claim.sub = '00000000-0000-4000-8000-0000000000e1';
  perform public.join_public_league(v_league_f1);

  -- lettura come E (authenticated), per verificare anche questo lato
  declare v_distinct_ranks int;
  begin
    for r in select * from public.league_leaderboard(v_league_f1) order by rank, user_id loop
      v_rows_f1 := v_rows_f1 || format('%s: %s pt, %s esatti, %s esiti, rank %s | ', r.username, r.total_points, r.exact_results, r.correct_outcomes, r.rank);
    end loop;
    select count(distinct rank) into v_distinct_ranks from public.league_leaderboard(v_league_f1);
    reset role;
    insert into test_results(test, expected, actual, passed)
      values ('P6f scenario1 (pareggio vero, turno precedente escluso) — letto da E/authenticated', 'D ed E: 3 pt, rank 1 entrambi', v_rows_f1,
              v_rows_f1 like '%3 pt%rank 1%' and v_distinct_ranks = 1);
  end;

  -- admin: D aggiunge un secondo esatto (altra partita), E aggiunge 3 esiti
  -- corretti (pareggio diverso, partite diverse) -> stesso totale, D avanti
  -- per piu' esatti.
  insert into public.predictions (user_id, match_id, home_goals, away_goals)
  values ('00000000-0000-4000-8000-0000000000d1', m2, 3, 0);
  insert into public.predictions (user_id, match_id, home_goals, away_goals) values
    ('00000000-0000-4000-8000-0000000000e1', m3, 2, 2),
    ('00000000-0000-4000-8000-0000000000e1', m4, 0, 0),
    ('00000000-0000-4000-8000-0000000000e1', m5, 3, 3);

  insert into public.leagues (name, visibility, start_round, created_by)
  values ('Test leaderboard f2 tiebreak esatti', 'public', v_start, '00000000-0000-4000-8000-0000000000d1')
  returning id into v_league_f2;
  insert into public.league_members (league_id, user_id, role) values (v_league_f2, '00000000-0000-4000-8000-0000000000d1', 'owner');

  set local role authenticated;
  set local request.jwt.claim.sub = '00000000-0000-4000-8000-0000000000e1';
  perform public.join_public_league(v_league_f2);

  -- lettura come D (authenticated)
  set local request.jwt.claim.sub = '00000000-0000-4000-8000-0000000000d1';
  declare
    v_distinct_points int;
    v_rank_d int;
    v_rank_e int;
  begin
    for r in select * from public.league_leaderboard(v_league_f2) order by rank, user_id loop
      v_rows_f2 := v_rows_f2 || format('%s: %s pt, %s esatti, %s esiti, rank %s | ', r.username, r.total_points, r.exact_results, r.correct_outcomes, r.rank);
    end loop;
    select count(distinct total_points) into v_distinct_points from public.league_leaderboard(v_league_f2);
    select rank into v_rank_d from public.league_leaderboard(v_league_f2) where user_id = '00000000-0000-4000-8000-0000000000d1';
    select rank into v_rank_e from public.league_leaderboard(v_league_f2) where user_id = '00000000-0000-4000-8000-0000000000e1';
    reset role;
    insert into test_results(test, expected, actual, passed)
      values ('P6f scenario2 (stesso totale, D avanti per esatti) — letto da D/authenticated', 'stesso totale, rank diversi (D=1,E=2)', v_rows_f2,
              v_distinct_points = 1 and v_rank_d = 1 and v_rank_e = 2);
  end;
end $$;

-- P6h: anon rifiutato su tutte le tabelle e su tutte le 12 funzioni (9 +
-- helper); matrice has_function_privilege per anon/public/authenticated.
do $$
declare
  t text;
  rejected boolean;
begin
  foreach t in array array['leagues','league_members','league_invites','league_join_attempts']
  loop
    rejected := false;
    begin
      set local role anon;
      execute format('select count(*) from public.%I', t);
      reset role;
    exception when insufficient_privilege then
      rejected := true;
      reset role;
    end;
    insert into test_results(test, expected, actual, passed)
      values ('P6h anon select ' || t, 'rifiutato', case when rejected then 'rifiutato' else 'NON rifiutato (BUG)' end, rejected);
  end loop;
end $$;

do $$
declare
  calls text[] := array[
    $q$select public.create_league('x','public',999)$q$,
    $q$select public.join_private_league('XXXXXXXX')$q$,
    $q$select public.join_public_league('00000000-0000-0000-0000-000000000000'::uuid)$q$,
    $q$select public.leave_league('00000000-0000-0000-0000-000000000000'::uuid)$q$,
    $q$select public.remove_league_member('00000000-0000-0000-0000-000000000000'::uuid,'00000000-0000-0000-0000-000000000000'::uuid)$q$,
    $q$select public.regenerate_invite_code('00000000-0000-0000-0000-000000000000'::uuid)$q$,
    $q$select public.delete_league('00000000-0000-0000-0000-000000000000'::uuid)$q$,
    $q$select * from public.league_leaderboard('00000000-0000-0000-0000-000000000000'::uuid)$q$,
    $q$select * from public.list_public_leagues()$q$,
    $q$select public.is_league_member('00000000-0000-0000-0000-000000000000'::uuid)$q$,
    $q$select public.is_league_owner('00000000-0000-0000-0000-000000000000'::uuid)$q$,
    $q$select public.shares_league_with('00000000-0000-0000-0000-000000000000'::uuid)$q$,
    $q$select public.open_round_number()$q$,
    $q$select public.current_round_number()$q$
  ];
  labels text[] := array['create_league','join_private_league','join_public_league','leave_league','remove_league_member','regenerate_invite_code','delete_league','league_leaderboard','list_public_leagues','is_league_member','is_league_owner','shares_league_with','open_round_number','current_round_number'];
  i int;
  rejected boolean;
begin
  for i in 1..array_length(calls,1) loop
    rejected := false;
    begin
      set local role anon;
      execute calls[i];
      reset role;
    exception when insufficient_privilege then
      rejected := true;
      reset role;
    end;
    insert into test_results(test, expected, actual, passed)
      values ('P6h anon execute ' || labels[i], 'rifiutato', case when rejected then 'rifiutato' else 'NON rifiutato (BUG)' end, rejected);
  end loop;
end $$;

do $$
declare
  funcs text[] := array[
    'public.create_league(text,text,int)',
    'public.join_private_league(text)',
    'public.join_public_league(uuid)',
    'public.leave_league(uuid)',
    'public.remove_league_member(uuid,uuid)',
    'public.regenerate_invite_code(uuid)',
    'public.delete_league(uuid)',
    'public.league_leaderboard(uuid)',
    'public.list_public_leagues()',
    'public.is_league_member(uuid)',
    'public.is_league_owner(uuid)',
    'public.shares_league_with(uuid)',
    'public.open_round_number()',
    'public.current_round_number()'
  ];
  roles text[] := array['anon','public','authenticated'];
  expected_vals boolean[] := array[false,false,true];
  f text;
  j int;
  v_priv boolean;
begin
  foreach f in array funcs loop
    for j in 1..3 loop
      v_priv := has_function_privilege(roles[j], f::regprocedure, 'EXECUTE');
      insert into test_results(test, expected, actual, passed)
        values ('P6h has_function_privilege(' || roles[j] || ', ' || f || ')', expected_vals[j]::text, v_priv::text, v_priv = expected_vals[j]);
    end loop;
  end loop;
end $$;


-- ========== Riepilogo ==========

-- Una sola query (l'MCP execute_sql restituisce solo l'ultimo result set):
-- totali + elenco dei falliti + tutti i test in un unico json.
-- N4 (ultimo, cambia lo stato dei turni): con tutti i turni bloccati open_round_number()
-- e' NULL, la vista non ha turni 'corrente' e create_league e' rifiutata.
-- I kickoff si anticipano nella transazione (consentito dal trigger); il rollback finale li ripristina.
do $$
declare
  v_null boolean;
  v_correnti int;
  v_rejected boolean := false;
  v_msg text := '';
begin
  update public.matches set kickoff = kickoff - interval '400 days'
  where round_number in (select round_number from public.rounds where locks_at > now());

  v_null := public.open_round_number() is null;
  select count(*) into v_correnti from public.calendar where round_status = 'corrente';

  begin
    set local role authenticated;
    set local request.jwt.claim.sub = '560f6bd4-6070-4f6a-a78e-676cb4b8c7c4';
    perform public.create_league('Test nessun turno aperto N4', 'public', (select max(round_number) from public.rounds));
  exception when raise_exception then
    v_rejected := true;
    v_msg := sqlerrm;
  end;
  reset role;

  insert into test_results(test, expected, actual, passed) values
    ('N4 tutti i turni bloccati: open_round_number() NULL', 'true', v_null::text, v_null),
    ('N4 tutti i turni bloccati: nessun turno corrente nella vista', '0', v_correnti::text, v_correnti = 0),
    ('N4 tutti i turni bloccati: create_league rifiutata', 'rifiutata: nessun turno aperto', case when v_rejected then 'rifiutata: ' || v_msg else 'NON rifiutata (BUG)' end,
     v_rejected and v_msg like '%nessun turno aperto%');
end $$;

select
  count(*) as test_totali,
  count(*) filter (where not passed) as test_falliti,
  coalesce(jsonb_agg(jsonb_build_object('seq', seq, 'test', test, 'expected', expected, 'actual', actual)) filter (where not passed), '[]'::jsonb) as falliti,
  jsonb_agg(jsonb_build_object('seq', seq, 'test', test, 'passed', passed, 'actual', actual) order by seq) as tutti
from test_results;

rollback;
