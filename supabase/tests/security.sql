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
    ('00000000-0000-4000-8000-0000000000c1', 'r1-udinese-como', 1, 1)
  on conflict (user_id, match_id) do nothing; -- B puo' aver gia' pronosticato per davvero il turno aperto

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

-- ========== Migrazione 03a: creazione, calendario a cerchio, blocco degli ingressi ==========
-- Utenti sintetici D (creatore), E, F, G (membri o candidati) e C (estraneo); turno "aperto" derivato dal DB;
-- il blocco si simula anticipando i kickoff del turno nella transazione (annullata dal rollback finale).
do $$
declare
  v_open int := public.open_round_number();
  v_nrounds int;
  v_l1 uuid; v_code1 text; v_mode text; v_vis text; v_start int; v_owner int; v_inv int;
  v_rej_past boolean := false; v_rej_name boolean := false; v_rej_anon_create boolean := false; v_rej_anon_state boolean := false;
  v_rej_live boolean := false; v_rej_locked boolean := false; v_rej_gen boolean := false;
  v_join_pre text; v_status_pre text; v_warn_pre boolean; v_locked_pre boolean; v_c_rows_pre int;
  v_lc uuid; v_codec text; v_join_closed text; v_join_class text; v_members_l1 int;
  v_cm text; v_cs text; v_chome text;
  v_l3 uuid; v_sched_status text; v_sched_cycle int; v_sched_members int; v_pairs int; v_rests int; v_bad_round int; v_dup int; v_first3 int;
  v_pairs_after int; v_c_state int; v_c_pairs int; v_d_pairs int;
  v_ls uuid; v_ls_status text; v_ls_home text; v_ls_pairs int; v_ls_sched int;
  v_l1_status text; v_l1_pairs int; v_l1_rests int;
