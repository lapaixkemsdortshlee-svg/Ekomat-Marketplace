# Plan & Objectifs — AyitiMarket (à partir du 1ᵉʳ juillet 2026)

> **Contexte** : 29 commits de fonctionnalités livrés en 6 jours (24–30 juin). On passe
> de la livraison rapide à la **fiabilisation et la croissance**.
>
> **Note paiements** : l'intégration MonCash réelle (Digicel) est **bloquée** faute de
> credentials marchands. On garde le stub (`moncashSendPayout` / `moncashVerifyTransaction`)
> et on le sort du chemin critique en attendant.

## 🎯 Les trois objectifs (/goal — autonomie déléguée)

| # | Objectif | Résultat visé |
|---|----------|---------------|
| **A** | QA & Durcissement | Chaque flux critique testé end-to-end + couvert par un smoke test qui passe en CI |
| **B** | Croissance / Acquisition | Premiers utilisateurs réels : onboarding Kreyòl, SEO, parrainage activé, ads |
| **C** | Observabilité escrow | Machine à états financière monitorée, réconciliée, et alertée avant tout incident |

---

# 🅰️ Objectif A — QA & Durcissement

## P0 — QA end-to-end

> Tester sur le preview Vercel (header de bypass de protection requis).

> **Scaffold E2E livré** : `playwright.e2e.config.mjs` + `tests/e2e/auth.spec.mjs` (test de login acheteur qui tourne + squelettes `fixme` pour escrow/promo/litige) + workflow `.github/workflows/e2e.yml` (déclenché à la main). Isolé de la suite smoke (via `testIgnore`). **Pour activer** : créer un compte de test + poser les GitHub Secrets `AYM_E2E_URL`, `AYM_E2E_EMAIL`, `AYM_E2E_PASSWORD` (et `AYM_BYPASS_TOKEN` si preview privé), puis lancer le workflow. Note : la QA live n'a pas pu tourner depuis l'environnement agent (HTTP 429 rate-limit de Vercel).

### Flux escrow complet (cœur du business)
- [ ] Commande → paiement (stub) → vendeur expédie → live tracking → livraison → release fonds
- [ ] Auto-release à 168h (simuler / forcer la fenêtre)
- [ ] Annulation / remboursement à chaque étape

### Litiges & anti-fraude
- [ ] Dispute acheteur avec motifs → audit trail correct
- [ ] Signalement de disputes répétées → flag déclenché
- [ ] Admin approve / reject d'un vendeur
- [ ] Déduplication photo (réupload de la même image → bloqué)

### Notifications & emails
- [ ] Push FCM réellement reçu (vendeur + acheteur, par rôle)
- [ ] Emails transactionnels liés aux commandes envoyés au bon moment

### Features acheteur / vendeur
- [ ] Codes promo (valide / expiré / cumul) + parrainage (génération + crédit)
- [ ] Adresses multiples (ajout / sélection / suppression soft-delete)
- [ ] Filtres de feed avancés
- [ ] Analytics vendeur dans Boutik Mwen
- [ ] Téléphone SMS-vérifié obligatoire avant la vérification vendeur

## P1 — Smoke tests à ajouter

- [x] Couche de tests UI sans backend — `tests/ui.spec.mjs` : intégrité meta/PWA, manifest + icônes, présence du formulaire d'auth, logique `toggleAuthMode()` (login ↔ signup), intégrité des assets/entrées. **11 tests passent** (Chromium).

