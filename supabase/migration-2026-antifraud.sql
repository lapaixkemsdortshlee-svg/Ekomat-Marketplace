-- Migration: anti-fraud Phase 1
--
-- Ajoute eta `pending_review` nan tab `products` pou pèmèt:
--   1) Premye 3 pwodwi yon nouvo vandè pase nan revizyon admin
--   2) Achtè pa wè pwodwi yo nan feed la jiskaske admin apwouve
--   3) Vandè ka swiv eta yo nan Boutik Mwen
--
-- Aplike yon sèl fwa nan Supabase SQL Editor.

alter table public.products
    drop constraint if exists products_status_check;

alter table public.products
    add constraint products_status_check
    check (status in ('active', 'draft', 'sold', 'archived', 'pending_review'));

-- Endèks pou administratè ka jwenn pwodwi an atant rapidman
create index if not exists products_pending_review_idx
    on public.products (status, created_at)
    where status = 'pending_review';
