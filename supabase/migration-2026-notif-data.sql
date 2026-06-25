-- Migration: ajoute kolòn `data` (jsonb) sou notifications pou kapab
-- pase enfòmasyon kontèks (egz. order_id, kind) bay Edge Functions ki
-- bati imèl ak push, san pase pa parsing tèks.
--
-- Aplike yon sèl fwa nan Supabase SQL Editor.

alter table public.notifications
    add column if not exists data jsonb not null default '{}'::jsonb;
