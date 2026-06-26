-- Migration: product_image_hashes
--
-- Anpeche yon vandè vòl katalòg yon lòt: chak foto pwodwi gen yon
-- SHA-256 hash. Lè yon nouvo vandè eseye pibliye yon foto ki gen
-- menm hash ak yon foto yon lòt vandè deja itilize, sistèm refize.
-- Menm vandè a kapab reyitilize pwòp foto li (egzanp menm pwodwi
-- li relist).
--
-- Aplike yon sèl fwa nan Supabase SQL Editor.

create table if not exists public.product_image_hashes (
    id           uuid primary key default gen_random_uuid(),
    hash         text not null unique,
    product_id   uuid not null references public.products(id) on delete cascade,
    seller_id    uuid not null references public.profiles(id) on delete cascade,
    created_at   timestamptz not null default now()
);

create index if not exists product_image_hashes_seller_idx
    on public.product_image_hashes (seller_id);
create index if not exists product_image_hashes_product_idx
    on public.product_image_hashes (product_id);

alter table public.product_image_hashes enable row level security;

-- Nenpòt itilizatè otantifye dwe ka SELECT pou tcheke doublon —
-- pa danjere paske nou pa ekspoze done sansib.
drop policy if exists product_image_hashes_select on public.product_image_hashes;
create policy product_image_hashes_select on public.product_image_hashes
    for select using (auth.role() = 'authenticated');

-- Vandè a sèlman ka enskri pwòp hash li (kontwòl koresponns ak
-- seller_id li menm).
drop policy if exists product_image_hashes_own_insert on public.product_image_hashes;
create policy product_image_hashes_own_insert on public.product_image_hashes
    for insert with check (auth.uid() = seller_id);

-- Pa gen UPDATE oswa DELETE pa kliyan — sèlman trigger CASCADE
-- (lè pwodwi efase) ka delete.
