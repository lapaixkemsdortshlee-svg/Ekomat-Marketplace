# Workspace History

> Journal chronologique de toutes les sessions et décisions importantes.
> Le plus récent en haut. Mis à jour automatiquement par Alita.
>
> **Comment ça marche :** Après une session importante, ou quand je raconte un changement significatif, Alita ajoute une entrée ici. Je n'ai pas à écrire ce fichier manuellement.

---

## 2026-07-01 : Correctif sécurité codes promo (finding QA live)

- Correctif du finding #3 (énumération des codes promo). Avant : `promo_codes_public_select` = `USING (active=true)` → n'importe qui listait tous les codes actifs (dont les codes admin).
- `supabase/migration-2026-promo-hardening.sql` : SELECT public restreint aux codes `referral` (parrainage intact) + nouvelle RPC `validate_promo_code()` (SECURITY DEFINER, search_path figé) qui valide un code au checkout sans exposer la table.
- Client (`index.html`) : `validatePromoCode` appelle la RPC (fini le SELECT direct) ; `_calcPromoDiscount` retiré (logique déplacée en SQL).
- Validé sur Postgres 16 (8 scénarios : %, plafond fixe, expiré, épuisé, self-referral, déjà utilisé, inexistant, non connecté).
- **À déployer** : exécuter la migration dans Supabase (le client mergé attend la RPC — déployer la migration en même temps).
- **Comptes admin/vendeur** : les nouveaux mots de passe échouent aussi ("Invalid login credentials") alors que les comptes existent → probablement comptes créés via Google (pas de mot de passe email). Piste : vérifier le provider dans Auth → Users, ou définir un mot de passe / utiliser service_role.

---

## 2026-07-01 : QA live via API (P0) + findings prod

- **Découverte infra clé** : le navigateur Chromium du sandbox NE PEUT PAS joindre Supabase (le proxy egress ferme la connexion TLS ; `curl` marche, pas le navigateur). Donc : la QA **UI/navigateur** doit tourner en **CI** (egress propre) ; la QA **API/backend** se fait ici via `curl`. Le 429 Vercel n'était qu'un symptôme secondaire.
- **Comptes** : acheteur OK ; **admin et vendeur → "Invalid login credentials"** (à revérifier par Thrasher). Donc les flux admin/vendeur (release escrow, ready_for_pickup) sont bloqués.
- **Validé en prod (compte acheteur, via API)** :
  - RLS commandes : l'acheteur ne voit que les siennes ; ne peut pas lire celles des autres.
  - Durcissement PR #92 déployé : `escrow_dispatch_alerts` → 403 permission denied pour un acheteur ; `escrow_overview`/`escrow_attention_orders` → "admin only".