begin
  insert into auth.users (id) values ('00000000-0000-4000-8000-0000000000f1'), ('00000000-0000-4000-8000-0000000000f2');
  insert into public.profiles (id, username, crest_pattern) values
    ('00000000-0000-4000-8000-0000000000f1', 'utente_test_f', 'star'),
    ('00000000-0000-4000-8000-0000000000f2', 'utente_test_g', 'leaf');
  v_nrounds := 38 - v_open + 1;

  -- creazione (turno ancora aperto)
  set local role authenticated;
  set local request.jwt.claim.sub = '00000000-0000-4000-8000-0000000000d1';
  v_l1 := public.create_h2h_league('Test scontri creata ST10', v_open);
  begin perform public.create_h2h_league('Test passato ST10', v_open - 1); exception when raise_exception then v_rej_past := true; end;
  begin perform public.create_h2h_league('ab', v_open); exception when raise_exception then v_rej_name := true; end;
  reset role;
  select mode, visibility, start_round into v_mode, v_vis, v_start from public.leagues where id = v_l1;
  select count(*) into v_owner from public.league_members where league_id = v_l1 and user_id = '00000000-0000-4000-8000-0000000000d1' and role = 'owner';
  select count(*) into v_inv from public.league_invites where league_id = v_l1;
  select code into v_code1 from public.league_invites where league_id = v_l1;
  insert into test_results(test, expected, actual, passed) values
    ('ST10 create_h2h_league: lega scontri privata sul turno aperto', 'scontri/private/' || v_open, v_mode || '/' || v_vis || '/' || v_start, v_mode = 'scontri' and v_vis = 'private' and v_start = v_open),
    ('ST10 create_h2h_league: il creatore e'' owner e c''e'' un codice', '1 owner, 1 codice', v_owner || ' owner, ' || v_inv || ' codice', v_owner = 1 and v_inv = 1),
    ('ST10 create_h2h_league: turno di partenza gia'' chiuso rifiutato', 'rifiutato', v_rej_past::text, v_rej_past),
    ('ST10 create_h2h_league: nome troppo corto rifiutato', 'rifiutato', v_rej_name::text, v_rej_name);

  -- prima del blocco: ingresso libero, stato in attesa, non membro non vede nulla
  set local role authenticated;
  set local request.jwt.claim.sub = '00000000-0000-4000-8000-0000000000e1';
  select outcome into v_join_pre from public.join_private_league(v_code1);
  set local request.jwt.claim.sub = '00000000-0000-4000-8000-0000000000d1';
  select status, warn_not_starting, is_locked into v_status_pre, v_warn_pre, v_locked_pre from public.h2h_league_state(v_l1);
  set local request.jwt.claim.sub = '00000000-0000-4000-8000-0000000000c1';
  select count(*) into v_c_rows_pre from public.h2h_league_state(v_l1);
  reset role;
  insert into test_results(test, expected, actual, passed) values
    ('ST10 lega a scontri prima del blocco: l''ingresso con codice funziona', 'ok', v_join_pre, v_join_pre = 'ok'),
    ('ST10 stato prima del blocco: in_attesa, non bloccata, nessun avviso (2 membri)', 'in_attesa/false/false', v_status_pre || '/' || v_locked_pre || '/' || v_warn_pre, v_status_pre = 'in_attesa' and not v_locked_pre and not v_warn_pre),
    ('ST10 h2h_league_state: un non membro non ottiene righe', '0', v_c_rows_pre::text, v_c_rows_pre = 0);

  -- lega a classifica con lo stesso turno di partenza
  insert into public.leagues (name, visibility, start_round, created_by)
  values ('Test classifica libera ST10', 'private', v_open, '00000000-0000-4000-8000-0000000000d1') returning id into v_lc;
  insert into public.league_members (league_id, user_id, role) values (v_lc, '00000000-0000-4000-8000-0000000000d1', 'owner');
  v_codec := public.generate_invite_code();
  insert into public.league_invites (league_id, code) values (v_lc, v_codec);

  -- il turno si blocca: kickoff anticipati
  update public.matches set kickoff = kickoff - interval '60 days' where round_number = v_open;

  set local role authenticated;
  set local request.jwt.claim.sub = '00000000-0000-4000-8000-0000000000f1';
  select outcome into v_join_closed from public.join_private_league(v_code1);
  select outcome into v_join_class from public.join_private_league(v_codec);
  reset role;
  select count(*) into v_members_l1 from public.league_members where league_id = v_l1;
  insert into test_results(test, expected, actual, passed) values
    ('ST10 lega a scontri con turno di partenza bloccato: ingresso -> closed', 'closed', v_join_closed, v_join_closed = 'closed'),
    ('ST10 ...e il membro non viene aggiunto', '2', v_members_l1::text, v_members_l1 = 2),
    ('ST10 lega a classifica con turno di partenza bloccato: ingresso libero -> ok', 'ok', v_join_class, v_join_class = 'ok');

  -- stato di una lega a classifica: nessuno stato scontri
  set local role authenticated;
  set local request.jwt.claim.sub = '00000000-0000-4000-8000-0000000000d1';
  select mode, status, home_state into v_cm, v_cs, v_chome from public.h2h_league_state(v_lc);
  reset role;
  insert into test_results(test, expected, actual, passed) values
    ('ST10 h2h_league_state su lega a classifica: mode classifica, nessuno stato scontri', 'classifica/null/null', v_cm || '/' || coalesce(v_cs,'null') || '/' || coalesce(v_chome,'null'), v_cm = 'classifica' and v_cs is null and v_chome is null);

  -- calendario a cerchio, 3 membri (dispari): D, E, F
  insert into public.leagues (name, visibility, mode, start_round, created_by)
  values ('Test scontri tre membri ST10', 'private', 'scontri', v_open, '00000000-0000-4000-8000-0000000000d1') returning id into v_l3;
  insert into public.league_members (league_id, user_id, role) values
    (v_l3, '00000000-0000-4000-8000-0000000000d1', 'owner'),
    (v_l3, '00000000-0000-4000-8000-0000000000e1', 'member'),
    (v_l3, '00000000-0000-4000-8000-0000000000f1', 'member');
  set local role authenticated;
  set local request.jwt.claim.sub = '00000000-0000-4000-8000-0000000000d1';
  perform * from public.h2h_league_state(v_l3);
  select count(*) into v_d_pairs from public.league_h2h_pairings where league_id = v_l3;
  set local request.jwt.claim.sub = '00000000-0000-4000-8000-0000000000c1';
  select count(*) into v_c_state from public.h2h_league_state(v_l3);
  select count(*) into v_c_pairs from public.league_h2h_pairings where league_id = v_l3;
  set local request.jwt.claim.sub = '00000000-0000-4000-8000-0000000000e1';
  perform * from public.h2h_league_state(v_l3);
  reset role;
  select status, cycle_length, member_count into v_sched_status, v_sched_cycle, v_sched_members from public.league_h2h_schedule where league_id = v_l3;
  select count(*), count(*) filter (where user_b is null) into v_pairs, v_rests from public.league_h2h_pairings where league_id = v_l3;
  v_pairs_after := v_pairs;
  select count(*) into v_bad_round from (select round_number from public.league_h2h_pairings where league_id = v_l3 group by round_number having count(*) filter (where user_b is null) <> 1 or count(*) <> 2) q;
  select count(*) into v_dup from (
    select round_number, u from (
      select round_number, user_a as u from public.league_h2h_pairings where league_id = v_l3
      union all select round_number, user_b from public.league_h2h_pairings where league_id = v_l3 and user_b is not null) x
    group by round_number, u having count(*) > 1) q;
  select count(distinct user_a) into v_first3 from public.league_h2h_pairings where league_id = v_l3 and user_b is null and round_number between v_open and v_open + 2;
  insert into test_results(test, expected, actual, passed) values
    ('ST10 calendario 3 membri: avviata, ciclo di 3 turni, 3 membri', 'avviata/3/3', v_sched_status || '/' || v_sched_cycle || '/' || v_sched_members, v_sched_status = 'avviata' and v_sched_cycle = 3 and v_sched_members = 3),
    ('ST10 calendario 3 membri: 2 abbinamenti per turno dal turno di partenza al 38', (v_nrounds * 2)::text, v_pairs::text, v_pairs = v_nrounds * 2),
    ('ST10 calendario 3 membri: un solo riposo a turno', v_nrounds::text, v_rests::text, v_rests = v_nrounds and v_bad_round = 0),
    ('ST10 calendario 3 membri: nessuno compare due volte nello stesso turno', '0', v_dup::text, v_dup = 0),
    ('ST10 calendario 3 membri: ognuno riposa esattamente una volta nel primo ciclo', '3', v_first3::text, v_first3 = 3),
    ('ST10 calendario: una seconda lettura non lo cambia (idempotente)', v_pairs::text, v_pairs_after::text, (select count(*) from public.league_h2h_pairings where league_id = v_l3) = v_pairs),
    ('ST10 calendario: il membro D vede tutti gli abbinamenti', (v_nrounds * 2)::text, v_d_pairs::text, v_d_pairs = v_nrounds * 2),
    ('ST10 calendario: un non membro non vede stato ne'' abbinamenti', '0/0', v_c_state || '/' || v_c_pairs, v_c_state = 0 and v_c_pairs = 0);

  -- lega a scontri con un solo membro al blocco: non avviata
  insert into public.leagues (name, visibility, mode, start_round, created_by)
  values ('Test scontri un membro ST10', 'private', 'scontri', v_open, '00000000-0000-4000-8000-0000000000d1') returning id into v_ls;
  insert into public.league_members (league_id, user_id, role) values (v_ls, '00000000-0000-4000-8000-0000000000d1', 'owner');
  set local role authenticated;
  set local request.jwt.claim.sub = '00000000-0000-4000-8000-0000000000d1';
  select status, home_state into v_ls_status, v_ls_home from public.h2h_league_state(v_ls);
  select count(*) into v_ls_pairs from public.league_h2h_pairings where league_id = v_ls;
  select count(*) into v_ls_sched from public.league_h2h_schedule where league_id = v_ls and status = 'non_avviata';
  -- lega a due membri (v_l1, bloccata dopo l'ingresso di E): avviata, un abbinamento a turno, nessun riposo
  select status into v_l1_status from public.h2h_league_state(v_l1);
  select count(*), count(*) filter (where user_b is null) into v_l1_pairs, v_l1_rests from public.league_h2h_pairings where league_id = v_l1;
  reset role;
  insert into test_results(test, expected, actual, passed) values
    ('ST10 un solo membro al blocco: non_avviata, nessun abbinamento', 'non_avviata/non_avviata/0/1', v_ls_status || '/' || v_ls_home || '/' || v_ls_pairs || '/' || v_ls_sched, v_ls_status = 'non_avviata' and v_ls_home = 'non_avviata' and v_ls_pairs = 0 and v_ls_sched = 1),
    ('ST10 due membri: avviata, un abbinamento a turno, nessun riposo', 'avviata/' || v_nrounds || '/0', v_l1_status || '/' || v_l1_pairs || '/' || v_l1_rests, v_l1_status = 'avviata' and v_l1_pairs = v_nrounds and v_l1_rests = 0);

  -- privilegi: anon non chiama le funzioni; authenticated non chiama le interne
  begin set local role anon; perform public.create_h2h_league('Test anon ST10', v_open); reset role;
  exception when insufficient_privilege then reset role; v_rej_anon_create := true; end;
  begin set local role anon; perform * from public.h2h_league_state(v_l3); reset role;
  exception when insufficient_privilege then reset role; v_rej_anon_state := true; end;
  begin set local role authenticated; set local request.jwt.claim.sub = '00000000-0000-4000-8000-0000000000d1'; perform public.round_live_number(); reset role;
  exception when insufficient_privilege then reset role; v_rej_live := true; end;
  begin set local role authenticated; set local request.jwt.claim.sub = '00000000-0000-4000-8000-0000000000d1'; perform public.h2h_is_locked(v_l3); reset role;
  exception when insufficient_privilege then reset role; v_rej_locked := true; end;
  begin set local role authenticated; set local request.jwt.claim.sub = '00000000-0000-4000-8000-0000000000d1'; perform public.h2h_generate_schedule(v_l3); reset role;
  exception when insufficient_privilege then reset role; v_rej_gen := true; end;
  insert into test_results(test, expected, actual, passed) values
    ('ST10 anon: create_h2h_league rifiutata', 'rifiutato', v_rej_anon_create::text, v_rej_anon_create),
    ('ST10 anon: h2h_league_state rifiutata', 'rifiutato', v_rej_anon_state::text, v_rej_anon_state),
    ('ST10 authenticated: round_live_number (interna) rifiutata', 'rifiutato', v_rej_live::text, v_rej_live),
    ('ST10 authenticated: h2h_is_locked (interna) rifiutata', 'rifiutato', v_rej_locked::text, v_rej_locked),
    ('ST10 authenticated: h2h_generate_schedule (interna) rifiutata', 'rifiutato', v_rej_gen::text, v_rej_gen);
end $$;

-- ========== Migrazione 03b: uscite e rimozioni (blocco solo per le leghe a scontri) ==========
do $$
declare
  v_open int := public.open_round_number();
  v_h1 uuid; v_h2 uuid; v_c1 uuid;
  v_leave_pre text; v_remove_pre text; v_rejoin text;
  v_leave_lock text; v_remove_lock text; v_owner_leave text; v_members_lock int;
  v_leave_cls text; v_remove_cls text; v_members_cls int;
  v_remove_nonowner text; v_remove_unknown text;
  v_code1 text;
begin
  -- D owner, E, F, G membri; tutto creato da amministratore (turno ancora aperto)
  insert into auth.users (id) values ('00000000-0000-4000-8000-0000000000a1') on conflict do nothing;
  insert into public.profiles (id, username, crest_pattern) values ('00000000-0000-4000-8000-0000000000a1', 'utente_test_h', 'star') on conflict do nothing;
  insert into public.leagues (name, visibility, mode, start_round, created_by) values ('Test scontri uscite prima ST11', 'private', 'scontri', v_open, '00000000-0000-4000-8000-0000000000d1') returning id into v_h1;
  insert into public.league_members (league_id, user_id, role) values
    (v_h1, '00000000-0000-4000-8000-0000000000d1', 'owner'),
    (v_h1, '00000000-0000-4000-8000-0000000000e1', 'member'),
    (v_h1, '00000000-0000-4000-8000-0000000000a1', 'member');
  insert into public.leagues (name, visibility, mode, start_round, created_by) values ('Test scontri uscite bloccata ST11', 'private', 'scontri', v_open, '00000000-0000-4000-8000-0000000000d1') returning id into v_h2;
  insert into public.league_members (league_id, user_id, role) values
    (v_h2, '00000000-0000-4000-8000-0000000000d1', 'owner'),
    (v_h2, '00000000-0000-4000-8000-0000000000e1', 'member'),
    (v_h2, '00000000-0000-4000-8000-0000000000a1', 'member');
  insert into public.leagues (name, visibility, start_round, created_by) values ('Test classifica uscite ST11', 'private', v_open, '00000000-0000-4000-8000-0000000000d1') returning id into v_c1;
  insert into public.league_members (league_id, user_id, role) values
    (v_c1, '00000000-0000-4000-8000-0000000000d1', 'owner'),
    (v_c1, '00000000-0000-4000-8000-0000000000e1', 'member'),
    (v_c1, '00000000-0000-4000-8000-0000000000a1', 'member');

  -- prima del blocco (lega a scontri): uscita e rimozione funzionano
  set local role authenticated;
  set local request.jwt.claim.sub = '00000000-0000-4000-8000-0000000000e1';
  v_leave_pre := public.leave_league(v_h1);
  set local request.jwt.claim.sub = '00000000-0000-4000-8000-0000000000d1';
  v_remove_pre := public.remove_league_member(v_h1, '00000000-0000-4000-8000-0000000000a1');
  v_remove_nonowner := public.remove_league_member(v_h1, '00000000-0000-4000-8000-0000000000c1');
  reset role;

  -- il turno si blocca
  update public.matches set kickoff = kickoff - interval '60 days' where round_number = v_open;

  -- lega a scontri bloccata
  set local role authenticated;
  set local request.jwt.claim.sub = '00000000-0000-4000-8000-0000000000e1';
  v_leave_lock := public.leave_league(v_h2);
  set local request.jwt.claim.sub = '00000000-0000-4000-8000-0000000000d1';
  v_remove_lock := public.remove_league_member(v_h2, '00000000-0000-4000-8000-0000000000a1');
  v_owner_leave := public.leave_league(v_h2);
  reset role;
  select count(*) into v_members_lock from public.league_members where league_id = v_h2;

  -- lega a classifica con turno di partenza bloccato: ancora libera
  set local role authenticated;
  set local request.jwt.claim.sub = '00000000-0000-4000-8000-0000000000e1';
  v_leave_cls := public.leave_league(v_c1);
  set local request.jwt.claim.sub = '00000000-0000-4000-8000-0000000000d1';
  v_remove_cls := public.remove_league_member(v_c1, '00000000-0000-4000-8000-0000000000a1');
  reset role;
  select count(*) into v_members_cls from public.league_members where league_id = v_c1;

  insert into test_results(test, expected, actual, passed) values
    ('ST11 lega a scontri prima del blocco: uscita di un membro -> ok', 'ok', v_leave_pre, v_leave_pre = 'ok'),
    ('ST11 lega a scontri prima del blocco: rimozione di un membro -> ok', 'ok', v_remove_pre, v_remove_pre = 'ok'),
    ('ST11 rimozione di chi non e'' membro -> not_member', 'not_member', v_remove_nonowner, v_remove_nonowner = 'not_member'),
    ('ST11 lega a scontri bloccata: uscita -> locked', 'locked', v_leave_lock, v_leave_lock = 'locked'),
    ('ST11 lega a scontri bloccata: rimozione di un membro -> locked', 'locked', v_remove_lock, v_remove_lock = 'locked'),
    ('ST11 lega a scontri bloccata: il creatore non puo'' uscire', 'owner_cannot_leave', v_owner_leave, v_owner_leave = 'owner_cannot_leave'),
    ('ST11 lega a scontri bloccata: nessun membro perso', '3', v_members_lock::text, v_members_lock = 3),
    ('ST11 lega a classifica con turno bloccato: uscita -> ok', 'ok', v_leave_cls, v_leave_cls = 'ok'),
    ('ST11 lega a classifica con turno bloccato: rimozione -> ok', 'ok', v_remove_cls, v_remove_cls = 'ok'),
    ('ST11 lega a classifica: restano solo il creatore', '1', v_members_cls::text, v_members_cls = 1);
end $$;

-- ========== Migrazione 04: letture degli scontri (elenco, risultati, classifica, dettaglio) ==========
-- Turno bloccato derivato dal DB (il piu' basso gia' bloccato con 10 partite); risultati e stati delle partite
-- scritti dentro la transazione (annullata dal rollback finale). D vince su E, A1 riposa.
do $$
declare
  v_r int; v_m text[]; v_l uuid;
  v_st1 text; v_prova int; v_fina int; v_provb int; v_finb int; v_pa1 int; v_pb1 int;
  v_zero1 boolean; v_det10_pa int; v_det10_pfa int; v_det10_pb int; v_det10_pfb int; v_det10_lock boolean; v_det1_pb int; v_det1_pfb int; v_det3_pred int; v_det3_pb int;
  v_st2 text; v_fina2 int; v_pa2 int; v_pb2 int; v_rest_is boolean; v_rest_pts int; v_rest_state text;
  v_d record; v_e record; v_a record; v_tied_e boolean; v_tied_a boolean; v_final boolean;
  v_c_p int; v_c_r int; v_c_s int; v_c_d int; v_mine boolean; v_first_rest boolean;
  v_rej1 boolean := false; v_rej2 boolean := false; v_rej3 boolean := false; v_rej4 boolean := false;
begin
  -- il turno bloccato PIU' BASSO con 10 partite: non interferisce con i turni usati dagli altri test (P6f usa gli ultimi)
  select min(r.round_number) into v_r from public.rounds r
   where r.locks_at <= now() and (select count(*) from public.matches m where m.round_number = r.round_number) = 10;
  select array_agg(id order by kickoff, id) into v_m from public.matches where round_number = v_r;
  update public.matches set status = 'non_iniziata', home_goals = null, away_goals = null where round_number = v_r;
  insert into auth.users (id) values ('00000000-0000-4000-8000-0000000000a1') on conflict do nothing;
  insert into public.profiles (id, username, crest_pattern) values ('00000000-0000-4000-8000-0000000000a1', 'utente_test_h', 'star') on conflict do nothing;
  insert into public.leagues (name, visibility, mode, start_round, created_by)
  values ('Test scontri risultati ST12', 'private', 'scontri', v_r, '00000000-0000-4000-8000-0000000000d1') returning id into v_l;
  insert into public.league_members (league_id, user_id, role) values
    (v_l, '00000000-0000-4000-8000-0000000000d1', 'owner'),
    (v_l, '00000000-0000-4000-8000-0000000000e1', 'member'),
    (v_l, '00000000-0000-4000-8000-0000000000a1', 'member');
  insert into public.league_h2h_schedule (league_id, status, start_round, member_count, cycle_length) values (v_l, 'avviata', v_r, 3, 3);
  insert into public.league_h2h_pairings (league_id, round_number, slot, user_a, user_b) values
    (v_l, v_r, 0, '00000000-0000-4000-8000-0000000000d1', '00000000-0000-4000-8000-0000000000e1'),
    (v_l, v_r, 1, '00000000-0000-4000-8000-0000000000a1', null);
  -- D: esatto (1-0) su tutte e 10; E: sbagliato (0-1) sulle partite 3..9, nessun pronostico sulle partite 1, 2 e 10; A1 (riposo): nessuno
  insert into public.predictions (user_id, match_id, home_goals, away_goals)
    select '00000000-0000-4000-8000-0000000000d1', unnest(v_m), 1, 0;
  insert into public.predictions (user_id, match_id, home_goals, away_goals)
    select '00000000-0000-4000-8000-0000000000e1', unnest(v_m[3:9]), 0, 1;

  -- fase 1: 9 partite finite 1-0, la decima IN CORSO 1-0 (turno non concluso)
  update public.matches set status = 'finita', home_goals = 1, away_goals = 0 where id = any (v_m[1:9]);
  update public.matches set status = 'in_corso', home_goals = 1, away_goals = 0 where id = v_m[10];
  set local role authenticated;
  set local request.jwt.claim.sub = '00000000-0000-4000-8000-0000000000d1';
  select round_state, prov_a, final_a, prov_b, final_b, h2h_pts_a, h2h_pts_b into v_st1, v_prova, v_fina, v_provb, v_finb, v_pa1, v_pb1
    from public.h2h_results(v_l) where slot = 0;
  select bool_and(pt_scontri = 0 and pt_totali = 0 and giocati = 0 and esatti = 0 and esiti = 0) into v_zero1 from public.h2h_standings(v_l);
  select points_a, points_final_a, points_b, points_final_b, round_locked into v_det10_pa, v_det10_pfa, v_det10_pb, v_det10_pfb, v_det10_lock
    from public.h2h_match_detail(v_l, v_r, 0::smallint) where match_id = v_m[10];
  select points_b, points_final_b into v_det1_pb, v_det1_pfb from public.h2h_match_detail(v_l, v_r, 0::smallint) where match_id = v_m[1];
  select pred_home_b, points_b into v_det3_pred, v_det3_pb from public.h2h_match_detail(v_l, v_r, 0::smallint) where match_id = v_m[3];
  reset role;
  insert into test_results(test, expected, actual, passed) values
    ('ST12 turno non concluso: stato in_corso, nessun punto scontri assegnato', 'in_corso/NULL/NULL', v_st1 || '/' || coalesce(v_pa1::text,'NULL') || '/' || coalesce(v_pb1::text,'NULL'), v_st1 = 'in_corso' and v_pa1 is null and v_pb1 is null),
    ('ST12 punti provvisori (con la partita in corso) e definitivi (solo finite) di D', '30/27', v_prova || '/' || v_fina, v_prova = 30 and v_fina = 27),
    ('ST12 E: nessun punto (sbagliato o non pronosticato)', '0/0', v_provb || '/' || v_finb, v_provb = 0 and v_finb = 0),
    ('ST12 classifica a turno non concluso: tutto a zero', 'true', coalesce(v_zero1::text,'NULL'), v_zero1),
    ('ST12 dettaglio, partita in corso con pronostico: provvisori 3, definitivi NULL', '3/NULL', coalesce(v_det10_pa::text,'NULL') || '/' || coalesce(v_det10_pfa::text,'NULL'), v_det10_pa = 3 and v_det10_pfa is null),
    ('ST12 dettaglio, partita in corso senza pronostico dell''avversario: NULL/NULL', 'NULL/NULL', coalesce(v_det10_pb::text,'NULL') || '/' || coalesce(v_det10_pfb::text,'NULL'), v_det10_pb is null and v_det10_pfb is null),
    ('ST12 dettaglio, partita finita senza pronostico: 0/0 (mai NULL)', '0/0', coalesce(v_det1_pb::text,'NULL') || '/' || coalesce(v_det1_pfb::text,'NULL'), v_det1_pb = 0 and v_det1_pfb = 0),
    ('ST12 dettaglio: il pronostico dell''avversario si vede dopo il blocco (0-1 sbagliato = 0 punti)', '0/0', coalesce(v_det3_pred::text,'NULL') || '/' || coalesce(v_det3_pb::text,'NULL'), v_det3_pred = 0 and v_det3_pb = 0),
    ('ST12 dettaglio: round_locked vero per il turno bloccato', 'true', coalesce(v_det10_lock::text,'NULL'), v_det10_lock);

  -- fase 2: tutte finite -> turno concluso
  update public.matches set status = 'finita' where id = v_m[10];
  set local role authenticated;
  set local request.jwt.claim.sub = '00000000-0000-4000-8000-0000000000d1';
  select round_state, final_a, h2h_pts_a, h2h_pts_b into v_st2, v_fina2, v_pa2, v_pb2 from public.h2h_results(v_l) where slot = 0;
  select is_rest, h2h_pts_a, round_state into v_rest_is, v_rest_pts, v_rest_state from public.h2h_results(v_l) where slot = 1;
  select * into v_d from public.h2h_standings(v_l) where user_id = '00000000-0000-4000-8000-0000000000d1';
  select * into v_e from public.h2h_standings(v_l) where user_id = '00000000-0000-4000-8000-0000000000e1';
  select * into v_a from public.h2h_standings(v_l) where user_id = '00000000-0000-4000-8000-0000000000a1';
  select is_final into v_final from public.h2h_standings(v_l) limit 1;
  set local request.jwt.claim.sub = '00000000-0000-4000-8000-0000000000a1';
  select is_mine, is_rest into v_mine, v_first_rest from public.h2h_pairings(v_l) where round_number = v_r order by is_mine desc, slot limit 1;
  set local request.jwt.claim.sub = '00000000-0000-4000-8000-0000000000c1';
  select count(*) into v_c_p from public.h2h_pairings(v_l);
  select count(*) into v_c_r from public.h2h_results(v_l);
  select count(*) into v_c_s from public.h2h_standings(v_l);
  select count(*) into v_c_d from public.h2h_match_detail(v_l, v_r, 0::smallint);
  reset role;
  insert into test_results(test, expected, actual, passed) values
    ('ST12 turno concluso: D batte E (3 a 0 in classifica)', 'concluso/30/3/0', v_st2 || '/' || v_fina2 || '/' || v_pa2 || '/' || v_pb2, v_st2 = 'concluso' and v_fina2 = 30 and v_pa2 = 3 and v_pb2 = 0),
    ('ST12 riposo: 0 punti scontri e riga di riposo segnalata', 'true/0/concluso', v_rest_is::text || '/' || v_rest_pts || '/' || v_rest_state, v_rest_is and v_rest_pts = 0 and v_rest_state = 'concluso'),
    ('ST12 classifica D: 3 pt scontri, 1 giocato/1 vinto, 30 pt totali, 10 esatti, primo', '3/1/1/30/10/1/false', v_d.pt_scontri || '/' || v_d.giocati || '/' || v_d.vinti || '/' || v_d.pt_totali || '/' || v_d.esatti || '/' || v_d.rank || '/' || v_d.tied,
       v_d.pt_scontri = 3 and v_d.giocati = 1 and v_d.vinti = 1 and v_d.pt_totali = 30 and v_d.esatti = 10 and v_d.rank = 1 and not v_d.tied),
    ('ST12 classifica E: 0 pt scontri, 1 giocato/1 perso, 0 pt totali', '0/1/1/0', v_e.pt_scontri || '/' || v_e.giocati || '/' || v_e.persi || '/' || v_e.pt_totali, v_e.pt_scontri = 0 and v_e.giocati = 1 and v_e.persi = 1 and v_e.pt_totali = 0),
    ('ST12 classifica A1 (riposo): 0 giocati, 1 riposo, 0 punti', '0/1/0', v_a.giocati || '/' || v_a.riposi || '/' || v_a.pt_scontri, v_a.giocati = 0 and v_a.riposi = 1 and v_a.pt_scontri = 0),
    ('ST12 classifica: E e A1 pari su tutti i criteri -> stesso rank e tied', '2/2/true/true', v_e.rank || '/' || v_a.rank || '/' || v_e.tied || '/' || v_a.tied, v_e.rank = 2 and v_a.rank = 2 and v_e.tied and v_a.tied),
    ('ST12 classifica: non definitiva (pronostici stagionali assenti)', 'false', v_final::text, not v_final),
    ('ST12 elenco scontri: il mio per primo (riposo di A1)', 'true/true', v_mine::text || '/' || v_first_rest::text, v_mine and v_first_rest),
    ('ST12 non membro C: 0 righe da elenco, risultati, classifica e dettaglio', '0/0/0/0', v_c_p || '/' || v_c_r || '/' || v_c_s || '/' || v_c_d, v_c_p = 0 and v_c_r = 0 and v_c_s = 0 and v_c_d = 0);

  -- anon rifiutato sulle letture
  begin set local role anon; perform * from public.h2h_results(v_l); reset role; exception when insufficient_privilege then reset role; v_rej1 := true; end;
  begin set local role anon; perform * from public.h2h_standings(v_l); reset role; exception when insufficient_privilege then reset role; v_rej2 := true; end;
  begin set local role anon; perform * from public.h2h_pairings(v_l); reset role; exception when insufficient_privilege then reset role; v_rej3 := true; end;
  begin set local role anon; perform * from public.h2h_match_detail(v_l, v_r, 0::smallint); reset role; exception when insufficient_privilege then reset role; v_rej4 := true; end;
  insert into test_results(test, expected, actual, passed) values
    ('ST12 anon: h2h_results, standings, pairings, match_detail rifiutate', 'true/true/true/true', v_rej1::text || '/' || v_rej2::text || '/' || v_rej3::text || '/' || v_rej4::text, v_rej1 and v_rej2 and v_rej3 and v_rej4);
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


-- ========== Migrazione 01: stato delle partite, punti provvisori/definitivi, privilegi ==========
-- Nessun id o turno scritto a mano: la partita di prova e' la prima ancora 'non_iniziata'.

-- ST1: matrice dei privilegi su TUTTE le relazioni di public (tabelle, viste, viste materializzate,
-- partizionate, esterne), per authenticated e anon, MAINTAIN incluso. Per authenticated la lista dei
-- privilegi attesi e' esplicita per relazione; qualunque relazione non elencata (nuova) deve avere
-- ZERO privilegi, cosi' un privilegio o una relazione nuova non passano inosservati. anon: sempre nessuno.
do $$
declare
  v_expected jsonb := '{
    "calendar": "SELECT",
    "general_leaderboard": "",
    "league_invites": "SELECT",
    "league_join_attempts": "",
    "league_members": "SELECT",
    "leagues": "SELECT",
    "matches": "SELECT",
    "prediction_scores": "SELECT",
    "predictions": "INSERT,SELECT,UPDATE",
    "profiles": "INSERT,SELECT,UPDATE",
    "rounds": "SELECT",
    "league_h2h_schedule": "SELECT",
    "league_h2h_pairings": "SELECT"
  }';
  r record;
  v_auth text; v_anon text; v_exp text;
  v_bad text := '';
  v_n int := 0;
