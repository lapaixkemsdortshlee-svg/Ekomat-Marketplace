-- ══════════════════════════════════════════════════════════
--  AyitiMarket — Migration 2026-referral-rewards-policy — INFO advisor
--  Execute via: Supabase Dashboard > SQL Editor > New Query
--  SAFE to re-run: idempotent.
--
--  Advisor `rls_enabled_no_policy` (INFO) on public.referral_rewards:
--  RLS is on but no policy exists (deny-all for anon/authenticated). That
--  deny-all is intentional (the table is written only by the SECURITY
--  DEFINER trigger grant_referral_reward). We add an explicit ADMIN-ONLY
--  SELECT policy so admins can audit granted rewards, which also resolves
--  the advisor. Writes remain closed to clients (trigger/service only).
-- ══════════════════════════════════════════════════════════

ALTER TABLE public.referral_rewards ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS referral_rewards_admin_select ON public.referral_rewards;
CREATE POLICY referral_rewards_admin_select ON public.referral_rewards
    FOR SELECT
    USING ((SELECT is_admin FROM public.profiles WHERE id = auth.uid()) IS TRUE);

-- ══════════════════════════════════════════════════════════
--  DONE — verify: as a non-admin, this returns 0 rows; as admin, all rows.
--    SELECT count(*) FROM public.referral_rewards;
-- ══════════════════════════════════════════════════════════
