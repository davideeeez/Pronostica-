# Pronostica! — regole per ogni sessione

Web app di pronostici Serie A tra amici. Frontend React+Vite+TypeScript in
`pronostica-app/`, backend Supabase (Postgres + RLS + Auth Google-only).
Leghe private (con codice d'invito) e leghe pubbliche (senza codice).
**Classifica generale sospesa fino a gennaio** (si riattiva dopo la
giornata 19, conta dalle giornate successive — data esatta da confermare):
nel frattempo si gioca solo in leghe.

## Risultati reali — mai inventati

- Nessun risultato (punteggio di una partita) entra nel database senza
  **due fonti indipendenti**, con nomi e URL reali.
- Prima di qualunque insert di risultati: mostra la tabella completa
  (giornata, partita, risultato, fonte) e aspetta conferma esplicita.
- Se si trova una sola fonte per una partita: fermarsi e dirlo, non inserire
  e non inventare il dato mancante.

## Sicurezza database — checklist obbligatoria dopo ogni modifica allo schema

- Ogni policy RLS è scoperta `TO authenticated` (mai `PUBLIC`/`anon`), a meno
  che il dato non sia esplicitamente pensato per essere pubblico (es.
  calendario partite).
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

## Prima di ogni modifica non banale

- Riepilogo del piano (tabelle, policy, file toccati) e attesa di conferma
  esplicita prima di scrivere codice o migrazioni, a meno che l'utente non
  abbia già approvato un piano dettagliato in precedenza nello stesso turno.
- Segnalare esplicitamente ogni buco di sicurezza o incoerenza trovata,
  anche se non richiesto — non aspettare che l'utente lo scopra.
