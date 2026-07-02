-- ══════════════════════════════════════════════════════════
--  AyitiMarket — Migration 2026-referral-rewards — CLOSE THE LOOP
--  Execute via: Supabase Dashboard > SQL Editor > New Query
--  SAFE to re-run: idempotent.
--
--  Context (Objectif B — Croissance): the referral system already gives
--  the INVITEE ("filleul") 10% off their first order via a referral promo
--  code, and stores `profiles.referred_by` at signup. But the REFERRER
--  ("parrain") was never rewarded — the loop was open, so there was no
--  real incentive to invite.
--
--  This migration closes the loop: when a referred buyer's order reaches a
--  fulfilled state (funds released / completed), the referrer automatically
--  receives a one-time 100 HTG reward promo code + an in-app notification.
--
--  Design:
--   * A dedup table `referral_rewards` — UNIQUE(referred_id) guarantees ONE
--     reward per invitee (granted on their first qualifying order).
--   * An AFTER UPDATE trigger on `orders` that fires when status enters a
--     fulfilled state. SECURITY DEFINER + search_path='' so it runs under
--     the advance_order_status() RPC without extra RLS grants.
--   * The reward code has scope 'referral_reward' (NOT 'referral'), so it is
--     NOT exposed by the public referral SELECT policy and is NOT blocked by
--     validate_promo_code()'s referral self-use guard — the parrain can use
--     their own reward. max_uses = 1 caps abuse.
-- ══════════════════════════════════════════════════════════

-- ──────────────────────────────────────────────────────────
-- 1) Dedup / audit table for granted rewards.
-- ──────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.referral_rewards (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    referrer_id  UUID NOT NULL,
    referred_id  UUID NOT NULL,
    order_id     UUID,
    reward_code  TEXT NOT NULL,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (referred_id)
);
ALTER TABLE public.referral_rewards ENABLE ROW LEVEL SECURITY;

-- No public policies: this table is written only by the SECURITY DEFINER
-- trigger and read only by admins / service role. (RLS on + no policy =
-- no access for anon/authenticated, which is what we want.)

-- ──────────────────────────────────────────────────────────
-- 2) Trigger function: grant the referrer a reward once the invitee's
--    order is fulfilled.
-- ──────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.grant_referral_reward()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
    v_ref  UUID;
    v_code TEXT;
BEGIN
    -- Only when entering a fulfilled state (not on every update).
    IF NEW.status NOT IN ('released', 'completed') THEN
        RETURN NEW;
    END IF;
    IF OLD.status IS NOT DISTINCT FROM NEW.status
       OR OLD.status IN ('released', 'completed') THEN
        RETURN NEW;
    END IF;

    -- Who referred this buyer?
    SELECT referred_by INTO v_ref FROM public.profiles WHERE id = NEW.buyer_id;
    IF v_ref IS NULL OR v_ref = NEW.buyer_id THEN
        RETURN NEW;
    END IF;

    -- One reward per invitee (first qualifying order only). The UNIQUE
    -- constraint is the real guard; this is a fast pre-check.
    IF EXISTS (SELECT 1 FROM public.referral_rewards WHERE referred_id = NEW.buyer_id) THEN
        RETURN NEW;
    END IF;

    v_code := 'AYRW-' || upper(substr(md5(random()::text || NEW.id::text), 1, 6));

    -- Create the reward promo code owned by the referrer.
    INSERT INTO public.promo_codes (code, discount_type, discount_value, scope, referrer_id, active, max_uses)
        VALUES (v_code, 'fixed', 100, 'referral_reward', v_ref, true, 1);

    -- Record the grant (dedup). If a concurrent order raced us, the UNIQUE
    -- constraint aborts only this INSERT — swallow it so the order update
    -- itself never fails because of the reward.
    BEGIN
        INSERT INTO public.referral_rewards (referrer_id, referred_id, order_id, reward_code)
            VALUES (v_ref, NEW.buyer_id, NEW.id, v_code);
    EXCEPTION WHEN unique_violation THEN
        -- Already granted for this invitee: undo the extra promo code.
        DELETE FROM public.promo_codes WHERE code = v_code;
        RETURN NEW;
    END;

    -- Notify the referrer via the existing notifications pipeline
    -- (drives in-app + push/email fan-out).
    INSERT INTO public.notifications (user_id, type, icon, title, body, color, data)
        VALUES (v_ref, 'referral', 'card_giftcard',
            'Ou touche yon rekonpans! 🎁',
            'Yon moun ou envite fè premye kòmand li. Kòd ' || v_code
                || ' ba ou 100 HTG rabè sou pwochen kòmand ou.',
            '#97422b',
            jsonb_build_object('code', v_code, 'kind', 'referral_reward'));

    RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.grant_referral_reward() FROM PUBLIC;

-- ──────────────────────────────────────────────────────────
-- 3) Wire the trigger (drop-and-create so re-runs stay clean).
-- ──────────────────────────────────────────────────────────
DROP TRIGGER IF EXISTS trg_grant_referral_reward ON public.orders;
CREATE TRIGGER trg_grant_referral_reward
    AFTER UPDATE OF status ON public.orders
    FOR EACH ROW
    EXECUTE FUNCTION public.grant_referral_reward();

-- ══════════════════════════════════════════════════════════
--  DONE — checks:
--    -- simulate: set an order (whose buyer has referred_by) to released
--    UPDATE public.orders SET status = 'released' WHERE id = '<order_id>';
--    -- the referrer should now have a fresh reward code + notification:
--    SELECT * FROM public.referral_rewards ORDER BY created_at DESC LIMIT 5;
--    SELECT code, scope, discount_value, max_uses FROM public.promo_codes
--        WHERE scope = 'referral_reward' ORDER BY id DESC LIMIT 5;
-- ══════════════════════════════════════════════════════════
