# S1 reale — turno 11 (venerdì 6/11, ore 19:47 UTC = 20:47 italiane)

Calendario generato dal database alla prima lettura dopo il blocco (`h2h_league_state`, chiamato impersonando ogni
membro in una transazione committata). Blocco: `2026-11-06 19:45 UTC`. Nessun risultato del turno 11 inserito.

| Lega | Stato | Membri | Turno di partenza | Ciclo | Abbinamenti | Riposi |
|---|---|---|---|---|---|---|
| Scontri 3 membri (prova) | avviata | 3 | 11 | 3 | 56 (turni 11–38) | 28 |
| Scontri 4 membri (prova) | avviata | 4 | 11 | 3 | 56 (turni 11–38) | 0 |

Ordine di ingresso reale (UTC): lega 3 = Davide 14:31, Marco 17:13, BR1 17:42; lega 4 = Davide 14:31,
**accountprova 17:04**, Marco 17:26, BR1 17:41 (accountprova NON per ultima).
`accountprova` ha pronosticato tutte e 10 le partite del turno 11 (40 pronostici totali), contro l'accordo.

## Confronto col calendario atteso (calcolato prima del blocco, `calendario_atteso_concreto_*.csv`)
md5 di `turno,slot,user_a,user_b` ordinato — identico in entrambe le leghe, compresa l'orientazione:
- lega 3: file `ff061d1bbd208a8994ebce80589427db` = DB `ff061d1bbd208a8994ebce80589427db`
- lega 4: file `0dac56d165adfea72b6b947f7c9c76df` = DB `0dac56d165adfea72b6b947f7c9c76df`

Turno 11: lega 3 = Davide riposa, Marco–BR1; lega 4 = Davide–BR1, accountprova–Marco.

## Stato per membro (`h2h_league_state`)
Tutti: mode=scontri, start=11, locked=true, status=avviata, warn=false, live_round=11.
- lega 3: Davide home=riposo (slot 0), Marco e BR1 home=segui (slot 1).
- lega 4: Davide segui (slot 0), Marco segui (slot 1), BR1 segui (slot 0), accountprova segui (slot 1).

## Test negativi (transazione annullata)
- ingresso di accountprova (non membro) nella lega 3: `closed`; membri 3 -> 3
- Marco esce dalla lega 3: `locked`; Davide rimuove BR1 (lega 3): `locked`; Davide rimuove accountprova (lega 4): `locked`
- Davide (owner) esce dalla lega 3: `owner_cannot_leave`
- membri totali dopo i test: 7 (3 + 4), invariati.

Esito S1: coincide con l'atteso.
