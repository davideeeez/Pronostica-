-- PROPOSTA 1d — Igiene dei privilegi EXECUTE sulle funzioni esistenti di public.
-- Letto in produzione (2026-10-21): quattro funzioni erano eseguibili da PUBLIC e anon.
-- - prediction_points, round_is_open: authenticated resta (le usano policy RLS e viste).
-- - matches_default_status, predictions_prevent_identity_change: funzioni-trigger, nessun ruolo
--   deve poterle chiamare (il privilegio non e' richiesto per far scattare un trigger).
revoke execute on function public.prediction_points(integer, integer, integer, integer) from public, anon;
revoke execute on function public.round_is_open(text) from public, anon;
revoke execute on function public.matches_default_status() from public, anon, authenticated;
revoke execute on function public.predictions_prevent_identity_change() from public, anon, authenticated;
