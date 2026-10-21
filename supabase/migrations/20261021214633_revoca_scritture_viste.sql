-- Applicata in produzione il 2026-10-21 (MCP apply_migration). Igiene dei privilegi sulle viste.
-- `authenticated` ha oggi tutti i privilegi (anche INSERT/UPDATE/DELETE/TRUNCATE/...) su
-- calendar, prediction_scores e general_leaderboard. Sono viste con join (non scrivibili nei
-- fatti), ma restano concessi: si tolgono tutti tranne SELECT.
-- SELECT: resta dove c'è già (calendar, prediction_scores); general_leaderboard resta
-- senza SELECT (classifica generale sospesa fino a gennaio).
revoke insert, update, delete, truncate, references, trigger
  on public.calendar, public.prediction_scores, public.general_leaderboard
  from authenticated;
