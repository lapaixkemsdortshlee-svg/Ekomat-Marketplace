-- Durcissement RLS sur public.orders : forcer TOUTES les transitions de
-- commande à passer par la machine à états (RPC advance_order_status,
-- SECURITY DEFINER). Avant ce correctif, les policies UPDATE participants
-- laissaient un acheteur/vendeur modifier orders.status en direct, ce qui :
--   1) contournait la matrice de transitions, le verrou d'état final et
--      l'audit de advance_order_status ;
--   2) pouvait déclencher le trigger trg_grant_referral_reward (AFTER UPDATE
--      OF status) sans passer par le flux escrow.
-- Le client officiel n'écrit JAMAIS orders en direct (tout via les RPC SECDEF
-- advance_order_status / try_seller_otp / hide_order / unhide_order), donc
-- retirer l'UPDATE participant ne casse aucun flux applicatif.
-- Idempotent.

-- 1) Retirer les policies UPDATE permissives (participants = surface d'attaque).
drop policy if exists orders_update on public.orders;
drop policy if exists orders_update_participants on public.orders;

-- 2) Conserver un override admin explicite (échappatoire manuel).
--    Les transitions admin normales passent déjà par le RPC SECDEF (qui
--    bypasse la RLS) ; cette policy sert de filet pour un correctif manuel.
drop policy if exists orders_update_admin on public.orders;
create policy orders_update_admin on public.orders
    for update to authenticated
    using (public.is_admin())
    with check (public.is_admin());

-- 3) Nettoyer la policy SELECT dupliquée (orders_select_own et
--    orders_select_participants étaient identiques). On garde orders_select_own
--    (acheteur OR vendeur OR admin) et on retire le doublon.
drop policy if exists orders_select_participants on public.orders;