begin
  for r in
    select c.oid, c.relname from pg_class c join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relkind in ('r', 'v', 'm', 'p', 'f') order by c.relname
  loop
    v_n := v_n + 1;
    select coalesce(string_agg(p, ',' order by p), '') into v_auth
      from unnest(array['SELECT','INSERT','UPDATE','DELETE','TRUNCATE','REFERENCES','TRIGGER','MAINTAIN']) p
      where has_table_privilege('authenticated', r.oid, p);
    select coalesce(string_agg(p, ',' order by p), '') into v_anon
      from unnest(array['SELECT','INSERT','UPDATE','DELETE','TRUNCATE','REFERENCES','TRIGGER','MAINTAIN']) p
      where has_table_privilege('anon', r.oid, p);
    v_exp := coalesce(v_expected ->> r.relname, '');
    if v_auth <> v_exp then v_bad := v_bad || r.relname || ': authenticated ha [' || v_auth || '] atteso [' || v_exp || '] | '; end if;
    if v_anon <> '' then v_bad := v_bad || r.relname || ': anon ha [' || v_anon || '] atteso [] | '; end if;
  end loop;
  insert into test_results(test, expected, actual, passed)
    values ('ST1 matrice privilegi di tutte le relazioni di public (' || v_n || ' relazioni)', 'nessuno scostamento', coalesce(nullif(v_bad,''),'nessuno scostamento'), v_bad = '');
