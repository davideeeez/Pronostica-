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
begin
  insert into public.predictions (user_id, match_id, home_goals, away_goals) values
    ('31e2df43-b49a-4b56-af0a-78aff50a9dd6', 'r6-inter-parma', 1, 1),
    ('31e2df43-b49a-4b56-af0a-78aff50a9dd6', 'r1-udinese-como', 1, 1);

  set local role authenticated;
  set local request.jwt.claim.sub = '560f6bd4-6070-4f6a-a78e-676cb4b8c7c4';

  select exists(select 1 from public.predictions where user_id = '31e2df43-b49a-4b56-af0a-78aff50a9dd6' and match_id = 'r6-inter-parma') into v_open_visible;
  select exists(select 1 from public.predictions where user_id = '31e2df43-b49a-4b56-af0a-78aff50a9dd6' and match_id = 'r1-udinese-como') into v_closed_visible;
  reset role;

  insert into test_results(test, expected, actual, passed)
    values ('P2d B su turno aperto invisibile ad A', 'false', v_open_visible::text, v_open_visible = false);
  insert into test_results(test, expected, actual, passed)
    values ('P2d B su turno chiuso invisibile ad A (nessuna lega in comune)', 'false', v_closed_visible::text, v_closed_visible = false);
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
  v_league_id := public.create_league('Test lega condivisa P2d-bis', 'public', public.current_round_number());

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
begin
  set local role authenticated;
  set local request.jwt.claim.sub = '560f6bd4-6070-4f6a-a78e-676cb4b8c7c4';
  insert into public.predictions (user_id, match_id, home_goals, away_goals)
  values ('31e2df43-b49a-4b56-af0a-78aff50a9dd6', 'r6-inter-parma', 3, 0);
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

-- P4a: turno corrente coerente con current_round_number()
do $$
declare
  v_fn int := public.current_round_number();
  v_calendar int;
begin
  select round_number into v_calendar from public.calendar where round_status = 'corrente' limit 1;
  insert into test_results(test, expected, actual, passed)
    values ('P4a current_round_number coerente con calendar', v_fn::text, coalesce(v_calendar::text,'nessuno'), v_fn = v_calendar);
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

-- locks_at: modifica libera prima della chiusura (round 6)
do $$
declare
  v_before timestamptz;
  v_after timestamptz;
begin
  select locks_at into v_before from public.rounds where round_number = 6;
  update public.matches set kickoff = v_before - interval '1 hour' where id = 'r6-genoa-fiorentina';
  select locks_at into v_after from public.rounds where round_number = 6;
  update public.matches set kickoff = v_before where id = 'r6-genoa-fiorentina';
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
  v_league_id := public.create_league('Test lega rate limit', 'private', public.current_round_number());
  reset role;

  select code into v_code from public.league_invites where league_id = v_league_id;

  set local role authenticated;
  set local request.jwt.claim.sub = '31e2df43-b49a-4b56-af0a-78aff50a9dd6';
  for i in 1..10 loop
    v_result := public.join_private_league('XXXXXXX' || i::text);
    if v_result = 'invalid' then
      v_rejected_wrong := v_rejected_wrong + 1;
    end if;
  end loop;

  -- 11esimo tentativo, codice giusto ma ancora dentro la finestra
  v_result := public.join_private_league(v_code);
  reset role;

  insert into test_results(test, expected, actual, passed)
    values ('P5i 10 codici sbagliati rifiutati', '10', v_rejected_wrong::text, v_rejected_wrong = 10);
  insert into test_results(test, expected, actual, passed)
    values ('P5i codice giusto rifiutato dentro la finestra', 'invalid', v_result, v_result = 'invalid');

  update public.league_join_attempts set attempted_at = now() - interval '11 minutes'
  where user_id = '31e2df43-b49a-4b56-af0a-78aff50a9dd6';

  set local role authenticated;
  set local request.jwt.claim.sub = '31e2df43-b49a-4b56-af0a-78aff50a9dd6';
  v_result := public.join_private_league(v_code);
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
  v_private_id := public.create_league('Test privata per j', 'private', public.current_round_number());
  v_public_id := public.create_league('Test pubblica per j', 'public', public.current_round_number());

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
  v_pub_id := public.create_league('Test pubblica per k', 'public', public.current_round_number());
  v_priv_id := public.create_league('Test privata per k', 'private', public.current_round_number());
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
  v_result1 := public.join_private_league(v_code);
  v_result2 := public.join_private_league(v_code);
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
  v_league_id := public.create_league('Test lega minuscole', 'private', public.current_round_number());
  reset role;

  select code into v_code from public.league_invites where league_id = v_league_id;
  select count(*) into v_attempts_before from public.league_join_attempts where user_id = '31e2df43-b49a-4b56-af0a-78aff50a9dd6';

  set local role authenticated;
  set local request.jwt.claim.sub = '31e2df43-b49a-4b56-af0a-78aff50a9dd6';
  v_result := public.join_private_league('  ' || lower(v_code) || '  ');
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
  v_league_id := public.create_league('Test lega privata per p', 'private', public.current_round_number());
  set local request.jwt.claim.sub = '31e2df43-b49a-4b56-af0a-78aff50a9dd6';
  v_result := public.join_public_league(v_league_id);
  reset role;

  insert into test_results(test, expected, actual, passed)
    values ('P5p join_public_league su lega privata', 'not_found', v_result, v_result = 'not_found');
end $$;


-- ========== Riepilogo ==========

select seq, test, expected, actual, passed from test_results order by seq;
select count(*) filter (where not passed) as test_falliti, count(*) as test_totali from test_results;

rollback;
