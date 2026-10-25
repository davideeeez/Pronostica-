-- Ripristina i privilegi di default per tabelle e sequenze nuove in public (ruolo postgres),
-- così com'erano prima della migrazione default_privilegi_tabelle_sequenze (letti in produzione il 2026-10-21).
-- Non tocca le funzioni: il default delle funzioni non è stato modificato.
alter default privileges for role postgres in schema public grant all on tables to anon, authenticated;
alter default privileges for role postgres in schema public grant all on sequences to anon, authenticated;
