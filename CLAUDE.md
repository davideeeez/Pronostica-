# Pronostica! — regole per ogni sessione

Web app di pronostici Serie A tra amici. Frontend React+Vite+TypeScript in
`pronostica-app/`, backend Supabase (Postgres + RLS + Auth Google-only).
Leghe private (con codice d'invito) e leghe pubbliche (senza codice).
**Classifica generale sospesa fino a gennaio** (si riattiva dopo la
giornata 19, conta dalle giornate successive — data esatta da confermare):
nel frattempo si gioca solo in leghe.

## Risultati reali — mai inventati

- **Non cercare dati di calendario/risultati sul web.** Orari, squadre e
  risultati si inseriscono solo da tabelle fornite direttamente dall'utente
  (lui è la fonte): mai da una ricerca web autonoma, nemmeno per "verificare"
  o completare un dato mancante.
- Prima di qualunque insert in `matches`/`rounds`: mostra un riepilogo
  completo (giornata, partita, orario/risultato) di cosa si sta per inserire.
- Se un dato manca o è ambiguo nella tabella fornita: fermarsi e dirlo,
  chiedere il dato corretto, non inventarlo e non colmare il buco con una
  ricerca web.

## Sicurezza database — checklist obbligatoria dopo ogni modifica allo schema

- Ogni policy RLS è scoperta `TO authenticated` (mai `PUBLIC`/`anon`) — anche
  dati apparentemente innocui come il calendario partite (`matches`/`rounds`)
  sono riservati agli utenti loggati, non pubblici.
- Nelle condizioni delle policy usare sempre `(select auth.uid())`, mai
  `auth.uid()` diretto: la forma diretta viene rivalutata riga per riga
  (avviso performance `auth_rls_initplan`), quella tra parentesi una sola
  volta per query.
- Dopo aver creato/modificato una policy: revocare anche i privilegi di
  tabella (`GRANT`) ad `anon` se non già assenti — altrimenti `anon` ottiene
  zero righe per via della RLS ma nessun errore di permesso netto
  (comportamento più debole, da evitare).
- Ogni vista che espone dati utente è creata con `security_invoker = true`
  (altrimenti gira con i permessi di chi l'ha creata, bypassando la RLS delle
  tabelle sottostanti).
- Dopo aver creato una vista: `revoke all ... from anon, public` esplicito,
  poi `grant select ... to authenticated` solo se la vista deve essere letta
  da app.
- Dopo ogni migrazione: lanciare gli advisor di sicurezza **e** performance di
  Supabase e mostrarne l'output per intero, non un riassunto.
- Testare sempre con ruolo `anon` (query diretta impersonando il ruolo, non
  solo "dovrebbe funzionare così") che le tabelle/viste con dati utente
  rifiutino l'accesso (errore di permesso o zero righe) — stessa cosa con
  ruolo `authenticated` per le operazioni che devono restare bloccate anche
  da loggati (es. scrivere risultati, modificare `matches`/`rounds`).
- Mostrare sempre l'output reale dei test (errori del database), non solo
  "funziona"/"ok".
- I test di sicurezza vivono in `supabase/tests/security.sql` (script SQL
  rilanciabile, transazioni annullate con `rollback`). Dopo ogni migrazione
  che tocca schema/policy: aggiornarlo se serve, rilanciarlo per intero e
  mostrare l'output — non riscrivere i test da zero a mano ogni volta.
- **Mai usare `DELETE` nello strumento MCP `execute_sql`** (nemmeno dentro
  una transazione poi annullata con `rollback`): il tool lo tratta come
  statement distruttivo e aspetta una conferma interattiva che in questa
  sessione non arriva mai, causando un timeout di 60s indistinguibile da un
  vero blocco. Stesso problema già noto per `DROP TRIGGER`/`DROP FUNCTION`.
  Per pulizia dati nei test: appoggiarsi solo al `rollback` finale, mai a un
  `DELETE` di mezzo.

## Regole di modello dati

- Il turno (`round_number`) di un pronostico si ricava **sempre** da
  `matches` via `match_id` — mai un valore scritto/passato dal client. Se
  serve il turno di una predizione, fare JOIN con `matches`, non aggiungere
  una colonna `round_number` a `predictions`.
- Il punteggio si calcola **solo** nel database (funzione/vista SQL), mai
  lato client/frontend.
- Un pronostico di una partita è unico per utente (`unique(user_id,
  match_id)`) e vale in tutte le leghe a cui l'utente partecipa — non esiste
  un pronostico "per lega".
- `matches`/`rounds` sono scrivibili solo da SQL diretto (nessuna policy di
  insert/update/delete per `authenticated`/`anon`): i risultati e gli orari
  ufficiali li inserisce chi lavora al progetto, mai l'app.
- **Il calendario (squadre, orari, risultati, stato dei turni) vive solo in
  `matches`/`rounds`, mai ricopiato nel codice** (niente dati di calendario
  in `mock.ts` o altrove nel frontend). Il frontend legge dalla vista
  `calendar` (`src/lib/calendar.ts` + `src/hooks/useCalendar.ts`), una sola
  query per tutte le giornate, non una per partita.
- "Turno corrente" ha un'unica definizione, in `current_round_number()`: il
  più basso con almeno una partita senza risultato, altrimenti l'ultimo.
  Riusarla sempre (vista `calendar`, frontend, future leghe, SQL) — **mai
  ridefinire la logica altrove**, nemmeno in una nuova query o vista.
- `rounds.locks_at` è calcolato in automatico da un trigger su `matches`
  (min(kickoff) del turno) — non va mai scritto a mano. Il trigger rifiuta di
  spostarlo più avanti una volta già passato (il turno non può "riaprire").

## Debito tecnico aperto (nessuna azione finché non richiesto)

- `is_league_member`/`is_league_owner` sono helper interni per le policy RLS
  (leghe), ma essendo `SECURITY DEFINER` con `EXECUTE` concesso ad
  `authenticated` risultano chiamabili direttamente via RPC — non è una falla
  (restituiscono solo un booleano sul proprio `auth.uid()`), ma vanno spostati
  in uno schema non esposto da PostgREST, lasciando le policy libere di
  richiamarli comunque.
- `leagues.created_by` e `leagues.start_round` non hanno un indice a supporto
  della foreign key — da aggiungere se la tabella cresce.
- Nessun limite di leghe per utente né di membri per lega (scelta di
  prodotto); nessuna moderazione dei nomi delle leghe, nessuna segnalazione o
  nascondimento — da chiudere prima di apertura pubblica.

## Prima di ogni modifica non banale

- Riepilogo del piano (tabelle, policy, file toccati) e attesa di conferma
  esplicita prima di scrivere codice o migrazioni, a meno che l'utente non
  abbia già approvato un piano dettagliato in precedenza nello stesso turno.
- Segnalare esplicitamente ogni buco di sicurezza o incoerenza trovata,
  anche se non richiesto — non aspettare che l'utente lo scopra.