end $$;

-- ST2: invariante status/gol sui dati reali: nessuna partita con risultato e stato diverso da 'finita'
-- (o in corso), nessuna 'finita' senza risultato.
do $$
declare
  v_bad int;
begin
  select count(*) into v_bad from public.matches
  where (home_goals is not null and status = 'non_iniziata') or (home_goals is null and status <> 'non_iniziata');
  insert into test_results(test, expected, actual, passed)
    values ('ST2 matches: stato coerente con i gol', '0 incoerenti', v_bad::text, v_bad = 0);
end $$;

-- ST3: trigger e vincolo: gol inseriti a mano -> 'finita'; 'in_corso' con gol resta tale;
-- 'in_corso' senza gol e 'finita' senza gol rifiutati.
do $$
declare
  v_match text;
  v_s1 text; v_s2 text;
  v_rej1 boolean := false; v_rej2 boolean := false;
begin
  select id into v_match from public.matches where status = 'non_iniziata' order by kickoff, id limit 1;
  update public.matches set home_goals = 2, away_goals = 1 where id = v_match;
  select status into v_s1 from public.matches where id = v_match;
  update public.matches set status = 'in_corso', home_goals = 1, away_goals = 0 where id = v_match;
  select status into v_s2 from public.matches where id = v_match;
  begin
    update public.matches set home_goals = null, away_goals = null where id = v_match;
  exception when check_violation then v_rej1 := true;
  end;
  begin
    update public.matches set status = 'finita', home_goals = null, away_goals = null where id = v_match;
  exception when check_violation then v_rej2 := true;
  end;
  update public.matches set status = 'non_iniziata', home_goals = null, away_goals = null where id = v_match;
  insert into test_results(test, expected, actual, passed) values
    ('ST3 gol inseriti a mano -> finita', 'finita', v_s1, v_s1 = 'finita'),
    ('ST3 in_corso con gol resta in_corso', 'in_corso', v_s2, v_s2 = 'in_corso'),
    ('ST3 in_corso senza gol rifiutato', 'check_violation', v_rej1::text, v_rej1),
    ('ST3 finita senza gol rifiutata', 'check_violation', v_rej2::text, v_rej2);
