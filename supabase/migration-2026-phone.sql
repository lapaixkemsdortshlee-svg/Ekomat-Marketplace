-- Migration: ajoute kolòn pou make telefòn yon itilizatè verifye via OTP
-- SMS. Aplike yon sèl fwa nan Supabase SQL Editor.
--
-- Yo non-bloke pou ranje ki egziste deja (default = false).

alter table public.profiles
    add column if not exists phone_verified boolean not null default false;

alter table public.profiles
    add column if not exists phone_verified_at timestamptz;
