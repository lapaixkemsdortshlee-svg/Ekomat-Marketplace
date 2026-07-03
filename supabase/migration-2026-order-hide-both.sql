-- ═══════════════════════════════════════════════════════════════
--  Masquer/démasquer une commande — ACHETEUR **et** VENDEUR
-- ───────────────────────────────────────────────────────────────
--  Généralise migration-2026-order-hide.sql / -unhide.sql: chaque
--  partie peut cacher la commande dans SA propre vue. Un flag par rôle
--  (buyer_hidden / seller_hidden). Les RPC détectent le rôle de
--  l'appelant sur la commande et ne touchent que sa colonne. Rien
--  n'est supprimé — l'autre partie et l'audit admin restent intacts.
--
--  Idempotent: exécuter ce fichier suffit (remplace les anciennes RPC),
--  que les migrations précédentes aient été lancées ou non.
-- ═══════════════════════════════════════════════════════════════

ALTER TABLE public.orders
    ADD COLUMN IF NOT EXISTS buyer_hidden  boolean NOT NULL DEFAULT false,
    ADD COLUMN IF NOT EXISTS seller_hidden boolean NOT NULL DEFAULT false;

-- Cacher: met le flag du rôle de l'appelant à true (commandes terminées).
CREATE OR REPLACE FUNCTION public.hide_order(p_order_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    UPDATE public.orders
       SET buyer_hidden  = CASE WHEN buyer_id  = auth.uid() THEN true ELSE buyer_hidden  END,
           seller_hidden = CASE WHEN seller_id = auth.uid() THEN true ELSE seller_hidden END
     WHERE id = p_order_id
       AND (buyer_id = auth.uid() OR seller_id = auth.uid())
       AND status IN ('released', 'completed', 'delivered', 'cancelled', 'refunded');
END;
$$;

-- Démasquer: remet le flag du rôle de l'appelant à false.
CREATE OR REPLACE FUNCTION public.unhide_order(p_order_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    UPDATE public.orders
       SET buyer_hidden  = CASE WHEN buyer_id  = auth.uid() THEN false ELSE buyer_hidden  END,
           seller_hidden = CASE WHEN seller_id = auth.uid() THEN false ELSE seller_hidden END
     WHERE id = p_order_id
       AND (buyer_id = auth.uid() OR seller_id = auth.uid());
END;
$$;

REVOKE EXECUTE ON FUNCTION public.hide_order(uuid)   FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.unhide_order(uuid) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.hide_order(uuid)   TO authenticated;
GRANT  EXECUTE ON FUNCTION public.unhide_order(uuid) TO authenticated;
