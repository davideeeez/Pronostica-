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
- La regola delle "due fonti con URL" vale solo per dati trovati
  autonomamente sul web. Se Davide fornisce uno screenshot o una tabella,
  quella è la fonte e basta, nessuna fonte aggiuntiva da cercare o citare.
  Resta comunque obbligatorio mostrargli la tabella (giornata, partita,
  orario/risultato) prima di qualunque insert/update e aspettare la sua
  conferma esplicita.

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
- I test non si appoggiano ai dati reali, che cambiano (utenti, leghe,
  pronostici, risultati, turni): niente turni scritti a mano (`r6-…`, "turno
  5") né utenti reali dove il test deve controllare cosa vede o ottiene un
  utente. Un turno aperto o precedente si ricava dal DB nel test stesso; utenti
  e dati servono sintetici, creati dentro la transazione annullata
  (`auth.users` + `profiles` con id fissi `00000000-0000-4000-8000-0000000000XX`,
  risultati finti sulle partite, kickoff anticipati per simulare il blocco) e
  spariscono col `rollback` finale. Gli utenti reali A e B restano solo dove
  serve verificare l'accesso con identità note (policy, funzioni, privilegi).
  Dopo ogni lancio verificare che il DB reale sia rimasto invariato.
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
  un pronostico di partita "per lega". (I pronostici stagionali, invece, sono
  per lega: vedi la sezione dedicata.)
- `matches`/`rounds` sono scrivibili solo da SQL diretto (nessuna policy di
  insert/update/delete per `authenticated`/`anon`): i risultati e gli orari
  ufficiali li inserisce chi lavora al progetto, mai l'app.
- **Il calendario (squadre, orari, risultati, stato dei turni) vive solo in
  `matches`/`rounds`, mai ricopiato nel codice** (niente dati di calendario
  in `mock.ts` o altrove nel frontend). Il frontend legge dalla vista
  `calendar` (`src/lib/calendar.ts` + `src/hooks/useCalendar.ts`), una sola
  query per tutte le giornate, non una per partita.
- "Turno corrente" ha due definizioni, ciascuna in una sola funzione. Riusarle
  sempre (vista `calendar`, frontend, leghe, SQL) — **mai ridefinire la logica
  altrove**, nemmeno in una nuova query o vista:
  - `current_round_number()` = primo turno non completato: il più basso con
    almeno una partita non `finita` (stato in `matches.status`), altrimenti
    l'ultimo. Può essere già chiuso ai pronostici (partite in corso, recuperi).
  - `open_round_number()` = turno aperto ai pronostici: il più basso con
    `locks_at` nel futuro, `NULL` se non ce n'è nessuno. È il turno su cui si
    pronostica: Home, Pronostici, `create_league` (turno di partenza ≥ turno
    aperto) e stato `corrente` della vista `calendar`.
  - Stati della vista `calendar`: `giocato` (tutte le partite `finita`), `corrente` (= `open_round_number()`, uno solo, può non
    esserci), `in_corso` (chiuso ma con partite non `finita`), `futuro`.
    Il frontend gestisce l'assenza del turno corrente con uno stato "in attesa
    del prossimo turno", non con un errore.
- La lega selezionata (e l'elenco delle mie leghe) ha un'unica fonte nel
  frontend: `MyLeaguesProvider` (`src/contexts/`), sopra le rotte, letto con
  `useMyLeagues()`. Salva la scelta sul dispositivo a ogni cambio, la legge
  all'avvio e non scrive nulla finché l'elenco non è caricato. Pagine e
  componenti non tengono una copia propria né leggono `localStorage`.
  Aprire il dettaglio di una lega non cambia la selezione: la cambia solo il
  selettore dell'header.
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
- `league_h2h_pairings.user_a/user_b` → `profiles` senza `ON DELETE CASCADE`:
  una lega a scontri avviata blocca la cancellazione del profilo dei suoi
  membri. Da decidere prima dell'apertura pubblica e degli store (cancellazione
  account obbligatoria).
- **Rollback di 02/04 (`rollback/02_04_rollback.sql`)**: cancella le tabelle degli
  scontri e quindi i calendari delle leghe a scontri avviate. Dalla prima lega
  reale a scontri non si torna indietro: si corregge solo in avanti, con nuove
  migrazioni.
- Funzioni: il test ST9 di `security.sql` è una matrice con la lista esplicita di
  chi può eseguire ciascuna funzione di `public` (anon, authenticated, PUBLIC).
  Ogni funzione nuova va aggiunta alla lista e, per default Supabase, nasce
  eseguibile da PUBLIC/anon: serve un `revoke execute ... from public, anon`
  esplicito (il revoke globale dei default per le funzioni NON è applicato).
- Privilegi di default (ruolo `postgres`, schema `public`): dalla migrazione
  `default_privilegi_tabelle_sequenze` (2026-10-25) tabelle, viste e sequenze
  NUOVE nascono SENZA privilegi per `anon` e `authenticated` (restano
  `postgres` e `service_role`): ogni migrazione deve concedere esplicitamente
  ad `authenticated` solo ciò che serve (`grant select ... to authenticated`).
  Il test ST13 di `security.sql` lo verifica; ST1 resta la rete di sicurezza
  sulle relazioni esistenti. Rollback in
  `supabase/proposte/scontri/rollback/defaults_tabelle_sequenze_rollback.sql`.
  NON coperto: le funzioni nuove nascono ancora eseguibili da PUBLIC/anon (il
  revoke globale `from public` non è applicato, scelta del 2026-10-21) e le
  tabelle create dal ruolo `supabase_admin` (non usato dalle migrazioni).
- `supabase/tests/security.sql`, test P2d: dipende dal pronostico reale
  dell'utente B sul turno aperto (oggi aggira il conflitto con `on conflict do
  nothing`). Da riscrivere con utenti sintetici, come richiede la regola sui
  test.
- Nessun limite di leghe per utente né di membri per lega (scelta di
  prodotto); nessuna moderazione dei nomi delle leghe, nessuna segnalazione o
  nascondimento — da chiudere prima di apertura pubblica.

## Leghe a scontri diretti — IN COSTRUZIONE

Stato delle migrazioni (proposte in `supabase/proposte/scontri/`): **tutte
applicate** — 01 (stato partite), 01b, 01c, 01d (privilegi), 02 (schema), 03a
(generazione e blocco ingressi), 03b (uscite/rimozioni, applicata a mano dal SQL
editor perché contiene DELETE e `apply_migration` va in timeout), 04 (risultati,
classifica, dettaglio) e i privilegi di default di tabelle/sequenze. Database
delle leghe a scontri completo; mancano i pronostici stagionali (criteri 3 e 4)
e il frontend. Una migrazione con `DELETE` nel testo si applica a mano, non via
`apply_migration`.

MODALITÀ E CREAZIONE
- Il creatore sceglie "classifica" o "scontri diretti" alla creazione; la scelta
  non si cambia più (trigger sul database).
- Primo rilascio: scontri diretti solo in leghe PRIVATE.
- La lega ha un turno di partenza, come oggi. Creazione con `create_h2h_league`
  (nessun overload di `create_league`).

ISCRIZIONI E USCITE (solo leghe a scontri; le leghe a classifica restano libere)
- Si entra fino a `locks_at` del turno di partenza; dopo, nessun ingresso, uscita
  o rimozione. Il creatore può solo eliminare la lega.
- Prima del blocco, uscita e rimozione funzionano come oggi.
- **Nessuna conversione in classifica**: la lega a scontri resta sempre a scontri,
  anche con membri dispari.
- Con 1 solo membro al blocco la lega è "non avviata": nessun abbinamento, solo
  eliminazione; avviso al creatore prima del blocco.

CALENDARIO
- All'italiana (metodo del cerchio), dal turno di partenza al turno 38. Membri
  ordinati per (joined_at, user_id).
- Con N dispari si aggiunge un membro fantasma: chi lo incontra **riposa** in quel
  turno; il ciclo dura N turni (N-1 se N pari). Abbinamenti con `user_b` nullo =
  riposo; non esiste FK sul turno (i turni 10–38 non esistono ancora in `rounds`).
- Il calendario è creato dal database alla prima lettura dopo il blocco
  (`h2h_league_state`, idempotente, con lock di riga), non dal frontend e non
  cambia più. Dopo l'ultimo ciclo completo riparte dal primo abbinamento.

ESITO DELLO SCONTRO
- Si confrontano i punti di turno (3 esatto, 1 esito, 0 sbagliato).
- Più punti: 3 in classifica; stessi punti: 1 a testa; meno punti: 0.
- Chi non pronostica ha 0 punti di turno. L'avversario vince solo se fa almeno 1
  punto; se fa 0 è pareggio (1 a testa).
- **Riposo: 0 punti scontri e il turno non conta come giocato.**
- Punti **provvisori** (partite `in_corso` e `finita`) e **definitivi** (solo
  `finita`): il dettaglio dello scontro mostra i provvisori man mano; la classifica
  scontri si aggiorna SOLO a turno concluso.
- `general_leaderboard` e `league_leaderboard` contano solo `points_final`.
- `matches.status` (`non_iniziata`/`in_corso`/`finita`): un risultato non nullo
  NON basta più a dire "finale". I risultati si inseriscono ancora a mano; un
  trigger porta a `finita` una partita con gol inseriti e stato di default.
  `current_round_number()` e la vista `calendar` si basano sullo stato.
- Un turno è "concluso" (`round_play_state`) solo con 10 partite presenti e tutte
  `finita`; un recupero rinviato lo tiene "in corso" per le classifiche.

HOME (solo leghe a scontri)
- Prima del blocco del turno aperto: "Pronostica". Dal blocco fino a quando non
  resta nessuna partita attiva nella finestra normale: "Segui lo scontro". Chi
  riposa: "Turno di riposo". Finito il turno: "Pronostica" sul turno successivo.
- Finestra normale = da `locks_at` a +96 ore; una partita è attiva se non è
  `finita` e il suo calcio d'inizio cade nella finestra (`round_live_number()`).
  Nessuna soglia oraria dal calcio d'inizio: finché il risultato non è inserito
  (e i punti assegnati) la Home resta su "Segui lo scontro". Una partita rinviata
  oltre la finestra NON tiene la Home in questo stato (diversamente dalle
  classifiche).
- La scheda Pronostici resta sempre sul prossimo turno aperto.
- Il dettaglio dello scontro (pronostici e punti di turno, per partita) si apre
  dal proprio scontro nella scheda Calendario e dalla Home.

CLASSIFICA FINALE (ordine dei criteri)
1. Punti scontri diretti
2. Punti totali dei pronostici (solo turni dalla partenza e solo turni conclusi)
3. Pronostico vincitrice corretto
4. Pronostico capocannoniere corretto
5. Più risultati esatti (solo turni conclusi)
6. Più esiti corretti (solo turni conclusi)
7. Se persiste, premio diviso equamente
- Nella lega a scontri diretti la tabella mostra come colonne principali
  "Pt scontri" e "Pt totali".

DIPENDENZE E ORDINE DI LAVORO
- I criteri 3 e 4 richiedono i pronostici stagionali (non ancora esistenti; oggi
  segnaposto che restituiscono `false`): gli scontri non si chiudono
  correttamente prima.
- Calcolo di scontri e classifica solo nel database. Niente integrazione con API
  di dati live in questa fase.
- Ordine: (1) test lega base con due account, (2) pronostici stagionali,
  (3) schema e funzioni scontri diretti con test di sicurezza prima del
  frontend, (4) frontend.

## Pronostici stagionali — DA COSTRUIRE (non implementare ora)

COSA SI PRONOSTICA
- Due pronostici per lega: squadra vincitrice della Serie A e capocannoniere
  della Serie A.

PUNTI E QUOTE
- I punti vengono da una tabella quote: vincitrice 15-100, capocannoniere
  20-100 (formula logaritmica, arrotondata al multiplo di 5). Il capocannoniere
  ha anche l'opzione "Altro" = 100 punti.
- La tabella quote è versionata: ogni aggiornamento è una nuova versione con
  un turno di validità; le versioni vecchie non si modificano mai. Davide manda
  le quote aggiornate a mano (con data e fonte): mai cercate sul web.

PER PARTITA E STAGIONALI
- I pronostici delle partite restano unici per utente e validi in tutte le
  leghe. I pronostici stagionali sono per lega: lo stesso utente può avere
  scelte diverse in leghe diverse.

BLOCCO E MODIFICHE
- Il pronostico stagionale si blocca al blocco della lega.
- Ogni pronostico stagionale salva i punti della versione quote valida quando
  è stato fatto o cambiato (punti congelati nel pronostico, non ricalcolati
  dalle versioni successive).
- Dopo la giornata 19 si può cambiare il pronostico; il cambio salva i punti
  della versione quote valida in quel momento.

ESITO
- Capocannoniere a pari gol: il pronostico vale per tutti i giocatori in testa
  secondo il marcatore ufficiale della Lega. Ogni utente con un pronostico tra
  i giocatori in testa prende i punti interi, senza divisione. I risultati li
  inserisce Davide, mai cercati sul web.

SICUREZZA E CALCOLO
- Punti calcolati solo nel database. Stesse regole di sicurezza di
  `predictions`: RLS `TO authenticated`, lettura dei pronostici altrui solo
  dopo il blocco e solo tra membri della stessa lega. Test di sicurezza prima
  del frontend.

ORDINE DI LAVORO
- Dopo il test a due account della lega base.

## Prima di ogni modifica non banale

- Riepilogo del piano (tabelle, policy, file toccati) e attesa di conferma
  esplicita prima di scrivere codice o migrazioni, a meno che l'utente non
  abbia già approvato un piano dettagliato in precedenza nello stesso turno.
- Segnalare esplicitamente ogni buco di sicurezza o incoerenza trovata,
  anche se non richiesto — non aspettare che l'utente lo scopra.
