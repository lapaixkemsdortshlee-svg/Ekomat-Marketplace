-- ══════════════════════════════════════════════════════════
--  AyitiMarket — Migration 2026-escrow-guards — STATE-MACHINE HARDENING
--  Execute via: Supabase Dashboard > SQL Editor > New Query
--  SAFE to re-run: CREATE OR REPLACE, idempotent.
--
--  Objective A / P2 — hardens the escrow state machine
--  (advance_order_status, from migration-2026-05.sql) against two
--  money-safety holes found in review:
--
--   1) No idempotence guard. Re-issuing the SAME status (e.g. an admin
--      double-clicking "Lage lajan" → released→released) re-ran the side
--      effects: re-stamped released_at and inserted a duplicate
--      admin_actions audit row. Since the payout is off-platform, a
--      confused admin could pay a seller twice.
--
--   2) No terminal-state lock. The admin branch allowed ANY transition,
--      so a finalized order (refunded / cancelled / completed) could be
--      pushed back to `released` — paying a seller for a refunded order.
--
--  Fix (defense in depth, added BEFORE the existing per-role checks so it
--  applies to everyone, admins included):
--   • from == to  → idempotent no-op (return the row unchanged, no side
--     effects, no audit spam).
--   • from IN (completed, refunded, cancelled) → hard stop.
--
--  Everything else (the per-role transition matrix, side effects, audit)
--  is reproduced verbatim from migration-2026-05.sql. search_path is now
--  pinned (also clears the function_search_path_mutable advisor).
-- ══════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.advance_order_status(
    p_order_id UUID,
    p_to_status TEXT,
    p_moncash_ref TEXT DEFAULT NULL,
    p_admin_note TEXT DEFAULT NULL
) RETURNS public.orders
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
    v_order public.orders;
    v_actor UUID := auth.uid();
    v_is_admin BOOLEAN;
    v_allowed BOOLEAN := FALSE;
    v_from_status TEXT;
BEGIN
    SELECT * INTO v_order FROM public.orders WHERE id = p_order_id FOR UPDATE;
    IF v_order.id IS NULL THEN RAISE EXCEPTION 'Order not found'; END IF;
    v_from_status := v_order.status;

    SELECT is_admin INTO v_is_admin FROM public.profiles WHERE id = v_actor;

    -- ── Durcissement (P2): idempotence + terminal-state lock ──
    -- Applies to everyone, admins included, before the per-role checks.

    -- Idempotent no-op: re-issuing the same status must not re-run side
    -- effects (double payout, duplicate audit rows).
    IF v_from_status = p_to_status THEN
        RETURN v_order;
    END IF;

    -- Final states never move again — protects money already settled.
    IF v_from_status IN ('completed', 'refunded', 'cancelled') THEN
        RAISE EXCEPTION 'Order % is in a final state (%); no further transition allowed',
            p_order_id, v_from_status;
    END IF;

    -- Validate transition (unchanged from migration-2026-05.sql)
    v_allowed := CASE
        -- Buyer actions
        WHEN v_actor = v_order.buyer_id AND v_order.status = 'awaiting_payment' AND p_to_status = 'payment_submitted' THEN TRUE
        WHEN v_actor = v_order.buyer_id AND v_order.status = 'awaiting_payment' AND p_to_status = 'cancelled' THEN TRUE
        WHEN v_actor = v_order.buyer_id AND v_order.status IN ('ready_for_pickup','otp_confirmed','released') AND p_to_status = 'disputed' THEN TRUE
        -- Seller actions
        WHEN v_actor = v_order.seller_id AND v_order.status = 'payment_verified' AND p_to_status = 'ready_for_pickup' THEN TRUE
        WHEN v_actor = v_order.seller_id AND v_order.status = 'ready_for_pickup' AND p_to_status = 'otp_confirmed' THEN TRUE
        WHEN v_actor = v_order.seller_id AND v_order.status IN ('ready_for_pickup','otp_confirmed') AND p_to_status = 'disputed' THEN TRUE
        -- Admin actions (can force any *non-final* transition; finality is
        -- already enforced above)
        WHEN v_is_admin = TRUE THEN TRUE
        ELSE FALSE
    END;

    IF NOT v_allowed THEN
        RAISE EXCEPTION 'Illegal transition: % → % by user %', v_order.status, p_to_status, v_actor;
    END IF;

    -- Apply side effects per target state (unchanged)
    UPDATE public.orders
        SET status      = p_to_status,
            moncash_ref = COALESCE(p_moncash_ref, moncash_ref),
            admin_note  = COALESCE(p_admin_note,  admin_note),
            paid_at      = CASE WHEN p_to_status = 'payment_submitted' THEN NOW() ELSE paid_at END,
            verified_at  = CASE WHEN p_to_status = 'payment_verified'  THEN NOW() ELSE verified_at END,
            verified_by  = CASE WHEN p_to_status = 'payment_verified'  THEN v_actor ELSE verified_by END,
            ready_at     = CASE WHEN p_to_status = 'ready_for_pickup'  THEN NOW() ELSE ready_at END,
            delivered_at = CASE WHEN p_to_status = 'otp_confirmed'     THEN NOW() ELSE delivered_at END,
            released_at  = CASE WHEN p_to_status = 'released'          THEN NOW() ELSE released_at END,
            released_by  = CASE WHEN p_to_status = 'released'          THEN v_actor ELSE released_by END,
            cancelled_at = CASE WHEN p_to_status IN ('cancelled','refunded') THEN NOW() ELSE cancelled_at END
        WHERE id = p_order_id
        RETURNING * INTO v_order;

    -- Audit log for admin-initiated transitions (unchanged)
    IF v_is_admin = TRUE THEN
        INSERT INTO public.admin_actions (admin_id, order_id, action, from_status, to_status, note)
        VALUES (v_actor, p_order_id, p_to_status, v_from_status, p_to_status, p_admin_note);
    END IF;

    RETURN v_order;
END;
$$;

GRANT EXECUTE ON FUNCTION public.advance_order_status(UUID, TEXT, TEXT, TEXT) TO authenticated;

-- ══════════════════════════════════════════════════════════
--  DONE — sanity checks (as an admin):
--    -- normal release works:
--    SELECT status FROM public.advance_order_status('<otp_confirmed order>', 'released');
--    -- second identical call is a no-op (no duplicate admin_actions row):
--    SELECT status FROM public.advance_order_status('<same order>', 'released');
--    -- a refunded order cannot be moved:
--    SELECT public.advance_order_status('<refunded order>', 'released'); -- raises
-- ══════════════════════════════════════════════════════════
