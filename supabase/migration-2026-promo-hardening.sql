-- ══════════════════════════════════════════════════════════
--  AyitiMarket — Migration 2026-promo-hardening — STOP CODE ENUMERATION
--  Execute via: Supabase Dashboard > SQL Editor > New Query
--  SAFE to re-run: idempotent.
--
--  Finding (QA live, Objectif A): the policy `promo_codes_public_select`
--  used `USING (active = true)`, so ANY visitor (even anon) could
--  `SELECT * FROM promo_codes` and enumerate every active promo code —
--  including admin discount codes never meant to be public.
--
--  Fix:
--   1) Restrict the public SELECT to referral-scope codes only. Referral
--      codes are meant to be shared (links), and the client still needs
--      to read them (linkReferralOnSignup, referral-code clash check).
--      Admin/general codes ('all', 'first_order') are no longer listable.
--   2) Add validate_promo_code() — a SECURITY DEFINER RPC that validates
--      ONE code at checkout (all scopes) without exposing the table.
--      The client calls this instead of selecting promo_codes directly.
-- ══════════════════════════════════════════════════════════

-- ──────────────────────────────────────────────────────────
-- 1) Tighten the public SELECT policy: referral codes only.
-- ──────────────────────────────────────────────────────────
DROP POLICY IF EXISTS promo_codes_public_select ON public.promo_codes;
CREATE POLICY promo_codes_public_select ON public.promo_codes
    FOR SELECT USING (active = true AND scope = 'referral');

-- ──────────────────────────────────────────────────────────
-- 2) validate_promo_code() — secure single-code validation.
--    Mirrors the client's previous logic (active, expiry, max_uses,
--    referral self-use, prior redemption, discount calc) server-side.
--    Returns: { ok, discount, code, discount_type, reason }
-- ──────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.validate_promo_code(p_code TEXT, p_total NUMERIC)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
    v_uid   UUID := auth.uid();
    v_code  TEXT := upper(btrim(coalesce(p_code, '')));
    v_promo public.promo_codes;
    v_disc  INTEGER;
BEGIN
    IF v_uid IS NULL THEN
        RETURN jsonb_build_object('ok', false, 'reason', 'Konekte pou aplike kòd');
    END IF;
    IF length(v_code) = 0 THEN
        RETURN jsonb_build_object('ok', false, 'reason', 'Antre yon kòd');
    END IF;

    SELECT * INTO v_promo FROM public.promo_codes
        WHERE code = v_code AND active = true;
    IF v_promo.id IS NULL THEN
        RETURN jsonb_build_object('ok', false, 'reason', 'Kòd pa egziste oswa pa aktif');
    END IF;
    IF v_promo.expires_at IS NOT NULL AND v_promo.expires_at < now() THEN
        RETURN jsonb_build_object('ok', false, 'reason', 'Kòd la ekspire');
    END IF;
    IF v_promo.max_uses IS NOT NULL AND v_promo.used_count >= v_promo.max_uses THEN
        RETURN jsonb_build_object('ok', false, 'reason', 'Kòd la rive nan limit itilizasyon li');
    END IF;
    IF v_promo.scope = 'referral' AND v_promo.referrer_id = v_uid THEN
        RETURN jsonb_build_object('ok', false, 'reason', 'Ou pa ka itilize pwòp kòd refè ou');
    END IF;
    IF EXISTS (SELECT 1 FROM public.promo_redemptions
               WHERE code = v_code AND user_id = v_uid) THEN
        RETURN jsonb_build_object('ok', false, 'reason', 'Ou deja itilize kòd sa a');
    END IF;

    -- Discount calc (parity with client _calcPromoDiscount).
    IF v_promo.discount_type = 'percent' THEN
        v_disc := least(p_total, round(p_total * v_promo.discount_value / 100.0))::INTEGER;
    ELSE
        v_disc := least(p_total, round(v_promo.discount_value))::INTEGER;
    END IF;
    IF v_disc <= 0 THEN
        RETURN jsonb_build_object('ok', false, 'reason', 'Kòd la pa aplikab sou total sa a');
    END IF;

    RETURN jsonb_build_object(
        'ok', true, 'discount', v_disc,
        'code', v_promo.code, 'discount_type', v_promo.discount_type);
END;
$$;

REVOKE ALL ON FUNCTION public.validate_promo_code(TEXT, NUMERIC) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.validate_promo_code(TEXT, NUMERIC) TO authenticated;

-- ══════════════════════════════════════════════════════════
--  DONE — checks:
--    -- as a normal (non-admin) user, this must now return few/zero rows:
--    SELECT count(*) FROM public.promo_codes;      -- only referral codes
--    -- validate a known code:
--    SELECT public.validate_promo_code('AYIM-XXXXXX', 1000);
-- ══════════════════════════════════════════════════════════
