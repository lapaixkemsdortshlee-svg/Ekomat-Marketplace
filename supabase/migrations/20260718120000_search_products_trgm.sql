-- Rechèch pwodwi sou sèvè: flou (pg_trgm) + endèks + ranking pa pertinans —
-- menm modèl ak search_sellers (SECURITY INVOKER, RLS aplike). Idempotente.

-- Endèks trigram pou ILIKE '%...%' ak word_similarity rete rapid lè katalòg
-- la grandi (san li, chak rechèch = seq scan sou tout tab la).
create index if not exists idx_products_title_trgm
    on public.products using gin (title public.gin_trgm_ops);

create or replace function public.search_products(
    q text default '', zone text default '', cat text default ''
)
returns table (
    id uuid, seller_id uuid, title text, description text, price integer,
    old_price integer, category text, location text, stock integer,
    views integer, images text[], sizes text[], created_at timestamptz,
    seller_name text, seller_verified boolean, seller_rating numeric,
    seller_avatar text
)
language sql
stable
set search_path to ''
as $$
    -- LEFT JOIN espre: RLS profiles mande yon itilizatè konekte — yon vizitè
    -- anonim dwe ka jwenn pwodwi yo kanmenm (non vandè a vin NULL, client la
    -- gen fallback 'Vandè').
    select pr.id, pr.seller_id, pr.title, pr.description, pr.price,
           pr.old_price, pr.category, pr.location, pr.stock, pr.views,
           pr.images, pr.sizes, pr.created_at,
           p.display_name, p.verified_seller, p.rating_avg, p.avatar_url
    from public.products pr
    left join public.profiles p on p.id = pr.seller_id
    where pr.status = 'active'
      and (
          q = ''
          or pr.title ilike ('%' || q || '%')
          or pr.description ilike ('%' || q || '%')
          or pr.category ilike ('%' || q || '%')
          -- Sèy 0.28 kalibre sou vrè done (2026-07-18): 'headfone' 0.46,
          -- 'headpone' 0.58, 'hedfone' 0.29 vs 'Headphone JBL...' — 0.35 te
          -- rate fot òtograf reyèl. Ranking pa similarite kenbe bri a anba.
          or public.word_similarity(q, pr.title) > 0.28
      )
      and (zone = '' or pr.location ilike ('%' || zone || '%'))
      and (cat = '' or pr.category = cat)
    order by
        (case when q <> '' and pr.title ilike (q || '%') then 0 else 1 end),
        (case when q <> '' then public.word_similarity(q, pr.title) else 0 end) desc,
        pr.created_at desc
    limit 40;
$$;