end $$;

-- ST4: punti provvisori vs definitivi con utente sintetico D e una partita 'in corso' 1-0:
-- prediction_scores.points = 3, points_final NULL; league_leaderboard e general_leaderboard
-- (letta da amministratore: authenticated non vi ha accesso) contano solo le finite.
do $$
declare
  v_match text;
  v_round int;
  v_league uuid;
  v_pts_live int; v_fin_live int; v_lb_live int; v_gen_live int;
  v_fin_done int; v_lb_done int; v_gen_done int;
  v_lb_base int; v_gen_base int;
begin
  select id, round_number into v_match, v_round from public.matches where status = 'non_iniziata' order by kickoff, id limit 1;
  insert into public.predictions (user_id, match_id, home_goals, away_goals)
  values ('00000000-0000-4000-8000-0000000000d1', v_match, 1, 0);
  insert into public.leagues (name, visibility, start_round, created_by)
  values ('Test punti provvisori ST4', 'public', v_round, '00000000-0000-4000-8000-0000000000d1')
  returning id into v_league;
  insert into public.league_members (league_id, user_id, role) values (v_league, '00000000-0000-4000-8000-0000000000d1', 'owner');

  -- D ha gia' punti da P6f nella stessa transazione: si confronta con la base, non con 0
  select total_points into v_lb_base from public.league_leaderboard(v_league) where user_id = '00000000-0000-4000-8000-0000000000d1';
  select total_points into v_gen_base from public.general_leaderboard where user_id = '00000000-0000-4000-8000-0000000000d1';
  update public.matches set status = 'in_corso', home_goals = 1, away_goals = 0 where id = v_match;
  select points, points_final into v_pts_live, v_fin_live from public.prediction_scores
    where user_id = '00000000-0000-4000-8000-0000000000d1' and match_id = v_match;
  select total_points into v_lb_live from public.league_leaderboard(v_league) where user_id = '00000000-0000-4000-8000-0000000000d1';
  select total_points into v_gen_live from public.general_leaderboard where user_id = '00000000-0000-4000-8000-0000000000d1';

  update public.matches set status = 'finita' where id = v_match;
  select points_final into v_fin_done from public.prediction_scores
    where user_id = '00000000-0000-4000-8000-0000000000d1' and match_id = v_match;
  select total_points into v_lb_done from public.league_leaderboard(v_league) where user_id = '00000000-0000-4000-8000-0000000000d1';
  select total_points into v_gen_done from public.general_leaderboard where user_id = '00000000-0000-4000-8000-0000000000d1';

  insert into test_results(test, expected, actual, passed) values
    ('ST4 in corso: points provvisori = 3', '3', coalesce(v_pts_live::text,'NULL'), v_pts_live = 3),
    ('ST4 in corso: points_final NULL', 'NULL', coalesce(v_fin_live::text,'NULL'), v_fin_live is null),
    ('ST4 in corso: league_leaderboard non conta la partita', v_lb_base::text, coalesce(v_lb_live::text,'NULL'), v_lb_live = v_lb_base),
    ('ST4 in corso: general_leaderboard non conta la partita', v_gen_base::text, coalesce(v_gen_live::text,'NULL'), v_gen_live = v_gen_base),
    ('ST4 finita: points_final = 3', '3', coalesce(v_fin_done::text,'NULL'), v_fin_done = 3),
    ('ST4 finita: league_leaderboard conta +3', (v_lb_base + 3)::text, coalesce(v_lb_done::text,'NULL'), v_lb_done = v_lb_base + 3),
    ('ST4 finita: general_leaderboard conta +3', (v_gen_base + 3)::text, coalesce(v_gen_done::text,'NULL'), v_gen_done = v_gen_base + 3);
  update public.matches set status = 'non_iniziata', home_goals = null, away_goals = null where id = v_match;
