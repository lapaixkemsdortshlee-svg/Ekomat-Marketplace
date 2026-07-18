-- Flash deals: okenn mekanis ekspirasyon pa t egziste — lè ends_at pase,
-- feed la kache seksyon an men PWODWI A TE KENBE PRI REDWI A POU TOUT TAN.
-- RPC sa a retounen pri nòmal la epi dezaktive deal ekspire yo. Client la
-- rele l nan boot ak lè yon countdown fini sou yon fich. Idempotente.

create or replace function public.expire_flash_deals()
returns integer
language plpgsql
security definer
set search_path to ''
as $$
declare
    v_count integer := 0;
begin
    -- Retounen pri nòmal — sèlman si pri pwodwi a se TOUJOU pri deal la
    -- (pa kraze yon pri vandè a ta chanje manyèlman apre).
    update public.products pr
       set price = fd.old_price,
           old_price = null
      from public.flash_deals fd
     where fd.product_id = pr.id
       and fd.active = true
       and fd.ends_at <= now()
       and fd.old_price is not null
       and pr.price = fd.price;
    get diagnostics v_count = row_count;

    update public.flash_deals
       set active = false
     where active = true
       and ends_at <= now();

    return v_count;
end;
$$;

revoke execute on function public.expire_flash_deals() from public, anon;
grant execute on function public.expire_flash_deals() to authenticated;
