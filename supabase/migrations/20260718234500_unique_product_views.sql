-- Vrè "visiteurs uniques" (tès 2-3 moun, suite). Idempotente.
--
-- Pwoblèm: increment_product_views (PR anvan) enkremante products.views nan
-- CHAK ouvèti fich → menm moun ki relouvri gonfle chif la. product_views gen
-- 116 ranje men sèlman 11 pè (pwodwi, viewer) inik.
--
-- Fiks: RPC la konte yon vizit YON SÈL fwa pa (viewer, pwodwi). Pou vizitè
-- konekte, dedup fèt sou sèvè a (li tcheke product_views). Pou envite (san
-- kont), dedup fèt kote kliyan an (localStorage) — RPC la jis konte +1.

create or replace function public.increment_product_views(p_product_id uuid)
returns void
language plpgsql
security definer
set search_path to ''
as $$
declare
    v_uid    uuid := auth.uid();
    v_seller uuid;
begin
    select seller_id into v_seller
    from public.products
    where id = p_product_id and status = 'active';
    if v_seller is null then
        return;  -- pwodwi pa aktif oswa pa egziste
    end if;
    -- Pa janm konte pwòp vizit vandè a.
    if v_uid is not null and v_uid = v_seller then
        return;
    end if;

    if v_uid is not null then
        -- Vizitè konekte: dedup pa (pwodwi, viewer) — sèlman premye vizyon konte.
        if exists (
            select 1 from public.product_views
            where product_id = p_product_id and viewer_id = v_uid
        ) then
            return;  -- deja konte pou moun sa a
        end if;
        insert into public.product_views (product_id, viewer_id)
        values (p_product_id, v_uid);
        update public.products
        set views = coalesce(views, 0) + 1
        where id = p_product_id;
    else
        -- Envite (san kont): dedup fèt sou aparèy la (localStorage aym_viewed).
        -- RPC la pa ka dedup san yon idantite, donk li jis konte +1.
        update public.products
        set views = coalesce(views, 0) + 1
        where id = p_product_id;
    end if;
end;
$$;
revoke all on function public.increment_product_views(uuid) from public;
grant execute on function public.increment_product_views(uuid) to anon, authenticated;

-- Rekalibre products.views sou vrè kantite vizitè INIK (konekte), san konte
-- vizit pwòp vandè a. Sa korije gonfleman ki te fèt pa ansyen RPC la.
update public.products p
set views = coalesce((
    select count(distinct pv.viewer_id)
    from public.product_views pv
    where pv.product_id = p.id
      and pv.viewer_id is not null
      and pv.viewer_id <> p.seller_id
), 0);
