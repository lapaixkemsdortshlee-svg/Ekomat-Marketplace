-- Migration: tab user_addresses pou pèmèt yon itilizatè anrejistre
-- plizyè adrès (kay, biwo, etc.) ak yon adrès default.
--
-- Aplike yon sèl fwa nan Supabase SQL Editor.

create table if not exists public.user_addresses (
    id            uuid primary key default gen_random_uuid(),
    user_id       uuid not null references auth.users(id) on delete cascade,
    label         text not null default 'Kay',
    address_text  text not null,
    geo_lat       double precision,
    geo_lng       double precision,
    is_default    boolean not null default false,
    created_at    timestamptz not null default now(),
    updated_at    timestamptz not null default now()
);

create index if not exists user_addresses_user_id_idx
    on public.user_addresses (user_id);

-- Yon sèl adrès default pa itilizatè (partial unique index).
create unique index if not exists user_addresses_one_default_per_user
    on public.user_addresses (user_id) where is_default;

alter table public.user_addresses enable row level security;

drop policy if exists user_addresses_own_select on public.user_addresses;
create policy user_addresses_own_select on public.user_addresses
    for select using (auth.uid() = user_id);

drop policy if exists user_addresses_own_insert on public.user_addresses;
create policy user_addresses_own_insert on public.user_addresses
    for insert with check (auth.uid() = user_id);

drop policy if exists user_addresses_own_update on public.user_addresses;
create policy user_addresses_own_update on public.user_addresses
    for update using (auth.uid() = user_id);

drop policy if exists user_addresses_own_delete on public.user_addresses;
create policy user_addresses_own_delete on public.user_addresses
    for delete using (auth.uid() = user_id);