- **Findings à traiter** :
  1. `error_logs` absente en prod → migration `migration-2026-error-logs.sql` (PR #91) pas encore exécutée.
  2. 2 commandes livrées (`otp_confirmed`) jamais `released` depuis avril/mai → vendeur non payé (cas "release_due").
  3. Les codes promo sont énumérables par un acheteur (RLS à resserrer, fuite possible).
- Helper `login()` du scaffold E2E corrigé d'après le live (skip onboarding via `aym_onboarded`, filtre bruit CDN, signal de succès = `#emailAuthForm` caché).

---

## 2026-07-01 : Objectif A — scaffold E2E CI (P0)

- P0 (QA end-to-end sur le vrai déploiement) ne peut pas tourner depuis l'environnement agent : Vercel renvoie HTTP 429 (rate-limit) + besoin d'un compte de test et d'un header de bypass.
- Choix (validé) : scaffold E2E qui tourne dans GitHub Actions avec les identifiants en secrets.
- Livré : `playwright.e2e.config.mjs` (URL déployée + bypass header optionnel), `tests/e2e/auth.spec.mjs` (login acheteur réel + squelettes `fixme` escrow/promo/litige), workflow `.github/workflows/e2e.yml` (workflow_dispatch), exclusion des e2e de la suite smoke (`testIgnore`), doc dans `.env.example`.
- Suite smoke par défaut confirmée à 11 tests (e2e exclus) ; config e2e liste bien ses 4 tests.
- **À faire côté toi** : créer un compte de test acheteur + poser les GitHub Secrets (AYM_E2E_URL, AYM_E2E_EMAIL, AYM_E2E_PASSWORD, AYM_BYPASS_TOKEN si preview privé), puis lancer le workflow « E2E (deployed) ». Le test de login valide les sélecteurs au premier run.

---

## 2026-07-01 : Objectif A — audit machine à états escrow (P2)

- Audit de `advance_order_status()` : 2 trous de sécurité financière trouvés.
  1. Pas de garde d'idempotence : un admin double-cliquant « Lage lajan » (released→released) re-exécutait les effets (re-timestamp + audit dupliqué) → risque de double paiement off-platform.
  2. États finaux non verrouillés : la branche admin autorisait n'importe quelle transition, donc une commande `refunded`/`cancelled`/`completed` pouvait revenir à `released`.
- Correctif : `supabase/migration-2026-escrow-guards.sql` remplace la fonction avec (a) no-op si `from == to`, (b) blocage des transitions depuis un état final. Reste du comportement inchangé. `search_path` figé.
- Validé sur Postgres 16, 6/6 tests (release OK, no-op sans doublon d'audit, refunded/cancelled bloqués, flux acheteur + released→disputed préservés).
- **À déployer** : exécuter la migration dans Supabase.

---

## 2026-07-01 : Objectif A — smoke tests UI (P1)

- Nouveau `tests/ui.spec.mjs` : couche de tests Playwright sans backend (meta/PWA, manifest + icônes, présence du formulaire d'auth, logique `toggleAuthMode()` login ↔ signup, intégrité des assets).
- Suite complète validée en local avec le Chromium préinstallé : **11 tests passent** (6 existants + 5 nouveaux).
- Aide dashboard : Leaked Password Protection se trouve dans Authentication → Attack Protection (probablement plan Pro ; c'est un WARN, non bloquant).
- Reste sur P1 : les tests des flux à argent (checkout/escrow, promo, dispute, gating vendeur) qui nécessitent un compte de test authentifié sur le preview.

---

## 2026-07-01 : Objectif A démarré — durcissement (advisors sécurité)

- Lancé les advisors sécurité Supabase (MCP). Confirmé : RLS activé sur les 22 tables de `public`.
- Corrigé les warnings `function_search_path_mutable` : `search_path` figé sur toutes les fonctions `SECURITY DEFINER`.
  - Mes fonctions (escrow_overview/attention/dispatch, log_error, error_overview) : `search_path = ''` dans leurs migrations source (elles qualifient tout).
  - Fonctions préexistantes : nouvelle migration `supabase/migration-2026-harden-functions.sql` (bloc générique, `pg_catalog, public`, sûr pour les corps non qualifiés).
- Verrouillé les RPC privilégiées : `escrow_dispatch_alerts` cron/owner uniquement (plus d'accès anon/authenticated) ; `escrow_overview`/`escrow_attention_orders`/`error_overview` en authenticated + garde `is_admin`.
- Validé le tout en intégration sur Postgres 16 (search_path figé partout, fonctions OK, droits corrects).
- Reste hors-code : activer « Leaked password protection » dans le dashboard Auth.

---

## 2026-07-01 : Error tracking + clôture de l'Objectif C

- Nouvelle migration `supabase/migration-2026-error-logs.sql` : table `error_logs`, `log_error()` (appelable anon + auth), `error_overview()` (admin). Validé en local sur Postgres 16.
- Front (`index.html`) : handlers globaux `error` et `unhandledrejection` qui loggent dans `error_logs` (throttlés, dédupliqués, sûrs) + carte « Sante Sistèm » dans l'onglet Verifikasyon admin.
- Edge functions `send-push` et `send-email` : capture des crashes dans `error_logs` (source `edge`).
- Routine advisors Supabase documentée (sécurité + perf, ~1×/semaine).
- **Objectif C (Observabilité escrow) : clôturé** — monitoring, réconciliation, alertes pré-auto-release, alerting temps réel, et error tracking sont tous livrés.
- **À déployer** : exécuter les 3 migrations escrow/erreurs, activer pg_cron, redéployer les 2 edge functions.

---

## 2026-07-01 : Ajout de la commande /update

- Nouvelle commande `.claude/commands/update.md` : `/update` met à jour `CONTEXT.md` et `HISTORY.md` de façon guidée (questions, plan validé, puis écriture).
- Le workspace Alita a maintenant ses trois commandes : `/prime`, `/morning`, `/update`.

---

## 2026-07-01 : Alerting temps réel de l'escrow (Objectif C, itération 2)

- Nouvelle migration `supabase/migration-2026-escrow-alerts.sql` : les alertes escrow arrivent maintenant toutes seules à l'admin, par **push + email**, sans qu'on ait à ouvrir l'app.
- Mécanisme : `escrow_dispatch_alerts()` planifié par **pg_cron** toutes les heures, qui insère des notifications (le pipeline `notifications` existant fan-out vers push + email). Dédup via `escrow_alert_log` pour ne pas ré-alerter la même situation.
- Couvre : libération due, libération imminente (12h), paiement en attente de vérif (24h), litige ancien (48h).
- Validé en local sur Postgres 16 (dispatch = 4 notifications, re-run = 0 grâce à la dédup).
- Choix : l'auto-release automatique après 168h reste volontairement de côté (décision financière séparée).
- **À déployer** : exécuter la migration dans Supabase et activer l'extension pg_cron.

---

## 2026-07-01 : Installation du workspace Alita

- Mise en place du workspace personnel **Alita** dans le repo (fichiers `context/`, commandes `/prime` et `/morning`, skill de veille contextualisée).
- Alita est configurée pour être présente à chaque session (section dédiée dans `CLAUDE.md`).
- Contexte de Thrasher rempli dans `CONTEXT.md`.

### Rappel de l'état d'AyitiMarket à cette date

- **Objectif A (QA & Durcissement) :** plan posé, issues #80 à #83 ouvertes.
- **Objectif B (Croissance / Acquisition) :** planifié, issue #84.
- **Objectif C (Observabilité escrow) :** 1re itération livrée et mergée (PR #87) : migration `migration-2026-observability.sql` (RPC `escrow_overview` + `escrow_attention_orders`) et carte admin « Sante Escrow ». Issue #85. Action en attente : exécuter la migration dans Supabase.
- **Prochaine brique prévue :** alerting temps réel de l'escrow (push / email sur libération due et échec de release), puis error tracking.
