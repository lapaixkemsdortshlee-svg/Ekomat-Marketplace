-- ═══════════════════════════════════════════════════════════════
--  Limite kòd parennaj yo a 3 moun
-- ───────────────────────────────────────────────────────────────
--  Chak itilizatè gen yon sèl kòd refè pèsonèl. Kounye a li ka sèvi
--  pou 3 moun sèlman (max 3 redemptions). Nouvo kòd yo deja kreye ak
--  max_uses = 3 nan kliyan an (myReferralCode). Migrasyon sa a ranpli
--  ansyen kòd parennaj ki pa t gen okenn limit (max_uses IS NULL).
--
--  Kontaj la fèt otomatikman: trigger promo_codes_inc_used ogmante
--  used_count chak redemption, epi validate_promo_code() refize deja
--  lè used_count >= max_uses. Kidonk pa gen lòt chanjman ki nesesè.
-- ═══════════════════════════════════════════════════════════════

UPDATE public.promo_codes
   SET max_uses = 3
 WHERE scope = 'referral'
   AND max_uses IS NULL;
