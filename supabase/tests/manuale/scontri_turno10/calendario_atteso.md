# Test reale scontri diretti — turno 10: calendario atteso

Salvato nel repo il 2026-10-27, PRIMA di qualunque prova generale e prima che i soci entrino nelle leghe.
Blocco del turno 10: `rounds.locks_at = 2026-10-31 14:00:00+00` (sabato 31/10, ore 15:00 italiane — verificato in produzione).

Leghe create il 2026-10-27 (claim `davidezotti`, transazione committata, `create_h2h_league(nome, 10)`):

| Lega | Id |
|---|---|
| Scontri 3 membri (prova) | `f84909cd-f5e3-472e-b93a-ff4fe8a623b2` |
| Scontri 4 membri (prova) | `a93c7f49-99cf-4fe7-a41a-2e37b2f5072f` |

I codici di invito NON sono nel repo.

## Membri e ordine di ingresso previsto
Il calendario ordina i membri per `(joined_at, user_id)`. m1 è sempre `davidezotti` (owner, entrato alla creazione).

| Lega | m1 | m2 | m3 | m4 |
|---|---|---|---|---|
| 3 membri | davidezotti | Marco o BR1 (primo ad entrare) | l'altro | — |
| 4 membri | davidezotti | Marco o BR1 | l'altro | accountprova (ultimo) |

L'ordine reale va letto dalle righe di `league_members` (tabella base) giovedì sera e il file concreto con gli
id va committato prima della prova generale (`calendario_atteso_concreto.csv`, prodotto con `calcolo_calendario.py`).

## Abbinamenti attesi (turni 10, 11, 12; poi il ciclo si ripete fino al 38)

Lega a 3 (ciclo di 3 turni, un riposo a turno):

| Turno | Riposa | Scontro |
|---|---|---|
| 10 | m1 | m2 – m3 |
| 11 | m2 | m1 – m3 |
| 12 | m3 | m1 – m2 |
| 13 | = turno 10 | |

Lega a 4 (ciclo di 3 turni, nessun riposo):

| Turno | Scontri |
|---|---|
| 10 | m1 – m4, m2 – m3 |
| 11 | m1 – m3, m4 – m2 |
| 12 | m1 – m2, m3 – m4 |
| 13 | = turno 10 |

Conseguenze per il turno 10: Davide riposa nella lega a 3; nella lega a 4 affronta `accountprova`, che non pronostica
(Davide vince 3–0 solo se fa almeno 1 punto, altrimenti pareggio 1–1).

## Proprietà che devono valere (indipendenti dalla convenzione di rotazione)
- ogni membro compare esattamente una volta per turno; con N dispari un solo riposo a turno, N pari nessuno;
- nel primo ciclo ogni coppia si incontra esattamente una volta; con N dispari ognuno riposa esattamente una volta;
- il turno k + ciclo ripete il turno k; calendario dal turno 10 al 38;
- righe attese: lega a 3 = 29 turni x 2 abbinamenti = 58; lega a 4 = 29 turni x 2 = 58.

Limite dichiarato: *quale* coppia cade in *quale* turno segue la convenzione del codice SQL (primo membro fisso, altri
ruotati di una posizione a destra); questa parte non è una verifica indipendente.

## Calendario del test
1. 2026-10-27: leghe create, tabella attesa salvata (questo file e `calcolo_calendario.py`).
2. fino a venerdì 30/10: soci entrano con il codice (accountprova per ultimo nella lega a 4).
3. venerdì 30/10 sera: ordine reale di ingresso -> file concreto committato -> prova generale in transazione annullata.
4. sabato 31/10 mattina (prima delle 15:00): riconteggio membri (3 e 4) e `regenerate_invite_code` non necessario.
5. sabato 31/10 dalle 15:01: calendario generato dal DB, istantanee S1-S4, test negativi (closed, locked) in transazione annullata.
