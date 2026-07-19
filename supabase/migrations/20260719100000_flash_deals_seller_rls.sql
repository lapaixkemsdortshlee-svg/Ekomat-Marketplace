-- Flash Deal toujou absan (tès 2-3 moun, suite). Idempotente.
--
-- Koz rasin: policy INSERT sou flash_deals se admin-sèlman (is_admin()), men
-- se VANDÈ yo ki kreye rediksyon (bouton « Rediksyon » + flux piblikasyon).
-- Donk chak `insert` vandè a te rejte an silans pa RLS (console.warn avale
-- erè a) → tab flash_deals rete vid → bandwòl la pa janm parèt, menm si pri
-- pwodwi a (old_price) montre rabè a.
--
-- Fiks: yon vandè ka jere flash deal pou PWòP pwodwi li (product_id ki
-- pwente sou yon pwodwi kote seller_id = auth.uid()). Policies admin yo rete
-- (RLS permissive = OR), donk admin toujou ka jere tout.

drop policy if exists flash_deals_seller_insert on public.flash_deals;
create policy flash_deals_seller_insert on public.flash_deals
    for insert to authenticated
    with check (
        exists (
            select 1 from public.products p
            where p.id = product_id and p.seller_id = (select auth.uid())
        )
    );

drop policy if exists flash_deals_seller_update on public.flash_deals;
create policy flash_deals_seller_update on public.flash_deals
    for update to authenticated
    using (
        exists (
            select 1 from public.products p
            where p.id = product_id and p.seller_id = (select auth.uid())
        )
    )
    with check (
        exists (
            select 1 from public.products p
            where p.id = product_id and p.seller_id = (select auth.uid())
        )
    );

drop policy if exists flash_deals_seller_delete on public.flash_deals;
create policy flash_deals_seller_delete on public.flash_deals
    for delete to authenticated
    using (
        exists (
            select 1 from public.products p
            where p.id = product_id and p.seller_id = (select auth.uid())
        )
    );
