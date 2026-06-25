-- Migration: kòd pwomosyon + refer-a-friend
--
-- promo_codes:        kòd ki bay yon rabè (admin kreye yo, oswa otomatik
--                      lè yon itilizatè jenere kòd refè li)
-- promo_redemptions:  ki itilizatè ki te itilize ki kòd (anpeche reyitilize)
-- profiles.referral_code:   kòd inik chak itilizatè (egz. AYIM-XXXXXX)
-- profiles.referred_by:     UID itilizatè ki te envite l (lè enskripsyon)
--
-- Aplike yon sèl fwa nan Supabase SQL Editor.

create table if not exists public.promo_codes (
    id              uuid primary key default gen_random_uuid(),
    code            text not null unique,
    discount_type   text not null default 'percent'
                    check (discount_type in ('percent', 'fixed')),
    discount_value  numeric not null check (discount_value > 0),
    max_uses        integer,
    used_count      integer not null default 0,
    expires_at      timestamptz,
    scope           text not null default 'all'
                    check (scope in ('all', 'first_order', 'referral')),
    referrer_id     uuid references public.profiles(id) on delete set null,
    active          boolean not null default true,
    created_by      uuid references public.profiles(id) on delete set null,
    created_at      timestamptz not null default now()
);

create index if not exists promo_codes_code_idx on public.promo_codes (code);
create index if not exists promo_codes_referrer_idx on public.promo_codes (referrer_id);

create table if not exists public.promo_redemptions (
    id           uuid primary key default gen_random_uuid(),
    code         text not null references public.promo_codes(code) on delete cascade,
    user_id      uuid not null references auth.users(id) on delete cascade,
    order_id     uuid references public.orders(id) on delete set null,
    discount_amount numeric not null default 0,
    redeemed_at  timestamptz not null default now(),
    unique (code, user_id)
);

create index if not exists promo_redemptions_user_idx on public.promo_redemptions (user_id);

alter table public.profiles
    add column if not exists referral_code text unique;
alter table public.profiles
    add column if not exists referred_by uuid references public.profiles(id) on delete set null;

-- RLS
alter table public.promo_codes enable row level security;
alter table public.promo_redemptions enable row level security;

-- Tout moun ka li (SELECT) kòd aktif yo pou validate yo nan checkout.
drop policy if exists promo_codes_public_select on public.promo_codes;
create policy promo_codes_public_select on public.promo_codes
    for select using (active = true);

-- Sèlman admin ki ka kreye/modifye kòd jeneral; nenpòt itilizatè ka
-- kreye yon kòd 'referral' pou tèt li (referrer_id = li menm).
drop policy if exists promo_codes_admin_write on public.promo_codes;
create policy promo_codes_admin_write on public.promo_codes
    for all using (
        exists (select 1 from public.profiles where id = auth.uid() and role = 'admin')
    ) with check (
        exists (select 1 from public.profiles where id = auth.uid() and role = 'admin')
    );

drop policy if exists promo_codes_referral_self_insert on public.promo_codes;
create policy promo_codes_referral_self_insert on public.promo_codes
    for insert with check (
        scope = 'referral' and referrer_id = auth.uid()
    );

-- Redenmsyon: chak itilizatè wè/kreye sèlman pwòp pa li.
drop policy if exists promo_redemptions_own_select on public.promo_redemptions;
create policy promo_redemptions_own_select on public.promo_redemptions
    for select using (auth.uid() = user_id);

drop policy if exists promo_redemptions_own_insert on public.promo_redemptions;
create policy promo_redemptions_own_insert on public.promo_redemptions
    for insert with check (auth.uid() = user_id);

-- Trigger pou monte `used_count` chak fwa yon redenmsyon kreye —
-- ekri kòm SECURITY DEFINER pou kontoune RLS sou tab promo_codes.
create or replace function public.promo_codes_inc_used()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
    update public.promo_codes
       set used_count = used_count + 1
     where code = new.code;
    return new;
end;
$$;

drop trigger if exists trg_promo_inc_used on public.promo_redemptions;
create trigger trg_promo_inc_used
    after insert on public.promo_redemptions
    for each row execute function public.promo_codes_inc_used();
