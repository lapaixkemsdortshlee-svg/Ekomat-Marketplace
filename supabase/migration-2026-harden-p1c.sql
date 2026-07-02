-- ══════════════════════════════════════════════════════════
--  AyitiMarket — Migration 2026-harden-p1c — hide trigger fns from API
--  Execute via: Supabase Dashboard > SQL Editor > New Query
--  SAFE to re-run: idempotent.
--
--  The advisors still flag several functions as callable by anon/authenticated
--  (lints 0028/0029). These are TRIGGER / event-trigger functions, not RPCs —
--  no code path calls them via /rest/v1/rpc (verified across the repo). A
--  trigger function does NOT need EXECUTE granted to the DML role: Postgres
--  fires triggers with the table-owner context and does not check the caller's
--  EXECUTE privilege. So revoking EXECUTE removes them from the PostgREST API
--  surface entirely WITHOUT affecting the triggers.
--
--  Left intentionally callable (NOT touched here):
--    - log_error, increment_views : anon by design (front error capture, public views)
--    - validate_promo_code        : real checkout RPC (authenticated; self-rejects anon)
--    - is_admin                   : used inside RLS policies (needs EXECUTE for authenticated)
-- ══════════════════════════════════════════════════════════

REVOKE EXECUTE ON FUNCTION public.grant_referral_reward()   FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.handle_new_user()          FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.promo_codes_inc_used()     FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.update_seller_rating()     FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.rls_auto_enable()          FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.generate_order_number()    FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.update_updated_at()        FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.update_updated_at_column() FROM PUBLIC, anon, authenticated;

-- ══════════════════════════════════════════════════════════
--  DONE — verify (these should no longer appear for anon/authenticated):
--    SELECT p.proname,
--      array_agg(g.grantee) FILTER (WHERE g.grantee IN ('anon','authenticated','PUBLIC')) AS grantees
--    FROM pg_proc p
--    LEFT JOIN information_schema.role_routine_grants g
--      ON g.routine_schema='public' AND g.routine_name=p.proname
--    WHERE p.proname IN ('grant_referral_reward','handle_new_user','promo_codes_inc_used',
--      'update_seller_rating','rls_auto_enable','generate_order_number',
--      'update_updated_at','update_updated_at_column')
--    GROUP BY p.proname;
--    -- then re-run the security advisors: 0028/0029 should drop for these.
--  Sanity: create an order (trigger generate_order_number/updated_at still fire),
--  sign up a user (handle_new_user still fires), submit a rating (update_seller_rating).
-- ══════════════════════════════════════════════════════════
