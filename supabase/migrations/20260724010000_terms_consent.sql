-- Konsantman kondisyon itilizasyon + politik konfidansyalite (pa-kont, vèsyone).
-- Idempotan, pa destriktif (kolòn nullable). Chak kont anrejistre ki vèsyon
-- li aksepte ak kilè, konsa lè kondisyon yo chanje (vèsyon monte) app la ka
-- re-mande. Kliyan an ekri sou pwòp ranje pa l (RLS profiles update = own).

alter table public.profiles
    add column if not exists terms_version integer,
    add column if not exists terms_accepted_at timestamptz;

comment on column public.profiles.terms_version is
    'Vèsyon Kondisyon/Konfidansyalite itilizatè a aksepte (NULL = poko aksepte vèsyon aktyèl la).';
comment on column public.profiles.terms_accepted_at is
    'Lè itilizatè a te aksepte dènye vèsyon an.';
