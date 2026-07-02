-- ══════════════════════════════════════════════════════════
--  AyitiMarket — Migration 2026-harden-p1 — SECURITY ADVISORS (P1)
--  Execute via: Supabase Dashboard > SQL Editor > New Query
--  SAFE to re-run: idempotent (ALTER/REVOKE).
--
--  Addresses the P1 findings from the security audit (Supabase advisors):
--
--  1) function_search_path_mutable — 3 trigger functions had no fixed
--     search_path (search_path hijack risk). Their bodies only use builtins
--     (NOW/CURRENT_TIMESTAMP/LPAD) or fully-qualified names
--     (nextval('public.orders_id_seq')), so pinning to '' is safe.
--
--  2) anon_security_definer_function_executable — Supabase auto-grants
--     EXECUTE to `anon` on new functions, so the admin-only observability
--     RPCs and the escrow state machine were callable (pre-auth) by anon.
--     They are already guarded internally (is_admin / auth.uid()), so this
--     was not exploitable — but least privilege says revoke `anon`.
--     `log_error` intentionally stays anon-callable (front error capture
--     happens before/without login).
-- ══════════════════════════════════════════════════════════

-- ──────────────────────────────────────────────────────────
-- 1) Pin search_path on the remaining trigger functions.
-- ──────────────────────────────────────────────────────────
ALTER FUNCTION public.generate_order_number()   SET search_path = '';
ALTER FUNCTION public.update_updated_at()        SET search_path = '';
ALTER FUNCTION public.update_updated_at_column() SET search_path = '';

-- ──────────────────────────────────────────────────────────
-- 2) Least privilege: revoke anon EXECUTE where it makes no sense.
--    Admin-only observability RPCs (guarded by is_admin):
-- ──────────────────────────────────────────────────────────
REVOKE EXECUTE ON FUNCTION public.escrow_overview()                 FROM anon;
REVOKE EXECUTE ON FUNCTION public.escrow_attention_orders(integer)  FROM anon;
REVOKE EXECUTE ON FUNCTION public.funnel_overview()                 FROM anon;
REVOKE EXECUTE ON FUNCTION public.error_overview()                  FROM anon;

-- Financial state machine + OTP: only signed-in actors ever call these.
REVOKE EXECUTE ON FUNCTION public.advance_order_status(uuid, text, text, text) FROM anon;
REVOKE EXECUTE ON FUNCTION public.try_seller_otp(uuid, text)                   FROM anon;

-- NOTE: log_error(text, text, jsonb) intentionally keeps anon EXECUTE
-- (captures front-end errors that can happen before authentication).

-- ══════════════════════════════════════════════════════════
--  DONE — verify:
--    -- no more mutable search_path on these:
--    SELECT proname, proconfig FROM pg_proc
--      WHERE proname IN ('generate_order_number','update_updated_at','update_updated_at_column');
--    -- anon should no longer be a grantee of the admin/escrow RPCs:
--    SELECT routine_name, grantee FROM information_schema.role_routine_grants
--      WHERE grantee = 'anon' AND routine_name IN
--        ('escrow_overview','funnel_overview','error_overview',
--         'escrow_attention_orders','advance_order_status','try_seller_otp');
--    -- then re-run the Supabase security advisors.
-- ══════════════════════════════════════════════════════════