end $$;

-- ST5: current_round_number() = primo turno con una partita non finita (basato sullo stato)
do $$
declare
  v_exp int;
  v_cur int := public.current_round_number();
begin
  select min(round_number) into v_exp from public.matches where status <> 'finita';
  insert into test_results(test, expected, actual, passed)
    values ('ST5 current_round_number() = primo turno con partite non finite', coalesce(v_exp::text,'ultimo turno'), v_cur::text, v_exp is null or v_cur = v_exp);
end $$;

-- ST6: viste con security_invoker e senza accesso ad anon/public
do $$
declare
  v text;
  v_inv boolean;
  v_bad boolean;
begin
  foreach v in array array['calendar','prediction_scores','general_leaderboard'] loop
    select coalesce(c.reloptions @> array['security_invoker=true'], false) into v_inv
    from pg_class c join pg_namespace n on n.oid = c.relnamespace where n.nspname = 'public' and c.relname = v;
    v_bad := has_table_privilege('anon', 'public.' || v, 'SELECT') or has_table_privilege('public', 'public.' || v, 'SELECT');
    insert into test_results(test, expected, actual, passed) values
      ('ST6 ' || v || ' security_invoker', 'true', v_inv::text, v_inv),
      ('ST6 ' || v || ' non leggibile da anon/public', 'false', v_bad::text, not v_bad);
  end loop;
