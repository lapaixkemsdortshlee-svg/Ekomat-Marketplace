-- ══════════════════════════════════════════════════════════
--  AyitiMarket — Migration 2026-error-logs — ERROR TRACKING
--  Execute via: Supabase Dashboard > SQL Editor > New Query
--  SAFE to re-run: every object is idempotent.
--
--  Closes Objective C (escrow observability) with error tracking:
--  a single place where front-end (single-file app) and edge-function
--  errors land, so the admin can see what's breaking.
--
--  Objects:
--    • error_logs        — the store (source, user, message, context).
--    • log_error()       — controlled insert, callable by anyone (even
--                          anon) so an error is never lost. SECURITY
--                          DEFINER, caps message length.
--    • error_overview()  — admin-only dashboard: 24h / 7d counts,
--                          breakdown by source, 10 most recent.
-- ══════════════════════════════════════════════════════════

-- ──────────────────────────────────────────────────────────
-- 1) STORE
-- ──────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.error_logs (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    source     TEXT NOT NULL DEFAULT 'web' CHECK (source IN ('web','edge','server')),
    user_id    UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    message    TEXT NOT NULL,
    context    JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_error_logs_created        ON public.error_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_error_logs_source_created ON public.error_logs(source, created_at DESC);

ALTER TABLE public.error_logs ENABLE ROW LEVEL SECURITY;

-- Admins read. No INSERT policy on purpose: writes go through log_error()
-- (SECURITY DEFINER) or the service role (edge functions), never raw client
-- inserts.
DROP POLICY IF EXISTS "error_logs_admin_read" ON public.error_logs;
CREATE POLICY "error_logs_admin_read" ON public.error_logs
    FOR SELECT USING (
        EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND is_admin = TRUE)
    );

-- ──────────────────────────────────────────────────────────
-- 2) log_error() — the write path for clients
-- ──────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.log_error(
    p_source  TEXT,
    p_message TEXT,
    p_context JSONB DEFAULT '{}'::jsonb
) RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
    IF p_message IS NULL OR length(trim(p_message)) = 0 THEN
        RETURN;
    END IF;
    INSERT INTO public.error_logs(source, user_id, message, context)
    VALUES (
        CASE WHEN p_source IN ('web','edge','server') THEN p_source ELSE 'web' END,
        auth.uid(),
        left(p_message, 1000),
        COALESCE(p_context, '{}'::jsonb)
    );
END;
$$;

-- Anyone can report an error (even before login), so nothing is lost.
GRANT EXECUTE ON FUNCTION public.log_error(TEXT, TEXT, JSONB) TO anon, authenticated;

-- ──────────────────────────────────────────────────────────
-- 3) error_overview() — admin dashboard
-- ──────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.error_overview()
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
    v_is_admin BOOLEAN;
    v_result   JSONB;
BEGIN
    SELECT is_admin INTO v_is_admin FROM public.profiles WHERE id = auth.uid();
    IF v_is_admin IS NOT TRUE THEN
        RAISE EXCEPTION 'error_overview: admin only';
    END IF;

    SELECT jsonb_build_object(
        'generated_at', NOW(),
        'last_24h', (SELECT COUNT(*) FROM public.error_logs WHERE created_at > NOW() - INTERVAL '24 hours'),
        'last_7d',  (SELECT COUNT(*) FROM public.error_logs WHERE created_at > NOW() - INTERVAL '7 days'),
        'by_source', (
            SELECT COALESCE(jsonb_object_agg(source, c), '{}'::jsonb)
            FROM (
                SELECT source, COUNT(*) AS c
                FROM public.error_logs
                WHERE created_at > NOW() - INTERVAL '7 days'
                GROUP BY source
            ) s
        ),
        'recent', (
            SELECT COALESCE(jsonb_agg(r ORDER BY (r->>'created_at') DESC), '[]'::jsonb)
            FROM (
                SELECT jsonb_build_object(
                    'message', left(message, 160),
                    'source', source,
                    'created_at', created_at
                ) AS r
                FROM public.error_logs
                ORDER BY created_at DESC
                LIMIT 10
            ) t
        )
    ) INTO v_result;

    RETURN v_result;
END;
$$;

REVOKE ALL ON FUNCTION public.error_overview() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.error_overview() TO authenticated;

-- ══════════════════════════════════════════════════════════
--  DONE — quick checks:
--    SELECT public.log_error('web', 'test error', '{"where":"manual"}');
--    SELECT public.error_overview();          -- as an admin
--    SELECT * FROM public.error_logs ORDER BY created_at DESC LIMIT 5;
-- ══════════════════════════════════════════════════════════
