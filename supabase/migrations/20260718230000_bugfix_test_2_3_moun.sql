-- Bugfixes tès 2-3 moun (doc Thrasher 2026-07-18). Idempotente.
--
-- 1) KOZ RASIN uploads kase (Bug 11 "Sove lokalman sèlman" + foto pwodwi
--    toujou an base64 malgre #205): Storage API a fè INSERT ... RETURNING *.
--    San yon policy SELECT sou bucket la, RETURNING nan echwe ak yon
--    vyolasyon RLS (HTTP 400) — menm si INSERT/UPDATE policies yo bon.
--    Prèv: sèl bucket ki gen policy SELECT (verification-docs) se sèl kote
--    upload janm mache; Avatar/product-images/chat-voice pa gen okenn objè.
--    Referans: doc ofisyèl Supabase "Storage error: new row violates
--    row-level security policy on upload".

drop policy if exists avatar_select_own on storage.objects;
create policy avatar_select_own on storage.objects
    for select to authenticated
    using (
        bucket_id = 'Avatar'
        and (storage.foldername(name))[1] = (select auth.uid())::text
    );

drop policy if exists product_images_select_own on storage.objects;
create policy product_images_select_own on storage.objects
    for select to authenticated
    using (
        bucket_id = 'product-images'
        and (storage.foldername(name))[1] = 'products'
        and (storage.foldername(name))[2] = (select auth.uid())::text
    );

drop policy if exists chat_voice_select_own on storage.objects;
create policy chat_voice_select_own on storage.objects
    for select to authenticated
    using (
        bucket_id = 'chat-voice'
        and (storage.foldername(name))[1] = (select auth.uid())::text
    );

-- 2) Bug 3 — prèv peman achtè: bucket prive "payment-proofs".
--    Chemen kliyan an: {buyer_uid}/{order_id}_{ts}.jpg. Admin li prèv la
--    ak yon signed URL (bucket la PA piblik: screenshot MonCash gen enfo
--    sansib — ref, montan, nimewo).
insert into storage.buckets (id, name, public)
values ('payment-proofs', 'payment-proofs', false)
on conflict (id) do nothing;

drop policy if exists payment_proofs_insert_own on storage.objects;
create policy payment_proofs_insert_own on storage.objects
    for insert to authenticated
    with check (
        bucket_id = 'payment-proofs'
        and (storage.foldername(name))[1] = (select auth.uid())::text
    );

drop policy if exists payment_proofs_update_own on storage.objects;
create policy payment_proofs_update_own on storage.objects
    for update to authenticated
    using (
        bucket_id = 'payment-proofs'
        and (storage.foldername(name))[1] = (select auth.uid())::text
    )
    with check (
        bucket_id = 'payment-proofs'
        and (storage.foldername(name))[1] = (select auth.uid())::text
    );

-- SELECT: achtè a wè pwòp prèv li; admin wè tout (pou verifikasyon).
drop policy if exists payment_proofs_select_own_or_admin on storage.objects;
create policy payment_proofs_select_own_or_admin on storage.objects
    for select to authenticated
    using (
        bucket_id = 'payment-proofs'
        and (
            (storage.foldername(name))[1] = (select auth.uid())::text
            or public.is_admin()
        )
    );

-- 3) Kolòn chemen prèv la sou orders (chemen storage, pa URL — bucket prive).
alter table public.orders add column if not exists payment_proof_path text;

-- 4) RPC pou achtè a tache prèv li sou kòmand li (RLS UPDATE sou orders se
--    admin-sèlman depi #198 — achtè a pa ka ekri dirèk).
create or replace function public.attach_payment_proof(p_order_id uuid, p_path text)
returns void
language plpgsql
security definer
set search_path to ''
as $$
declare
    v_order public.orders;
begin
    select * into v_order from public.orders where id = p_order_id for update;
    if v_order.id is null then
        raise exception 'Order not found';
    end if;
    if v_order.buyer_id is distinct from auth.uid() then
        raise exception 'Only the buyer can attach a payment proof';
    end if;
    if v_order.status not in ('awaiting_payment', 'payment_submitted') then
        raise exception 'Proof can only be attached before verification';
    end if;
    if p_path is null or p_path !~ ('^' || auth.uid()::text || '/') then
        raise exception 'Invalid proof path';
    end if;
    update public.orders set payment_proof_path = p_path where id = p_order_id;
end;
$$;
revoke all on function public.attach_payment_proof(uuid, text) from public;
grant execute on function public.attach_payment_proof(uuid, text) to authenticated;

-- 5) Bug 5 — vandè ka fèmen sik la tou (released → completed), menm jan ak
--    achtè a (#209). Fèmti kosmetik: lajan an deja regle nan released.
--    Yon sèl liy nan matris la; tout rès fonksyon an idantik ak prod.
create or replace function public.advance_order_status(p_order_id uuid, p_to_status text, p_moncash_ref text default null::text, p_admin_note text default null::text)
 returns orders
 language plpgsql
 security definer
 set search_path to ''
as $function$
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
        -- Bug 5 tès 2-3 moun 2026-07-18: vandè a tou ka fèmen sik la.
        WHEN v_actor = v_order.seller_id AND v_order.status = 'released' AND p_to_status = 'completed' THEN TRUE
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

-- 6) Bug 6 — vizit pwodwi pa t janm konte (products.views rete 0 pou tout
--    tan): RLS UPDATE sou products se pwopriyetè-sèlman, donc yon achtè pa
--    ka enkremante views. RPC SECURITY DEFINER; pa konte pwòp vizit vandè a.
create or replace function public.increment_product_views(p_product_id uuid)
returns void
language sql
security definer
set search_path to ''
as $$
    update public.products
    set views = coalesce(views, 0) + 1
    where id = p_product_id
      and status = 'active'
      and seller_id is distinct from auth.uid();
$$;
revoke all on function public.increment_product_views(uuid) from public;
grant execute on function public.increment_product_views(uuid) to anon, authenticated;

-- 7) Bug 7 — kòd referral yo dwe kòmanse pa EKO- (retire AYIM- rebrand).
--    Migre kòd ki egziste yo; kliyan an jenere EKO- apati kounye a.
update public.profiles
set referral_code = 'EKO-' || substring(referral_code from 6)
where referral_code like 'AYIM-%';

update public.promo_codes
set code = 'EKO-' || substring(code from 6)
where code like 'AYIM-%';
