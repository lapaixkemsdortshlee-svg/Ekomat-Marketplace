-- ══════════════════════════════════════════════════════════
--  AyitiMarket — Migration 2026-seller-search-cat — FILTRE KATEGORI + ZÒN ILIKE
--  Execute via: Supabase Dashboard > SQL Editor > New Query
--  SAFE to re-run: idempotent. Ranplase search_sellers de
--  migration-2026-seller-search.sql (li endepandan: li ka woule pou kont li).
--
--  Amelyorasyon parapò a vèsyon anvan an:
--   1) Ajoute yon paramèt `cat`: filtre vandè ki gen omwen yon pwodwi aktif
--      nan kategori sa a. Kategori yon vandè DEDWI de pwodwi li yo (kolòn
--      `categories` sou profiles pa janm te egziste — se poutèt sa nou dedwi).
--   2) Zòn nan matche an SOUS-CHèN (ILIKE) olye egzat: vre `location` yo se
--      tèks lib (ex. "Village Eden, Commune de Delmas"), donk `= 'Delmas'`
--      te rate yo. Kounye a "Delmas" jwenn yo.
--   3) Retounen `categories` (dedwi) pou kliyan an ka montre sa boutik la vann.
-- ══════════════════════════════════════════════════════════

-- pg_trgm + endèks GIN (idanpotan; nesesè si migration anvan an poko woule)
CREATE EXTENSION IF NOT EXISTS pg_trgm;

CREATE INDEX IF NOT EXISTS idx_profiles_display_name_trgm
    ON public.profiles USING gin (display_name gin_trgm_ops);

-- Retire ansyen siyati 2-paramèt la pou evite anbigwite RPC
DROP FUNCTION IF EXISTS public.search_sellers(TEXT, TEXT);

CREATE OR REPLACE FUNCTION public.search_sellers(q TEXT DEFAULT '', zone TEXT DEFAULT '', cat TEXT DEFAULT '')
RETURNS TABLE (
    id UUID,
    display_name TEXT,
    avatar_url TEXT,
    verified_seller BOOLEAN,
    rating_avg NUMERIC,
    review_count INTEGER,
    location TEXT,
    categories TEXT[]
)
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = ''
AS $$
    SELECT p.id, p.display_name, p.avatar_url, p.verified_seller,
           p.rating_avg, p.review_count, p.location,
           (SELECT array_agg(DISTINCT pr.category)
              FROM public.products pr
             WHERE pr.seller_id = p.id AND pr.status = 'active') AS categories
    FROM public.profiles p
    WHERE p.role = 'seller'
      AND p.status = 'active'
      AND p.display_name IS NOT NULL
      AND (
          q = ''
          OR p.display_name ILIKE ('%' || q || '%')
          OR public.word_similarity(q, p.display_name) > 0.4
      )
      AND (zone = '' OR p.location ILIKE ('%' || zone || '%'))
      AND (
          cat = ''
          OR EXISTS (
              SELECT 1 FROM public.products pr2
              WHERE pr2.seller_id = p.id AND pr2.status = 'active' AND pr2.category = cat
          )
      )
    ORDER BY
        (CASE WHEN q <> '' AND p.display_name ILIKE (q || '%') THEN 0 ELSE 1 END),
        (CASE WHEN q <> '' THEN public.word_similarity(q, p.display_name) ELSE 0 END) DESC,
        p.rating_avg DESC NULLS LAST
    LIMIT 12;
$$;

REVOKE ALL ON FUNCTION public.search_sellers(TEXT, TEXT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.search_sellers(TEXT, TEXT, TEXT) TO anon, authenticated;
