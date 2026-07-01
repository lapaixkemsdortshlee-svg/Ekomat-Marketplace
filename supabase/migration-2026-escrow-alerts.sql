-- ══════════════════════════════════════════════════════════
--  AyitiMarket — Migration 2026-escrow-alerts — REAL-TIME ALERTS
--  Execute via: Supabase Dashboard > SQL Editor > New Query
--  SAFE to re-run: every object is idempotent.
--
--  Turns the passive escrow observability (migration-2026-observability.sql)
--  into alerts that reach the admin on their own, without anyone opening
--  the app. It reuses the existing notification pipeline:
--
--    INSERT into public.notifications  →  Database Webhooks fire  →
--    send-push (FCM) + send-email (Resend) deliver to the admin.
--
--  So one notification row = both channels (push AND email).
--
--  Pieces:
--    • escrow_alert_log     — dedup ledger, one row per (order, reason),
--                             so an admin is alerted once per situation,
--                             never re-spammed every hour.
--    • escrow_dispatch_alerts() — scans time-sensitive escrow situations,
--                             logs new ones, and inserts a notification
--                             for every admin.
--    • pg_cron job          — runs the dispatcher hourly.
--
--  Reasons alerted (time-sensitive only; data-quality anomalies stay in
--  the Sante Escrow card, not pushed):
--    release_due        — otp_confirmed past the auto-release window
--    release_soon_12h   — otp_confirmed crossing the window within 12h
--    verify_overdue_24h — payment_submitted waiting > 24h for admin verify
--    dispute_stale_48h  — dispute open > 48h
-- ══════════════════════════════════════════════════════════

-- ──────────────────────────────────────────────────────────
-- 1) DEDUP LEDGER — one alert per (order, reason), ever
-- ──────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.escrow_alert_log (
    order_id   UUID REFERENCES public.orders(id) ON DELETE CASCADE,
    reason     TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (order_id, reason)
);

ALTER TABLE public.escrow_alert_log ENABLE ROW LEVEL SECURITY;

-- Admins can read the ledger (writes only happen through the SECURITY
-- DEFINER dispatcher below).
DROP POLICY IF EXISTS "escrow_alert_log_admin_read" ON public.escrow_alert_log;
CREATE POLICY "escrow_alert_log_admin_read" ON public.escrow_alert_log
    FOR SELECT USING (
        EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND is_admin = TRUE)
    );

-- ──────────────────────────────────────────────────────────
-- 2) DISPATCHER — find new situations, notify every admin
--    Returns the number of notification rows inserted.
-- ──────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.escrow_dispatch_alerts()
RETURNS INTEGER
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
    v_hours INTEGER;
    v_new   INTEGER := 0;
    r       RECORD;
    a       RECORD;
    v_title TEXT;
    v_body  TEXT;
    v_color TEXT;
BEGIN
    SELECT COALESCE(escrow_auto_release_hours, 168) INTO v_hours
        FROM public.app_settings WHERE id = 1;
    v_hours := COALESCE(v_hours, 168);

    FOR r IN
        SELECT o.id, o.product_title, o.buyer_name, o.seller_name,
               COALESCE(o.net_amount, o.total_amount - COALESCE(o.fee_amount,0)) AS net,
               t.reason
        FROM public.orders o
        CROSS JOIN LATERAL (VALUES
            ('release_due'),
            ('release_soon_12h'),
            ('verify_overdue_24h'),
            ('dispute_stale_48h')
        ) AS t(reason)
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
    LOOP
        -- Dedup: only proceed the first time this (order, reason) is seen.
        INSERT INTO public.escrow_alert_log(order_id, reason)
        VALUES (r.id, r.reason)
        ON CONFLICT (order_id, reason) DO NOTHING;
        IF NOT FOUND THEN
            CONTINUE;  -- already alerted for this situation
        END IF;

        -- Message per reason (Kreyòl).
        IF r.reason = 'release_due' THEN
            v_title := '⏰ Lajan pou libere';
            v_color := '#b91c1c';
            v_body  := 'Kòmand «' || COALESCE(r.product_title,'?') || '» depase ' || v_hours
                       || 'è. Libere ' || to_char(r.net, 'FM999,999,999') || ' HTG bay '
                       || COALESCE(r.seller_name,'vandè a') || '.';
        ELSIF r.reason = 'release_soon_12h' THEN
            v_title := '⏳ Libere ap pwoche';
            v_color := '#92400e';
            v_body  := 'Kòmand «' || COALESCE(r.product_title,'?')
                       || '» ap rive nan otorelease nan mwens pase 12è.';
        ELSIF r.reason = 'verify_overdue_24h' THEN
            v_title := '⚠️ Peman pou verifye';
            v_color := '#92400e';
            v_body  := 'Achtè «' || COALESCE(r.buyer_name,'?')
                       || '» soumèt yon peman depi plis pase 24è. Verifye l.';
        ELSE  -- dispute_stale_48h
            v_title := '🚩 Litij ki rete louvri';
            v_color := '#991b1b';
            v_body  := 'Litij sou «' || COALESCE(r.product_title,'?')
                       || '» louvri depi plis pase 48è. Rezoud li.';
        END IF;

        -- Fan-out to every admin. Each INSERT triggers push + email
        -- through the existing notifications webhooks.
        FOR a IN SELECT id FROM public.profiles WHERE is_admin = TRUE LOOP
            INSERT INTO public.notifications(user_id, type, icon, title, body, color, data)
            VALUES (
                a.id, 'order', 'monitoring', v_title, v_body, v_color,
                jsonb_build_object('order_id', r.id, 'kind', 'escrow_alert', 'reason', r.reason)
            );
            v_new := v_new + 1;
        END LOOP;
    END LOOP;

    RETURN v_new;
END;
$$;

-- Only the owner (and pg_cron, which runs as the owner) may call it.
-- Not exposed to app clients, to avoid manual alert spam.
REVOKE ALL ON FUNCTION public.escrow_dispatch_alerts() FROM PUBLIC;

-- ──────────────────────────────────────────────────────────
-- 3) SCHEDULE — run the dispatcher every hour via pg_cron.
--    Wrapped so the migration still succeeds (function + table stay
--    installed) even if pg_cron isn't enabled yet. If it isn't,
--    enable it in Supabase → Database → Extensions, then re-run.
-- ──────────────────────────────────────────────────────────
DO $$
BEGIN
    CREATE EXTENSION IF NOT EXISTS pg_cron;

    IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'escrow-alerts-hourly') THEN
        PERFORM cron.unschedule('escrow-alerts-hourly');
    END IF;

    PERFORM cron.schedule(
        'escrow-alerts-hourly',
        '17 * * * *',
        'SELECT public.escrow_dispatch_alerts();'
    );
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'pg_cron not scheduled (enable it in Supabase → Database → Extensions, then re-run this migration): %', SQLERRM;
END $$;

-- ══════════════════════════════════════════════════════════
--  DONE — quick checks:
--    -- dry run (safe; dedup prevents re-alerts): returns rows inserted
--    SELECT public.escrow_dispatch_alerts();
--    -- see what has been alerted
--    SELECT * FROM public.escrow_alert_log ORDER BY created_at DESC;
--    -- confirm the cron job exists
--    SELECT jobname, schedule FROM cron.job WHERE jobname = 'escrow-alerts-hourly';
-- ══════════════════════════════════════════════════════════