end $$;


-- ST7 (migrazione 01b): sulle viste authenticated puo' solo leggere (e general_leaderboard
-- resta senza SELECT, sospesa fino a gennaio); nessuna scrittura per nessuno.
do $$
declare v text; p text; v_bad text := '';
begin
  foreach v in array array['calendar','prediction_scores','general_leaderboard'] loop
    foreach p in array array['INSERT','UPDATE','DELETE','TRUNCATE','REFERENCES','TRIGGER','MAINTAIN'] loop
      if has_table_privilege('authenticated', 'public.' || v, p) then v_bad := v_bad || v || ':' || p || ' '; end if;
    end loop;
  end loop;
  insert into test_results(test, expected, actual, passed) values
    ('ST7 viste: authenticated senza privilegi di scrittura', 'nessuno', coalesce(nullif(v_bad,''),'nessuno'), v_bad = ''),
    ('ST7 calendar: authenticated SELECT si', 'true', has_table_privilege('authenticated','public.calendar','SELECT')::text, has_table_privilege('authenticated','public.calendar','SELECT')),
    ('ST7 prediction_scores: authenticated SELECT si', 'true', has_table_privilege('authenticated','public.prediction_scores','SELECT')::text, has_table_privilege('authenticated','public.prediction_scores','SELECT')),
    ('ST7 general_leaderboard: authenticated SELECT no', 'false', has_table_privilege('authenticated','public.general_leaderboard','SELECT')::text, not has_table_privilege('authenticated','public.general_leaderboard','SELECT'));
end $$;


-- ========== Migrazione 02: schema leghe a scontri diretti ==========
-- Utenti sintetici D, E (membri) e C (estraneo), gia' creati in cima; lega e abbinamenti scritti
-- da amministratore dentro la transazione (annullata dal rollback finale).

