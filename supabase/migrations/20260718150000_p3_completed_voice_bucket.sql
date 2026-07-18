-- Lot P3: (1) achtè ka fèmen sik la (released → completed apre nòt),
-- (2) bucket Storage pou nòt vokal chat yo (olye base64 nan messages.content).
-- Idempotente.

-- 1) advance_order_status: yon sèl liy ajoute nan matris la —
--    achtè: released → completed (fèmen sik la apre li fin bay nòt).
--    Tout rès fonksyon an idantik ak vèsyon prod la (harden P2 enkli).
CREATE OR REPLACE FUNCTION public.advance_order_status(p_order_id uuid, p_to_status text, p_moncash_ref text DEFAULT NULL::text, p_admin_note text DEFAULT NULL::text)
 RETURNS orders
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
        -- P3 2026-07-18: achtè fèmen sik la apre nòt (lajan deja regle —
        -- se yon fèmti kosmetik, pa yon mouvman lajan).
        WHEN v_actor = v_order.buyer_id AND v_order.status = 'released' AND p_to_status = 'completed' THEN TRUE
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
$function$;

-- 2) Bucket nòt vokal (piblik an lekti, chemen {uid}/... an ekri).
--    Anvan: odyo a te ale an base64 nan messages.content — lou an data
--    pou voye AK pou chaje fil la. Ansyen mesaj yo rete konpatib (player
--    la li nenpòt url: data: oswa https:).
insert into storage.buckets (id, name, public)
values ('chat-voice', 'chat-voice', true)
on conflict (id) do nothing;

drop policy if exists chat_voice_insert_own on storage.objects;
create policy chat_voice_insert_own on storage.objects
    for insert to authenticated
    with check (
        bucket_id = 'chat-voice'
        and (storage.foldername(name))[1] = (select auth.uid())::text
    );