- [x] Flux escrow complet (E2E API) — `tests/e2e/escrow-api.spec.mjs` : cycle awaiting_payment → … → released avec les 3 rôles, **validé live en prod** + idempotence + verrou état final + nettoyage.
- [x] Soumission de dispute — couverte par le même test API (buyer → disputed, admin → refunded), validée live.
- [x] axe-core sur les écrans authentifiés — `tests/e2e/auth.spec.mjs` (feed/order/profile/pub), exécuté live (0 violation après fix `alt` sur l'avatar profil).

Reste :
- [ ] Application d'un code promo (UI) — attend le déploiement de `migration-2026-promo-hardening.sql` (RPC `validate_promo_code`)
- [ ] Gating de la vérification vendeur (téléphone SMS)

## P2 — Durcissement

- [x] Audit de la machine à états escrow : transitions illégales bloquées côté RPC — audit de `advance_order_status()` + verrou des états finaux (`completed`/`refunded`/`cancelled`). Voir `supabase/migration-2026-escrow-guards.sql`.
- [x] Idempotence des paiements / release — garde `from == to` (no-op) : un double-clic « Lage lajan » ne re-libère plus ni ne duplique l'audit. Validé sur Postgres 16 (6/6 tests).
- [x] RLS sur les nouvelles tables — vérifié via Supabase `list_tables` : **RLS activé sur les 22 tables** de `public`.
- [x] Durcissement des fonctions (advisors sécurité) — `search_path` figé sur toutes les fonctions `SECURITY DEFINER`, et RPC escrow privilégiées verrouillées (`escrow_dispatch_alerts` cron-only ; `escrow_overview`/`escrow_attention_orders`/`error_overview` = authenticated + garde `is_admin`). Voir `supabase/migration-2026-harden-functions.sql`. Validé sur Postgres 16.
- [x] Fuite d'énumération des codes promo (trouvée en QA live) — la policy `promo_codes_public_select` exposait tous les codes actifs. Corrigé : SELECT public limité aux codes `referral`, + RPC `validate_promo_code()` (SECURITY DEFINER) pour valider un code au checkout sans exposer la table ; client branché dessus. Voir `supabase/migration-2026-promo-hardening.sql`. Validé sur Postgres 16 (8 scénarios).

> **Reste hors-code (dashboard Supabase)** : activer « Leaked password protection » (Auth) ; extensions `pg_trgm`/`pg_net` dans `public` laissées telles quelles (déplacement risqué). **Routine** : relancer `get_advisors` (security + performance) après chaque migration.

## P3 — Prépa MonCash (reporté, débloqué quand Digicel arrive)

- [ ] Ajouter les `env vars` Digicel dans `.env.example`
- [ ] Structure sandbox prête pour que le branchement réel soit trivial le jour J
- [ ] Documenter le contrat des deux fonctions (`moncashSendPayout`, `moncashVerifyTransaction`)

---

# 🅱️ Objectif B — Croissance / Acquisition

> Le produit est riche ; il faut maintenant des utilisateurs. Toute la copie reste en **Kreyòl**.
> Skills mobilisables : `onboarding`, `cro`, `seo-audit`, `ai-seo`, `referrals`, `ads`,
> `ad-creative`, `copywriting`, `social`, `analytics`. Connecteurs : Windsor.ai (Meta/Google Ads),
> Magic (UI), Supabase (cohortes/funnel).

### Activation & onboarding (Kreyòl)
- [ ] Auditer le first-run / `onboarding.html` → réduire le time-to-value
- [ ] Définir le « aha moment » (1ère commande ? 1ère mise en vente ?) et le mesurer
- [ ] Empty states qui guident l'acheteur et le vendeur

### Parrainage (déjà construit → à pousser)
- [ ] Rendre l'invitation visible au bon moment (post-achat, post-vente)
- [ ] Vérifier la boucle crédit parrain/filleul de bout en bout
- [ ] Message de partage en Kreyòl optimisé (WhatsApp first)

### SEO & visibilité
- [~] Audit SEO technique — **Open Graph / Twitter + apple-touch-icon + canonical ajoutés** (aperçu de partage WhatsApp/Facebook) ; test dans `tests/ui.spec.mjs`. Reste : sitemap, image OG dédiée 1200×630, perf mobile.
- [ ] AI-SEO : être cité par les assistants (llms.txt, contenu structuré)
- [ ] Pages d'atterrissage par catégorie / ville

### Acquisition payante (quand prêt)
- [ ] Stratégie ads Meta/Google ciblée diaspora + Haïti
- [ ] Variantes de créatives en Kreyòl
- [ ] Tracking conversions branché (analytics) avant de dépenser

### Mesure
- [ ] Funnel AARRR de base instrumenté (acquisition → activation → rétention → referral)

---

# 🅲️ Objectif C — Observabilité escrow

> Sécuriser la machine à états financière : rien ne doit bouger sans qu'on le voie.
> Outils : Supabase MCP (`get_logs`, `get_advisors`, requêtes), edge functions, error tracking.

### Monitoring des paiements
- [x] Vue admin de l'état des commandes/escrow en temps réel (par statut) — `escrow_overview()` RPC + carte « Sante Escrow »
- [x] Suivi des montants bloqués vs libérés vs remboursés — snapshot `money` dans `escrow_overview()`

### Réconciliation
- [x] Réconciliation paiements ↔ commandes (détecter les écarts) — compteurs d'anomalies (`net_mismatch`, `missing_ref`, `bad_amount`, `released_no_releaser`)
- [x] Détecter les commandes « coincées » dans un état (ni release ni refund) — `escrow_attention_orders()`

### Alertes
- [x] Alerte avant l'auto-release 168h (fenêtre de revue côté admin) — `release_due` / `release_soon_12h`
- [x] Alerting temps réel push + email (via `notifications`) — `escrow_dispatch_alerts()` planifié par pg_cron, avec dédup (`escrow_alert_log`). Couvre `release_due`, `release_soon_12h`, `verify_overdue_24h`, `dispute_stale_48h`.

### Error tracking
- [x] Capturer les erreurs front (single-file app) et edge functions — table `error_logs` + `log_error()`, handlers globaux `error`/`unhandledrejection` côté front, capture des crashes dans `send-push` / `send-email`
- [x] Surveiller les advisors Supabase (sécurité / perf) régulièrement — routine documentée ci-dessous ; visibilité in-app via la carte « Sante Sistèm » (`error_overview()`)

**Routine advisors Supabase** (à faire ~1×/semaine) : via le Supabase MCP, lancer `get_advisors` (types `security` puis `performance`) et traiter les alertes ; en complément, `get_logs` pour les erreurs des edge functions. Objectif : zéro advisor de sécurité non traité.

> **Livré (itération 1)** : `supabase/migration-2026-observability.sql` (RPC `escrow_overview` + `escrow_attention_orders`, admin-only, lecture seule) + carte « Sante Escrow » dans le panneau admin.
>
> **Livré (itération 2)** : `supabase/migration-2026-escrow-alerts.sql` — alerting temps réel (push + email) via le pipeline `notifications` existant, dispatché par pg_cron toutes les heures, avec dédup par `(order_id, reason)`. Validé en local sur Postgres 16 (dispatch + dédup).
>
> **Livré (itération 3)** : `supabase/migration-2026-error-logs.sql` — error tracking unifié (front + edge) : table `error_logs`, `log_error()` (anon + auth), `error_overview()` (admin). Handlers globaux côté front (throttlés) et capture des crashes dans les edge functions. Carte « Sante Sistèm » dans l'onglet Verifikasyon. Validé en local sur Postgres 16.
>
> **Objectif C : clôturé.** ✅
>
> **À déployer** : exécuter les trois migrations dans Supabase (SQL Editor). Pour l'alerting, activer l'extension **pg_cron** (Database → Extensions). Pour capturer les crashes edge, redéployer `send-push` et `send-email`.
