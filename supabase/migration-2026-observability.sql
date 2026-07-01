-- ══════════════════════════════════════════════════════════
--  AyitiMarket — Migration 2026-observability — ESCROW HEALTH
--  Execute via: Supabase Dashboard > SQL Editor > New Query
--  SAFE to re-run: every object is CREATE OR REPLACE / idempotent.
--
--  Adds an admin-only observability layer over the escrow state
--  machine (see migration-2026-05.sql). Nothing here mutates orders —
--  it only reads + aggregates, server-side, so the admin panel never
--  has to pull every order row to the client.
--
--  Objects:
--    • escrow_overview()          — JSON dashboard: money held / released
--                                   / refunded, queue depths, alerts,
--                                   reconciliation anomaly counts.
--    • escrow_attention_orders()  — the actual rows that need a human:
--                                   verify-overdue, release-due/soon,
--                                   stale disputes, reconciliation issues.
--
--  Both are SECURITY DEFINER and refuse non-admin callers explicitly
--  (DEFINER bypasses RLS, so the guard is mandatory).
-- ══════════════════════════════════════════════════════════

-- ──────────────────────────────────────────────────────────
-- 0) Shared definitions (kept in sync via comments only — SQL has
--    no cheap way to share a constant list across functions):
--
--    HELD     escrow states (platform holds buyer's money):
--             payment_verified, ready_for_pickup, picked_up,
--             otp_confirmed, disputed
--    SETTLED  states (money paid out to seller):
--             released, completed
--    REFUNDED states: refunded
--    OPEN     pre-escrow states (no money held yet):
--             awaiting_payment, payment_submitted, pending
-- ──────────────────────────────────────────────────────────

-- ──────────────────────────────────────────────────────────
-- 1) escrow_overview() — one-call JSON dashboard for admins
-- ──────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.escrow_overview()
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
    v_is_admin BOOLEAN;
    v_hours    INTEGER;
    v_result   JSONB;
BEGIN
    SELECT is_admin INTO v_is_admin FROM public.profiles WHERE id = auth.uid();
    IF v_is_admin IS NOT TRUE THEN
        RAISE EXCEPTION 'escrow_overview: admin only';
    END IF;

    SELECT COALESCE(escrow_auto_release_hours, 168) INTO v_hours
        FROM public.app_settings WHERE id = 1;
    v_hours := COALESCE(v_hours, 168);

    SELECT jsonb_build_object(
        'generated_at', NOW(),
        'auto_release_hours', v_hours,

        -- Money snapshot (HTG, integer minor unit as stored on orders)
        'money', jsonb_build_object(
            'in_escrow_htg',       COALESCE(SUM(total_amount) FILTER (WHERE status IN
                ('payment_verified','ready_for_pickup','picked_up','otp_confirmed','disputed')), 0),
            'in_escrow_net_htg',   COALESCE(SUM(COALESCE(net_amount, total_amount - COALESCE(fee_amount,0))) FILTER (WHERE status IN
                ('payment_verified','ready_for_pickup','picked_up','otp_confirmed','disputed')), 0),
            'released_htg',        COALESCE(SUM(COALESCE(net_amount, total_amount - COALESCE(fee_amount,0))) FILTER (WHERE status IN
                ('released','completed')), 0),
            'refunded_htg',        COALESCE(SUM(total_amount) FILTER (WHERE status = 'refunded'), 0),
            'fees_earned_htg',     COALESCE(SUM(COALESCE(fee_amount,0)) FILTER (WHERE status IN
                ('released','completed')), 0)
        ),

        -- Work queues (what an admin has to act on)
        'queues', jsonb_build_object(
            'awaiting_verify', COUNT(*) FILTER (WHERE status = 'payment_submitted'),
            'awaiting_release', COUNT(*) FILTER (WHERE status = 'otp_confirmed'),
            'open_disputes',   COUNT(*) FILTER (WHERE status = 'disputed')
        ),

        -- Alerts (time-sensitive)
        'alerts', jsonb_build_object(
            -- buyer submitted a MonCash ref but admin hasn't verified in 24h+
            'verify_overdue_24h', COUNT(*) FILTER (
                WHERE status = 'payment_submitted'
                  AND COALESCE(paid_at, created_at) < NOW() - INTERVAL '24 hours'),
            -- delivered (otp_confirmed) and past the auto-release window → overdue to release
            'release_due', COUNT(*) FILTER (
                WHERE status = 'otp_confirmed'
                  AND delivered_at IS NOT NULL
                  AND delivered_at + (v_hours || ' hours')::INTERVAL <= NOW()),
            -- delivered and crossing the window within the next 12h
            'release_soon_12h', COUNT(*) FILTER (
                WHERE status = 'otp_confirmed'
                  AND delivered_at IS NOT NULL
                  AND delivered_at + (v_hours || ' hours')::INTERVAL > NOW()
                  AND delivered_at + (v_hours || ' hours')::INTERVAL <= NOW() + INTERVAL '12 hours'),
            -- disputes open more than 48h
            'dispute_stale_48h', COUNT(*) FILTER (
                WHERE status = 'disputed'
                  AND updated_at < NOW() - INTERVAL '48 hours')
        ),

        -- Reconciliation anomalies (data that shouldn't exist)
        'reconciliation', jsonb_build_object(
            -- net_amount stored but != total - fee
            'net_mismatch', COUNT(*) FILTER (
                WHERE net_amount IS NOT NULL
                  AND net_amount <> total_amount - COALESCE(fee_amount,0)),
            -- escrow active / settled but no MonCash reference on file
            'missing_ref', COUNT(*) FILTER (
                WHERE status IN ('payment_verified','ready_for_pickup','picked_up',
                                 'otp_confirmed','disputed','released','completed')
                  AND (moncash_ref IS NULL OR length(trim(moncash_ref)) = 0)),
            -- non-positive amounts
            'bad_amount', COUNT(*) FILTER (WHERE total_amount IS NULL OR total_amount <= 0),
            -- released without a recorded releaser (audit gap)
            'released_no_releaser', COUNT(*) FILTER (
                WHERE status = 'released' AND released_by IS NULL)
        )
    )
    INTO v_result
    FROM public.orders;

    -- Per-status breakdown as a separate aggregate
    v_result := v_result || jsonb_build_object('by_status', (
        SELECT COALESCE(jsonb_agg(row), '[]'::jsonb) FROM (
            SELECT jsonb_build_object(
                'status', status,
                'count', COUNT(*),
                'total_amount', COALESCE(SUM(total_amount), 0)
            ) AS row
            FROM public.orders
            GROUP BY status
            ORDER BY COUNT(*) DESC
        ) s
    ));

    RETURN v_result;
END;
$$;

REVOKE ALL ON FUNCTION public.escrow_overview() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.escrow_overview() TO authenticated;

-- ──────────────────────────────────────────────────────────
-- 2) escrow_attention_orders() — the rows a human must look at
--    Returns a JSON array, each item tagged with a `reason`.
--    p_limit caps the payload (default 100).
-- ──────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.escrow_attention_orders(p_limit INTEGER DEFAULT 100)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
    v_is_admin BOOLEAN;
    v_hours    INTEGER;
    v_result   JSONB;
