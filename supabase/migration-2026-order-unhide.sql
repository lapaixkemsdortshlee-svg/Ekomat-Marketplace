-- ═══════════════════════════════════════════════════════════════
--  Démasquer une commande (par compte)
-- ───────────────────────────────────────────────────────────────
--  Complément de migration-2026-order-hide.sql: l'acheteur peut
--  RÉ-AFFICHER une commande qu'il avait masquée (buyer_hidden=false).
--  Même garde: seulement ses propres commandes. Le démasquage côté
--  localStorage marche déjà sans migration; cette RPC assure la
--  synchro cross-device.
-- ═══════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.unhide_order(p_order_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    UPDATE public.orders
       SET buyer_hidden = false
     WHERE id = p_order_id
       AND buyer_id = auth.uid();
END;
$$;

REVOKE EXECUTE ON FUNCTION public.unhide_order(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.unhide_order(uuid) TO authenticated;
