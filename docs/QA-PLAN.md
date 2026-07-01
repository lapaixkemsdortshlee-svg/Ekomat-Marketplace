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

Priorité aux flux à argent :
- [ ] Checkout / escrow
- [ ] Application d'un code promo
- [ ] Soumission de dispute
- [ ] Gating de la vérification vendeur (téléphone SMS)
- [ ] Re-run axe-core sur les nouveaux écrans

## P2 — Durcissement

- [ ] Audit de la machine à états escrow : transitions illégales bloquées côté RPC
- [ ] Idempotence des paiements / release
- [ ] RLS sur les nouvelles tables (`addresses`, `promo`, `image-hashes`, `fcm`)

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
- [ ] Audit SEO technique (meta, OG, sitemap, perf mobile)
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
