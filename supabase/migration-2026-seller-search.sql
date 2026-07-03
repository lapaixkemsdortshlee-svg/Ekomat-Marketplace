-- ══════════════════════════════════════════════════════════
--  AyitiMarket — Migration 2026-seller-search — RECHÈCH FLOU BOUTIK/VANDÈ
--  Execute via: Supabase Dashboard > SQL Editor > New Query
--  SAFE to re-run: idempotent.
--
--  Bay yon rechèch boutik/vandè ki tolere fot òtograf (ex. "Bhoutik"
--  jwenn "Boutik"), pa jis yon match pasyèl ILIKE. Sèvi ak pg_trgm
--  (word_similarity) ki deja enstale nan `public`.
--
--  Kliyan an (index.html) rele RPC sa a dabò; si migration sa a poko
--  deplwaye, li retonbe sou yon rechèch ILIKE dirèk (degradasyon gras).
--
--  Sekirite: SECURITY INVOKER — fonksyon an kouri ak wòl moun k ap rele
--  a, donk menm RLS ak yon SELECT dirèk sou `profiles` (okenn eskalasyon
--  privilèj). search_path figen ('') epi tout non kalifye.
-- ══════════════════════════════════════════════════════════

-- 1) pg_trgm (deja enstale; IF NOT EXISTS pou idanpotans) + endèks GIN
--    sou display_name pou akselere match trigram yo.
CREATE EXTENSION IF NOT EXISTS pg_trgm;

CREATE INDEX IF NOT EXISTS idx_profiles_display_name_trgm
    ON public.profiles USING gin (display_name gin_trgm_ops);

-- 2) RPC rechèch vandè: pa non (display_name, flou + pasyèl) ak/oswa
--    pa zòn (location egzak). Retounen sèlman kolòn piblik yo.
CREATE OR REPLACE FUNCTION public.search_sellers(q TEXT DEFAULT '', zone TEXT DEFAULT '')
RETURNS TABLE (
    id UUID,
    display_name TEXT,
    avatar_url TEXT,
    verified_seller BOOLEAN,
    rating_avg NUMERIC,
    review_count INTEGER,
    location TEXT
)
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = ''
AS $$
    SELECT p.id, p.display_name, p.avatar_url, p.verified_seller,
           p.rating_avg, p.review_count, p.location
    FROM public.profiles p
    WHERE p.role = 'seller'
      AND p.status = 'active'
      AND p.display_name IS NOT NULL
      AND (
          q = ''
          OR p.display_name ILIKE ('%' || q || '%')
          OR public.word_similarity(q, p.display_name) > 0.4
      )
      AND (zone = '' OR p.location = zone)
    ORDER BY
        -- Match prefiks an premye (pi presi), apre similarite, apre nòt
        (CASE WHEN q <> '' AND p.display_name ILIKE (q || '%') THEN 0 ELSE 1 END),
        (CASE WHEN q <> '' THEN public.word_similarity(q, p.display_name) ELSE 0 END) DESC,
        p.rating_avg DESC NULLS LAST
    LIMIT 12;
$$;

-- 3) Grants: rechèch la piblik (anon + authenticated), jan rechèch pwodwi
--    a ye. RLS sou `profiles` toujou aplike (SECURITY INVOKER).
REVOKE ALL ON FUNCTION public.search_sellers(TEXT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.search_sellers(TEXT, TEXT) TO anon, authenticated;