-- ST8a: tipo di lega (default, immutabilita', solo privata)
do $$
declare
  v_league uuid;
  v_default text;
  v_rej_change boolean := false; v_rej_public boolean := false;
  v_old_default int;
begin
  select count(*) into v_old_default from public.leagues where mode <> 'classifica' and created_at < now() - interval '1 minute';
  insert into public.leagues (name, visibility, start_round, created_by)
  values ('Test default mode ST8', 'public', coalesce(public.open_round_number(), (select max(round_number) from public.rounds)), '00000000-0000-4000-8000-0000000000d1')
  returning id, mode into v_league, v_default;
  insert into public.leagues (name, visibility, mode, start_round, created_by)
  values ('Test scontri privata ST8', 'private', 'scontri', coalesce(public.open_round_number(), (select max(round_number) from public.rounds)), '00000000-0000-4000-8000-0000000000d1')
  returning id into v_league;
  begin
    update public.leagues set mode = 'classifica' where id = v_league;
  exception when raise_exception then v_rej_change := true;
  end;
  begin
    insert into public.leagues (name, visibility, mode, start_round, created_by)
    values ('Test scontri pubblica ST8', 'public', 'scontri', coalesce(public.open_round_number(), (select max(round_number) from public.rounds)), '00000000-0000-4000-8000-0000000000d1');
  exception when check_violation then v_rej_public := true;
  end;
  insert into test_results(test, expected, actual, passed) values
    ('ST8a lega creata senza mode: default classifica', 'classifica', v_default, v_default = 'classifica'),
    ('ST8a il tipo di lega non si cambia', 'rifiutato', v_rej_change::text, v_rej_change),
    ('ST8a scontri solo in leghe private', 'rifiutato', v_rej_public::text, v_rej_public);
end $$;

-- ST8b: RLS attiva e policy solo SELECT TO authenticated sulle due tabelle nuove
do $$
declare v_rls int; v_pol int; v_bad int;
begin
  select count(*) into v_rls from pg_class c join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relname in ('league_h2h_schedule','league_h2h_pairings') and c.relrowsecurity;
  select count(*) into v_pol from pg_policies where schemaname = 'public' and tablename in ('league_h2h_schedule','league_h2h_pairings');
  select count(*) into v_bad from pg_policies where schemaname = 'public' and tablename in ('league_h2h_schedule','league_h2h_pairings')
    and (cmd <> 'SELECT' or roles::text <> '{authenticated}');
  insert into test_results(test, expected, actual, passed) values
    ('ST8b RLS attiva su schedule e pairings', '2', v_rls::text, v_rls = 2),
    ('ST8b una policy SELECT per tabella', '2', v_pol::text, v_pol = 2),
    ('ST8b nessuna policy diversa da SELECT TO authenticated', '0', v_bad::text, v_bad = 0);
end $$;

-- ST8c/d/e: accesso, visibilita' e vincoli con lega sintetica (D vs E, C estraneo)
do $$
declare
  v_league uuid;
  v_d int; v_e int; v_c int; v_sd int; v_sc int;
  v_rej_ins boolean := false; v_rej_upd boolean := false; v_rej_sch boolean := false; v_rej_anon boolean := false;
  v_self boolean := false; v_twice boolean := false; v_rest2 boolean := false; v_round int := 1;
begin
  select id into v_league from public.leagues where name = 'Test scontri privata ST8';
  insert into public.league_members (league_id, user_id, role) values
    (v_league, '00000000-0000-4000-8000-0000000000d1', 'owner'),
    (v_league, '00000000-0000-4000-8000-0000000000e1', 'member');
  insert into public.league_h2h_schedule (league_id, status, start_round, member_count, cycle_length)
  values (v_league, 'avviata', 8, 2, 1);
  insert into public.league_h2h_pairings (league_id, round_number, slot, user_a, user_b)
  values (v_league, 8, 0, '00000000-0000-4000-8000-0000000000d1', '00000000-0000-4000-8000-0000000000e1');

  -- visibilita' per ruolo
  set local role authenticated;
  set local request.jwt.claim.sub = '00000000-0000-4000-8000-0000000000d1';
  select count(*) into v_d from public.league_h2h_pairings where league_id = v_league;
  select count(*) into v_sd from public.league_h2h_schedule where league_id = v_league;
  set local request.jwt.claim.sub = '00000000-0000-4000-8000-0000000000e1';
  select count(*) into v_e from public.league_h2h_pairings where league_id = v_league;
  set local request.jwt.claim.sub = '00000000-0000-4000-8000-0000000000c1';
  select count(*) into v_c from public.league_h2h_pairings where league_id = v_league;
  select count(*) into v_sc from public.league_h2h_schedule where league_id = v_league;
  reset role;
  insert into test_results(test, expected, actual, passed) values
    ('ST8c membro D vede l''abbinamento', '1', v_d::text, v_d = 1),
    ('ST8c membro E vede l''abbinamento', '1', v_e::text, v_e = 1),
    ('ST8c membro D vede il calendario', '1', v_sd::text, v_sd = 1),
    ('ST8c non membro C: 0 abbinamenti', '0', v_c::text, v_c = 0),
    ('ST8c non membro C: 0 righe di calendario', '0', v_sc::text, v_sc = 0);

  -- scritture dirette da authenticated: rifiutate
  begin
    set local role authenticated;
    set local request.jwt.claim.sub = '00000000-0000-4000-8000-0000000000d1';
    insert into public.league_h2h_pairings (league_id, round_number, slot, user_a, user_b) values (v_league, 9, 0, '00000000-0000-4000-8000-0000000000d1', '00000000-0000-4000-8000-0000000000e1');
    reset role;
  exception when insufficient_privilege then reset role; v_rej_ins := true;
  end;
  begin
    set local role authenticated;
    set local request.jwt.claim.sub = '00000000-0000-4000-8000-0000000000d1';
    update public.league_h2h_pairings set user_b = '00000000-0000-4000-8000-0000000000c1' where league_id = v_league;
    reset role;
  exception when insufficient_privilege then reset role; v_rej_upd := true;
  end;
  begin
    set local role authenticated;
    set local request.jwt.claim.sub = '00000000-0000-4000-8000-0000000000d1';
    insert into public.league_h2h_schedule (league_id, status, start_round, member_count, cycle_length) values (v_league, 'avviata', 8, 2, 1);
    reset role;
  exception when insufficient_privilege then reset role; v_rej_sch := true;
  end;
  begin
    set local role anon;
    perform count(*) from public.league_h2h_pairings;
    reset role;
  exception when insufficient_privilege then reset role; v_rej_anon := true;
  end;
  insert into test_results(test, expected, actual, passed) values
    ('ST8c authenticated: insert diretto su pairings rifiutato', 'rifiutato', v_rej_ins::text, v_rej_ins),
    ('ST8c authenticated: update diretto su pairings rifiutato', 'rifiutato', v_rej_upd::text, v_rej_upd),
    ('ST8c authenticated: insert diretto su schedule rifiutato', 'rifiutato', v_rej_sch::text, v_rej_sch),
    ('ST8c anon: select su pairings rifiutato', 'rifiutato', v_rej_anon::text, v_rej_anon);

  -- vincoli sui dati (scritture da amministratore)
  begin
    insert into public.league_h2h_pairings (league_id, round_number, slot, user_a, user_b) values (v_league, 9, 0, '00000000-0000-4000-8000-0000000000d1', '00000000-0000-4000-8000-0000000000d1');
  exception when check_violation then v_self := true;
  end;
  begin
    insert into public.league_h2h_pairings (league_id, round_number, slot, user_a, user_b) values (v_league, 8, 1, '00000000-0000-4000-8000-0000000000e1', '00000000-0000-4000-8000-0000000000c1');
  exception when others then v_twice := true;
  end;
  insert into public.league_h2h_pairings (league_id, round_number, slot, user_a, user_b) values (v_league, 10, 0, '00000000-0000-4000-8000-0000000000d1', null);
  begin
    insert into public.league_h2h_pairings (league_id, round_number, slot, user_a, user_b) values (v_league, 10, 1, '00000000-0000-4000-8000-0000000000e1', null);
  exception when unique_violation then v_rest2 := true;
  end;
  insert into test_results(test, expected, actual, passed) values
    ('ST8e un membro non gioca contro se stesso', 'rifiutato', v_self::text, v_self),
    ('ST8e un membro non compare due volte nello stesso turno', 'rifiutato', v_twice::text, v_twice),
    ('ST8e al massimo un riposo per turno', 'rifiutato', v_rest2::text, v_rest2);
end $$;

-- ST9: matrice EXECUTE su TUTTE le funzioni di public (come ST1 per le tabelle). Per ogni funzione la
-- lista esplicita di chi puo' eseguirla fra anon, authenticated e PUBLIC (che rende eseguibile a tutti).
-- Una funzione non elencata deve risultare eseguibile da NESSUNO; una funzione con piu' permessi di
-- quelli attesi fa fallire il test. Le funzioni delle migrazioni 03a/04 sono gia' elencate (ancora assenti).
do $$
declare
  v_expected jsonb := '{
    "create_league": "authenticated",
    "current_round_number": "authenticated",
    "delete_league": "authenticated",
    "generate_invite_code": "",
    "is_league_member": "authenticated",
    "is_league_owner": "authenticated",
    "join_private_league": "authenticated",
    "join_public_league": "authenticated",
    "league_leaderboard": "authenticated",
    "leave_league": "authenticated",
    "list_public_leagues": "authenticated",
    "matches_default_status": "",
    "open_round_number": "authenticated",
    "prediction_points": "authenticated",
    "predictions_prevent_identity_change": "",
    "recompute_round_locks_at": "",
    "regenerate_invite_code": "authenticated",
    "remove_league_member": "authenticated",
    "round_is_open": "authenticated",
    "shares_league_with": "authenticated",
    "leagues_mode_immutable": "",
    "league_h2h_pairings_check": "",
    "round_play_state": "authenticated",
    "round_live_number": "",
    "h2h_is_locked": "",
    "create_h2h_league": "authenticated",
    "h2h_generate_schedule": "",
    "h2h_league_state": "authenticated",
    "h2h_pairings": "authenticated",
    "h2h_results": "authenticated",
    "h2h_standings": "authenticated",
    "h2h_match_detail": "authenticated",
    "h2h_season_winner_ok": "authenticated",
    "h2h_season_scorer_ok": "authenticated",
    "h2h_season_ready": "authenticated"
  }';
  r record;
  v_act text; v_exp text; v_bad text := ''; v_n int := 0;
begin
  for r in
    select p.oid, p.proname || '(' || pg_get_function_identity_arguments(p.oid) || ')' as sig, p.proname
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.prokind in ('f', 'p') order by p.proname, 2
  loop
    v_n := v_n + 1;
    v_act := concat_ws(',',
      case when has_function_privilege('anon', r.oid, 'EXECUTE') then 'anon' end,
      case when has_function_privilege('authenticated', r.oid, 'EXECUTE') then 'authenticated' end,
      case when has_function_privilege('public', r.oid, 'EXECUTE') then 'PUBLIC' end);
    v_exp := coalesce(v_expected ->> r.proname, '');
    if v_act <> v_exp then v_bad := v_bad || r.sig || ': eseguibile da [' || v_act || '] atteso [' || v_exp || '] | '; end if;
  end loop;
  insert into test_results(test, expected, actual, passed)
    values ('ST9 matrice EXECUTE di tutte le funzioni di public (' || v_n || ' funzioni)', 'nessuno scostamento', coalesce(nullif(v_bad,''),'nessuno scostamento'), v_bad = '');
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
