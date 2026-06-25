-- Migration: user_devices — pou stoke FCM token chak itilizatè pou push
-- notifikasyon. Yon itilizatè ka gen plizyè aparèy (telefòn, kompitè).
-- Aplike yon sèl fwa sou Supabase.

create table if not exists public.user_devices (
    id           uuid primary key default gen_random_uuid(),
    user_id      uuid not null references auth.users(id) on delete cascade,
    fcm_token    text not null,
    platform     text not null default 'web',
    created_at   timestamptz not null default now(),
    last_seen_at timestamptz not null default now(),
    unique (fcm_token)
);

create index if not exists user_devices_user_id_idx
    on public.user_devices (user_id);

alter table public.user_devices enable row level security;

-- Chak itilizatè jere sèlman pwòp aparèy li.
drop policy if exists user_devices_own_select on public.user_devices;
create policy user_devices_own_select on public.user_devices
    for select using (auth.uid() = user_id);

drop policy if exists user_devices_own_insert on public.user_devices;
create policy user_devices_own_insert on public.user_devices
    for insert with check (auth.uid() = user_id);

drop policy if exists user_devices_own_update on public.user_devices;
create policy user_devices_own_update on public.user_devices
    for update using (auth.uid() = user_id);

drop policy if exists user_devices_own_delete on public.user_devices;
create policy user_devices_own_delete on public.user_devices
    for delete using (auth.uid() = user_id);
