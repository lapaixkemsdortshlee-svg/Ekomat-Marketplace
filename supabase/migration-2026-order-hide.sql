-- ═══════════════════════════════════════════════════════════════
--  Suppression d'historique de commande — par COMPTE (cross-device)
-- ───────────────────────────────────────────────────────────────
--  L'acheteur peut retirer une commande TERMINÉE de son historique.
--  Avant: masquage local (localStorage, par appareil). Ici: un flag
--  `buyer_hidden` sur orders + une RPC qui ne laisse l'acheteur cacher
--  QUE ses propres commandes terminées. Le reçu escrow, le côté vendeur
--  et l'audit admin restent intacts (rien n'est supprimé).
--
--  Le client filtre déjà `!o.buyer_hidden` à l'affichage, et garde le
--  masquage localStorage en secours (rétrocompatible avant déploiement).
-- ═══════════════════════════════════════════════════════════════

ALTER TABLE public.orders
    ADD COLUMN IF NOT EXISTS buyer_hidden boolean NOT NULL DEFAULT false;

CREATE OR REPLACE FUNCTION public.hide_order(p_order_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    UPDATE public.orders
       SET buyer_hidden = true
     WHERE id = p_order_id
       AND buyer_id = auth.uid()
       AND status IN ('released', 'completed', 'delivered', 'cancelled', 'refunded');
END;
$$;

-- Moindre privilège: seulement les utilisateurs connectés (garde interne
-- buyer_id = auth.uid()). Pas d'accès anon / PUBLIC.
REVOKE EXECUTE ON FUNCTION public.hide_order(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.hide_order(uuid) TO authenticated;
