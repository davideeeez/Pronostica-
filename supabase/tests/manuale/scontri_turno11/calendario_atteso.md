# Test reale scontri diretti — turno 11: calendario atteso

Il test sul turno 10 è saltato (nessun socio è entrato nelle leghe, nessun calendario generato) e le leghe di
quel test sono state eliminate con `delete_league` il 2026-11-05. Si riparte dal turno 11.

Salvato nel repo il 2026-11-05, PRIMA della prova generale e prima che i soci entrino.

Blocco del turno 11: `rounds.locks_at = 2026-11-06 19:45:00+00` = venerdì 6/11 ore 20:45 italiane (CET, UTC+1).

Leghe create il 2026-11-05 (claim `davidezotti`, transazione committata, `create_h2h_league(nome, 11)`):

| Lega | Id |
|---|---|
| Scontri 3 membri (prova) | `68e277bf-9710-4936-9ee7-b913681e265b` |
| Scontri 4 membri (prova) | `64a403d3-be87-4ca9-aaaa-6da39c4c133c` |

I codici di invito NON sono nel repo.

## Ingresso previsto (cut-off ingressi: venerdì 6/11 ore 17:00 italiane)
Il calendario ordina i membri per `(joined_at, user_id)`. m1 è sempre `davidezotti` (owner, entrato alla creazione).

| Lega | m1 | m2 | m3 | m4 |
|---|---|---|---|---|
| 3 membri | davidezotti | Marco o BR1 (primo ad entrare) | l'altro | — |
| 4 membri | davidezotti | Marco o BR1 | l'altro | accountprova (ultimo) |

`accountprova` non pronostica il turno 11. L'ordine reale va letto dalle righe di `league_members` (tabella base)
alle 17:00 e il file concreto con gli id (`calendario_atteso_concreto_lega3.csv` / `_lega4.csv`, prodotto con
`calcolo_calendario.py --start 11`) va committato PRIMA di iniziare la prova generale.

## Abbinamenti attesi (turni 11, 12, 13; poi il ciclo si ripete fino al 38)

Lega a 3 (ciclo di 3 turni, un riposo a turno):

| Turno | Riposa | Scontro |
|---|---|---|
| 11 | m1 | m2 – m3 |
| 12 | m2 | m1 – m3 |
| 13 | m3 | m1 – m2 |
| 14 | = turno 11 | |

Lega a 4 (ciclo di 3 turni, nessun riposo):

| Turno | Scontri |
|---|---|
| 11 | m1 – m4, m2 – m3 |
| 12 | m1 – m3, m4 – m2 |
| 13 | m1 – m2, m3 – m4 |
| 14 | = turno 11 |

Conseguenze per il turno 11: Davide riposa nella lega a 3; nella lega a 4 affronta `accountprova`, che non pronostica
(Davide vince 3–0 solo se fa almeno 1 punto, altrimenti pareggio 1–1).

## Proprietà che devono valere (indipendenti dalla convenzione di rotazione)
- ogni membro compare esattamente una volta per turno; con N dispari un solo riposo a turno, N pari nessuno;
- nel primo ciclo ogni coppia si incontra esattamente una volta; con N dispari ognuno riposa esattamente una volta;
- il turno k + ciclo ripete il turno k; calendario dal turno 11 al 38;
- righe attese: lega a 3 = 28 turni x 2 abbinamenti = 56; lega a 4 = 28 turni x 2 = 56.

Limite dichiarato: *quale* coppia cade in *quale* turno segue la convenzione del codice SQL (primo membro fisso, altri
ruotati di una posizione a destra); questa parte non è una verifica indipendente.

## Calendario del test (orari italiani, venerdì 6/11)
1. giovedì 5/11: leghe create, tabella attesa salvata (questo file).
2. fino alle 17:00 di venerdì: i soci entrano con il codice (accountprova per ultimo nella lega a 4).
3. 17:00: riconteggio membri (3 e 4), ordine reale di ingresso, file concreto committato.
4. 17:00–19:30: prova generale in transazione annullata (calendario con i membri reali, `closed`, `locked`, punti
   simulati).
5. 20:30–20:40: ricontrollo che i membri siano gli stessi della prova generale (gli ingressi restano tecnicamente
   possibili fino al blocco).
6. 20:45: blocco. Dalle 20:46: S1 reale (calendario generato dal DB, lettura e confronto).
7. S2 e S3: simulati in transazione annullata (mai sul DB reale).
8. S4: turno concluso, quando Davide comunica che i risultati sono inseriti.
Nessuna migrazione sulle funzioni `h2h_*` fino a S4.
