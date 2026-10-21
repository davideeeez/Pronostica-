-- PROPOSTA — NON APPLICATA. Da applicare dopo le migrazioni 03a/03b/04 (decisione del 2026-10-21).
-- Privilegi di default per gli oggetti NUOVI creati dal ruolo postgres (quello delle migrazioni).
-- Verificato in dry-run (BEGIN … ROLLBACK) il 2026-10-21: senza queste righe una tabella nuova nasce con
-- tutti i privilegi per anon e authenticated, e una funzione nuova nasce eseguibile da PUBLIC e anon.

-- (a) funzioni: togliere EXECUTE a PUBLIC. Va fatto a livello GLOBALE (senza IN SCHEMA): il default
--     "PUBLIC può eseguire" è globale e un'istruzione per-schema non lo toglie.
alter default privileges for role postgres revoke execute on functions from public;
-- (b) funzioni nello schema public: via anon (le voci per authenticated e service_role restano)
alter default privileges for role postgres in schema public revoke execute on functions from anon;
-- (b-bis, OPZIONALE, piu' severo) anche authenticated: ogni funzione nuova richiede un grant esplicito
-- alter default privileges for role postgres in schema public revoke execute on functions from authenticated;
-- (c) tabelle e sequenze nello schema public: via anon e authenticated (service_role resta)
alter default privileges for role postgres in schema public revoke all on tables from anon, authenticated;
alter default privileges for role postgres in schema public revoke all on sequences from anon, authenticated;
