-- ══════════════════════════════════════════════════════════
--  AyitiMarket — Migration 2026-harden-functions — SECURITY HARDENING
--  Execute via: Supabase Dashboard > SQL Editor > New Query
--  SAFE to re-run: idempotent.
--
--  Fixes Supabase security-advisor findings (Objective A / durcissement):
--
--   1) function_search_path_mutable — every SECURITY DEFINER function
--      must pin its search_path, or a caller who can create objects in an
--      earlier schema could shadow the objects the function uses. We set
--      `search_path = pg_catalog, public` on every SECURITY DEFINER
--      function in `public` that doesn't already pin one. `public` is kept
--      so functions that reference unqualified table names keep working.
--      (The functions shipped by AyitiMarket's own migrations pin
--      `search_path = ''` in their own files — they fully schema-qualify.)
--
--   2) anon/authenticated can execute privileged SECURITY DEFINER RPCs —
--      lock down the escrow admin/cron functions so they aren't callable
--      from the public REST API by anon (they already guard internally,
--      but defense in depth). escrow_dispatch_alerts is cron/owner-only.
--
--  NOT fixable in SQL (do these in the Supabase dashboard):
--   • Auth → enable "Leaked password protection" (HaveIBeenPwned).
--   • Extensions pg_trgm / pg_net live in `public`; moving them can break
--     dependent code, so leave unless you audit the dependencies.
-- ══════════════════════════════════════════════════════════

-- ──────────────────────────────────────────────────────────
-- 1) Pin search_path on every SECURITY DEFINER function in public
--    that doesn't already have one set.
-- ──────────────────────────────────────────────────────────
DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN
        SELECT p.oid::regprocedure AS sig
        FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname = 'public'
          AND p.prosecdef = TRUE
          AND NOT EXISTS (
              SELECT 1 FROM unnest(COALESCE(p.proconfig, '{}')) c
              WHERE c LIKE 'search_path=%'
          )
    LOOP
        EXECUTE format('ALTER FUNCTION %s SET search_path = pg_catalog, public', r.sig);
        RAISE NOTICE 'Pinned search_path on %', r.sig;
    END LOOP;
END $$;

-- ──────────────────────────────────────────────────────────
-- 2) Lock down privileged escrow RPCs (guarded: only if present).
-- ──────────────────────────────────────────────────────────
DO $$
BEGIN
    -- Cron/owner only: never callable from the public REST API.
    IF to_regprocedure('public.escrow_dispatch_alerts()') IS NOT NULL THEN
        EXECUTE 'REVOKE ALL ON FUNCTION public.escrow_dispatch_alerts() FROM PUBLIC, anon, authenticated';
    END IF;

    -- Admin dashboards: signed-in only (they still re-check is_admin inside).
    IF to_regprocedure('public.escrow_overview()') IS NOT NULL THEN
        EXECUTE 'REVOKE ALL ON FUNCTION public.escrow_overview() FROM PUBLIC';
        EXECUTE 'GRANT EXECUTE ON FUNCTION public.escrow_overview() TO authenticated';
    END IF;

    IF to_regprocedure('public.escrow_attention_orders(integer)') IS NOT NULL THEN
        EXECUTE 'REVOKE ALL ON FUNCTION public.escrow_attention_orders(integer) FROM PUBLIC';
        EXECUTE 'GRANT EXECUTE ON FUNCTION public.escrow_attention_orders(integer) TO authenticated';
    END IF;

    IF to_regprocedure('public.error_overview()') IS NOT NULL THEN
        EXECUTE 'REVOKE ALL ON FUNCTION public.error_overview() FROM PUBLIC';
        EXECUTE 'GRANT EXECUTE ON FUNCTION public.error_overview() TO authenticated';
    END IF;
END $$;

-- ══════════════════════════════════════════════════════════
--  DONE — re-run the security advisor to confirm the
--  function_search_path_mutable warnings are cleared:
--    (Supabase Dashboard → Advisors → Security)
-- ══════════════════════════════════════════════════════════