BEGIN
    SELECT is_admin INTO v_is_admin FROM public.profiles WHERE id = auth.uid();
    IF v_is_admin IS NOT TRUE THEN
        RAISE EXCEPTION 'escrow_attention_orders: admin only';
    END IF;

    SELECT COALESCE(escrow_auto_release_hours, 168) INTO v_hours
        FROM public.app_settings WHERE id = 1;
    v_hours := COALESCE(v_hours, 168);

    SELECT COALESCE(jsonb_agg(item ORDER BY severity DESC, ref_time ASC), '[]'::jsonb)
    INTO v_result
    FROM (
        SELECT
            jsonb_build_object(
                'id', o.id,
                'reason', t.reason,
                'severity', t.severity,
                'status', o.status,
                'product_title', o.product_title,
                'buyer_name', o.buyer_name,
                'seller_name', o.seller_name,
                'total_amount', o.total_amount,
                'net_amount', COALESCE(o.net_amount, o.total_amount - COALESCE(o.fee_amount,0)),
                'moncash_ref', o.moncash_ref,
                'age_hours', ROUND(EXTRACT(EPOCH FROM (NOW() - t.ref_time)) / 3600.0)::INTEGER
            ) AS item,
            t.severity,
            t.ref_time
        FROM public.orders o
        CROSS JOIN LATERAL (
            VALUES
                ('release_due',        3, o.delivered_at),
                ('verify_overdue_24h', 2, COALESCE(o.paid_at, o.created_at)),
                ('dispute_stale_48h',  2, o.updated_at),
                ('release_soon_12h',   1, o.delivered_at),
                ('reconciliation',     2, o.created_at)
        ) AS t(reason, severity, ref_time)
        WHERE
            (t.reason = 'release_due'
                AND o.status = 'otp_confirmed'
                AND o.delivered_at IS NOT NULL
                AND o.delivered_at + (v_hours || ' hours')::INTERVAL <= NOW())
         OR (t.reason = 'release_soon_12h'
                AND o.status = 'otp_confirmed'
                AND o.delivered_at IS NOT NULL
                AND o.delivered_at + (v_hours || ' hours')::INTERVAL > NOW()
                AND o.delivered_at + (v_hours || ' hours')::INTERVAL <= NOW() + INTERVAL '12 hours')
         OR (t.reason = 'verify_overdue_24h'
                AND o.status = 'payment_submitted'
                AND COALESCE(o.paid_at, o.created_at) < NOW() - INTERVAL '24 hours')
         OR (t.reason = 'dispute_stale_48h'
                AND o.status = 'disputed'
                AND o.updated_at < NOW() - INTERVAL '48 hours')
         OR (t.reason = 'reconciliation'
                AND (
                    (o.net_amount IS NOT NULL AND o.net_amount <> o.total_amount - COALESCE(o.fee_amount,0))
                 OR (o.status IN ('payment_verified','ready_for_pickup','picked_up',
                                  'otp_confirmed','disputed','released','completed')
                        AND (o.moncash_ref IS NULL OR length(trim(o.moncash_ref)) = 0))
                 OR (o.total_amount IS NULL OR o.total_amount <= 0)
                 OR (o.status = 'released' AND o.released_by IS NULL)
                ))
        LIMIT GREATEST(p_limit, 1)
    ) ranked;

    RETURN v_result;
END;
$$;

REVOKE ALL ON FUNCTION public.escrow_attention_orders(INTEGER) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.escrow_attention_orders(INTEGER) TO authenticated;

-- ══════════════════════════════════════════════════════════
--  DONE — quick checks (run as an admin user):
--    SELECT public.escrow_overview();
--    SELECT public.escrow_attention_orders(20);
-- ══════════════════════════════════════════════════════════
