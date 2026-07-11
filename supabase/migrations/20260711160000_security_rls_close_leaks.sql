-- Ekomat — Migration sécurité : ferme 2 fuites d'accès RLS
-- Validé par Thrasher le 2026-07-11 (« fonce sur les deux »).
-- Trouvées en analysant les multiple_permissive_policies des advisors.
-- Validée en rejouant les DROP sur la prod en transaction rollback : après coup,
-- profiles garde profiles_select_authenticated (SELECT connectés) et reviews garde
-- reviews_insert_buyer (INSERT réservé aux acheteurs). Aucune lecture légitime cassée.

begin;

-- Fuite 1 (PII) : profiles_select_public avait USING (true) pour le rôle public,
-- donc N'IMPORTE QUI, même non connecté, pouvait lire toutes les colonnes de profiles
-- (moncash_number, phone, location...). On la supprime ; profiles_select_authenticated
-- (auth.uid() IS NOT NULL) couvre la lecture pour les utilisateurs connectés.
drop policy if exists profiles_select_public on public.profiles;

-- Fuite 2 (intégrité des avis) : reviews_insert_own (with check auth.uid() = reviewer_id)
-- coexistait avec reviews_insert_buyer ; les policies permissives étant en OU, tout compte
-- connecté pouvait poster un avis sans avoir acheté, contournant la vérif de commande livrée.
-- On la supprime ; reviews_insert_buyer (exige une commande otp_confirmed/released/completed/
-- delivered du bon acheteur) reste la seule voie d'insertion.
drop policy if exists reviews_insert_own on public.reviews;

commit;
