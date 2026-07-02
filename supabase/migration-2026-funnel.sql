-- ══════════════════════════════════════════════════════════
--  AyitiMarket — Migration 2026-funnel — AARRR FUNNEL (Objectif B)
--  Execute via: Supabase Dashboard > SQL Editor > New Query
--  SAFE to re-run: CREATE OR REPLACE / idempotent.
--
--  Context (Objectif B — Croissance): before spending anything on ads,
--  we need to MEASURE what already works. This adds an admin-only, read-only
--  funnel snapshot computed entirely from EXISTING data (profiles, orders,
--  promo_codes) — so it works retroactively, with no event pipeline to
--  maintain. Mirrors escrow_overview() / error_overview().
--
--  AARRR:
--    Acquisition — signups, new 7d/30d, how many came via a referral
--    Activation  — placed >=1 order; "aha" = got a delivery (otp/released/completed)
--    Retention   — buyers with >=2 orders (repeat)
--    Referral    — referred signups + reward codes granted to referrers
--    Revenue     — GMV, net to sellers, fees, paid orders, AOV
--
--  SECURITY DEFINER bypasses RLS, so the is_admin guard is mandatory.
-- ══════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.funnel_overview()
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
    v_is_admin BOOLEAN;
    v_result   JSONB;
BEGIN
    SELECT is_admin INTO v_is_admin FROM public.profiles WHERE id = auth.uid();
    IF v_is_admin IS NOT TRUE THEN
        RAISE EXCEPTION 'funnel_overview: admin only';
    END IF;

    WITH buyer_orders AS (
        SELECT buyer_id,
               COUNT(*) AS n_orders,
               COUNT(*) FILTER (WHERE status IN ('otp_confirmed','released','completed')) AS n_fulfilled
        FROM public.orders
        WHERE buyer_id IS NOT NULL
        GROUP BY buyer_id
    ),
    agg AS (
        SELECT
            (SELECT COUNT(*) FROM public.profiles)                                          AS users_total,
            (SELECT COUNT(*) FROM public.profiles WHERE created_at >= now() - interval '7 days')  AS users_7d,
            (SELECT COUNT(*) FROM public.profiles WHERE created_at >= now() - interval '30 days') AS users_30d,
            (SELECT COUNT(*) FROM public.profiles WHERE referred_by IS NOT NULL)            AS users_referred,
            (SELECT COUNT(*) FROM buyer_orders)                                             AS buyers,
            (SELECT COUNT(*) FROM buyer_orders WHERE n_fulfilled >= 1)                      AS activated,
            (SELECT COUNT(*) FROM buyer_orders WHERE n_orders >= 2)                         AS repeat_buyers,
            (SELECT COUNT(*) FROM public.promo_codes WHERE scope = 'referral_reward')       AS rewards_granted,
            (SELECT COALESCE(SUM(total_amount) FILTER (WHERE status IN ('released','completed')), 0) FROM public.orders) AS gmv,
            (SELECT COALESCE(SUM(COALESCE(net_amount, total_amount - COALESCE(fee_amount,0)))
                    FILTER (WHERE status IN ('released','completed')), 0) FROM public.orders) AS net_sellers,
            (SELECT COALESCE(SUM(COALESCE(fee_amount,0)) FILTER (WHERE status IN ('released','completed')), 0) FROM public.orders) AS fees,
            (SELECT COUNT(*) FILTER (WHERE status IN ('released','completed')) FROM public.orders) AS paid_orders
    )
    SELECT jsonb_build_object(
        'generated_at', now(),
        'acquisition', jsonb_build_object(
            'total_users',       users_total,
            'new_7d',            users_7d,
            'new_30d',           users_30d,
            'referral_acquired', users_referred
        ),
        'activation', jsonb_build_object(
            'buyers',              buyers,
            'activated',           activated,
            'signup_to_buyer_pct', CASE WHEN users_total > 0
                                        THEN round(100.0 * buyers / users_total, 1) ELSE 0 END
        ),
        'retention', jsonb_build_object(
            'repeat_buyers', repeat_buyers,
            'repeat_pct',    CASE WHEN buyers > 0
                                  THEN round(100.0 * repeat_buyers / buyers, 1) ELSE 0 END
        ),
        'referral', jsonb_build_object(
            'referred_signups', users_referred,
            'rewards_granted',  rewards_granted
        ),
        'revenue', jsonb_build_object(
            'gmv_htg',            gmv,
            'net_to_sellers_htg', net_sellers,
            'fees_htg',           fees,
            'paid_orders',        paid_orders,
            'aov_htg',            CASE WHEN paid_orders > 0 THEN round(gmv / paid_orders) ELSE 0 END
        )
    )
    INTO v_result
    FROM agg;

    RETURN v_result;
END;
$$;

REVOKE ALL ON FUNCTION public.funnel_overview() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.funnel_overview() TO authenticated;

-- ══════════════════════════════════════════════════════════
--  DONE — quick check (run as an admin user):
--    SELECT public.funnel_overview();
-- ══════════════════════════════════════════════════════════
