-- ══════════════════════════════════════════════════════════
--  AyitiMarket — Migration 2026-harden-p1b — REVOKE PUBLIC on escrow RPCs
--  Execute via: Supabase Dashboard > SQL Editor > New Query
--  SAFE to re-run: idempotent.
--
--  Follow-up to harden-p1. After deploying harden-p1 the advisors showed
--  `advance_order_status` and `try_seller_otp` STILL executable by `anon`.
--  Root cause: both still carry a PUBLIC grant from their original CREATE,
--  and `anon` is a member of PUBLIC — so `REVOKE ... FROM anon` alone was
--  masked by the PUBLIC grant. (The observability RPCs came out clean
--  because PUBLIC had already been revoked on them by harden-functions.)
--
--  Fix: revoke PUBLIC (and anon, belt-and-suspenders) on these two money-
--  path functions; keep the direct `authenticated` grant so buyers/sellers/
--  admins still call them. Not exploitable by anon today (auth.uid() is null
--  → internal checks reject), but least privilege on the financial path.
-- ══════════════════════════════════════════════════════════

REVOKE EXECUTE ON FUNCTION public.advance_order_status(uuid, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.try_seller_otp(uuid, text)                   FROM PUBLIC, anon;

-- Ensure signed-in actors keep access (idempotent; they already have it).
GRANT EXECUTE ON FUNCTION public.advance_order_status(uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.try_seller_otp(uuid, text)                   TO authenticated;

-- ══════════════════════════════════════════════════════════
--  DONE — verify (grantees should be {authenticated} only):
--    SELECT p.proname,
--      array_agg(g.grantee) FILTER (WHERE g.grantee IN ('anon','authenticated','PUBLIC'))
--    FROM pg_proc p
--    LEFT JOIN information_schema.role_routine_grants g
--      ON g.routine_schema='public' AND g.routine_name=p.proname
--    WHERE p.proname IN ('advance_order_status','try_seller_otp')
--    GROUP BY p.proname;
--    -- then re-run the security advisors.
-- ══════════════════════════════════════════════════════════
