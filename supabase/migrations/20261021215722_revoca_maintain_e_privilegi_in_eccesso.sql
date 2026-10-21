-- Applicata in produzione il 2026-10-21 (MCP apply_migration). Igiene dei privilegi su tutte le relazioni di public.
-- Letto in produzione (2026-10-21): anon non ha nulla; authenticated ha in piu' solo MAINTAIN
-- (PostgreSQL 17: LOCK TABLE, VACUUM, ANALYZE, REINDEX, CLUSTER, REFRESH MATERIALIZED VIEW) su
-- matches, rounds, predictions, profiles, calendar, prediction_scores, general_leaderboard.
-- I privilegi attesi per authenticated restano quelli di oggi (vedi security.sql, test ST1).
do $$
declare
  r record;
begin
  for r in
    select c.oid::regclass as rel
    from pg_class c join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relkind in ('r', 'v', 'm', 'p', 'f')
  loop
    execute format('revoke all on %s from anon, public', r.rel);
    execute format('revoke maintain on %s from authenticated', r.rel);
  end loop;
end $$;
