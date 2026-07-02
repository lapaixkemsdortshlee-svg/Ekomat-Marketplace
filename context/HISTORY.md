# Workspace History

> Journal chronologique de toutes les sessions et décisions importantes.
> Le plus récent en haut. Mis à jour automatiquement par Alita.
>
> **Comment ça marche :** Après une session importante, ou quand je raconte un changement significatif, Alita ajoute une entrée ici. Je n'ai pas à écrire ce fichier manuellement.

---

## 2026-07-02 : Objectif B — SEO (sitemap + llms.txt + landing pages Kreyòl)

- **`robots.txt` + `sitemap.xml`** (8 URLs : accueil, onboarding, 6 landing pages) à la racine.
- **`llms.txt`** (AI-SEO) : résumé bilingue Kreyòl/EN — fonctionnement de l'escrow, catégories, villes, pages clés — pour être cité correctement par les assistants IA.
- **6 landing pages Kreyòl** sous `/l/` (Elektwonik, Mòd, Bote/Kosmetik, Atizana + Pòtoprens, Cap-Haïtien) : contenu **unique** par page (évite le thin content), JSON-LD structuré (BreadcrumbList + CollectionPage/Organization), OG tags, cross-linking interne, CTA vers l'app. Basées sur les vraies catégories (`SELLER_CATS_MAP`) et villes de l'app.
- Générées par `scripts/gen-landing.mjs` (committé, extensible via le tableau `PAGES`) — pas un build de l'app, juste un outil de contenu.
- Servies en statique : Vercel sert les fichiers existants **avant** le rewrite catch-all `/(.*) → index.html` (même mécanisme que `onboarding.html`), donc aucun changement de `vercel.json`.
- Validé : JSON-LD parse OK (6/6), sitemap bien formé, rendu vérifié au navigateur, **6/6 tests ui** (incl. robots/sitemap/llms + 2 landing pages servies).

---

## 2026-07-02 : Objectif B — Croissance (parrainage bout-en-bout + image OG)

- **PR #99 mergé** (a11y + Open Graph + durcissement XSS HTML) puis branche remise sur `main`, cron de check-in nettoyé.
- **Boucle de parrainage bouclée** : le trou était le crédit **parrain** (`referred_by` stocké à l'inscription, mais le parrain ne touchait jamais rien). Ajout de `supabase/migration-2026-referral-rewards.sql` : trigger `AFTER UPDATE OF status ON orders` → quand la commande d'un filleul passe `released`/`completed`, le parrain reçoit un code one-time **100 HTG** (`scope='referral_reward'`, `max_uses=1`) + une notification. Table `referral_rewards` avec `UNIQUE(referred_id)` (1 récompense par filleul). Testé sur Postgres 16 : grant unique, dédup sur re-transition, buyer non-parrainé ignoré, migration idempotente.
- **Invitation au bon moment** : bouton « Envit yon zanmi » sur les commandes livrées (acheteur) + écran de succès « Vann fèt! 🎉 » après confirmation OTP (vendeur), tous deux vers `openReferralSheet()`. Message WhatsApp-first réécrit + copie du sheet (« Toulède genyen »).
- **Image OG dédiée** : `og-image.png` 1200×630 (carte de marque teal, wordmark AyitiMarket, tagline « Achte & Vann an tout sekirite », badges eskwo/vandè/MonCash, drapeau haïtien), générée via Playwright/Chromium. `twitter:card=summary_large_image` + `og:image:width/height/alt`.
- Validé : 0 erreur de syntaxe (7 blocs), **12/12 tests** (smoke + a11y axe + ui + asset OG) passent.
- **À déployer par Thrasher** : `migration-2026-referral-rewards.sql` (SQL Editor) — s'ajoute aux migrations déjà en attente (`error-logs`, `promo-hardening`).

---

## 2026-07-02 : Durcissement XSS (DOM) — sweep esc()

- CodeQL signalait un baseline XSS (données vendeur/achtè interpolées dans `innerHTML`), re-attribué à la PR #99 à cause du gros diff single-file. Confirmé réel : ex. conversations admin où **noms + contenu des messages** allaient dans `innerHTML` sans échappement → XSS stocké visible par l'admin.
- Ajout d'un helper `esc()` (échappe `& < > " '`) + application sur ~76 sites : URLs d'image (`src`), titres produit, descriptions, noms acheteur/vendeur/utilisateur, bio, location, avis (reviewer), raisons, contenu des messages, titres de notif/annonce.
- **Contexte JS préservé** : les `onclick="fn('${...}')"` (verif/review) n'ont PAS été « esc »-és (échappement HTML inadapté en contexte JS d'attribut) — laissés bruts et **notés pour un refactor dédié** (passer par data-attributes plutôt que d'interpoler dans le JS inline).
- Validé : 0 erreur de syntaxe (7 blocs), 9/9 smoke+ui tests passent. Pas testé au navigateur réel (sandbox ne joint pas Supabase) → une passe QA navigateur reste recommandée.
- Note : le compteur « new alerts » de CodeQL est instable sur ce fichier 1 Mo (il re-signale le baseline à chaque gros diff) ; les PR précédentes touchant `index.html` avaient le même et ont été mergées.

---

## 2026-07-01 : Sweep a11y + libération commandes + démarrage Objectif B (SEO)

- **Sweep a11y** : `alt` ajouté aux 11 `<img>` restants (logos splash, photos produit, avatars chat/partenaire, photos de vérification vendeur). Plus aucun `<img>` sans `alt`.
- **Libération commandes bloquées** : 3 commandes `otp_confirmed` (livrées depuis avril/mai, jamais libérées) libérées via l'admin → **6426 HTG** à verser aux vendeurs (versement MonCash manuel, stub). 0 commande bloquée restante.
- **Objectif B démarré — SEO** : balises **Open Graph / Twitter** + `apple-touch-icon` + `canonical` ajoutées dans `<head>` (aperçu de partage WhatsApp/Facebook). Test OG dans `tests/ui.spec.mjs`. 6/6 tests UI passent. Reste : sitemap, image OG dédiée 1200×630, perf mobile.
- `service_role` régénérée par Thrasher (ok).

---

## 2026-07-01 : Flux escrow validé LIVE en prod (P0 débloqué)

- Thrasher a donné la clé `service_role` (à régénérer après) ; les comptes admin/vendeur se connectaient via Google (pas de mot de passe email), d'où les échecs. J'ai défini des mots de passe temporaires via l'admin API.
- **Flux escrow complet exécuté en prod** avec les 3 vrais comptes (achteur/vandè/admin) : awaiting_payment → payment_submitted → payment_verified → ready_for_pickup → OTP → released. + litige (buyer→disputed, admin→refunded). Commandes de test créées puis **supprimées** (impact net nul).
- **Gardes PR #94 confirmées déployées en prod** : re-release = no-op (pas de doublon d'audit) ; refunded→released = bloqué ("final state").
- Traduit en test répétable : `tests/e2e/escrow-api.spec.mjs` (skip sans identifiants) — **passe** ici.
- Scan axe authentifié rendu répétable (mode session injectée dans `tests/e2e/auth.spec.mjs`) et **exécuté** : feed/order/pub OK, profil avait 1 `image-alt` (avatar) → corrigé (`alt="Foto pwofil"`). Les 2 tests passent.
- **Finding a11y plus large** : plusieurs `<img>` d'avatar/photo sans `alt` ailleurs (lignes ~5068, 6098[corrigé], 7684-7686, 7776, 10464…) — sweep a11y à faire.
- ⚠️ **Action sécurité** : régénérer la clé `service_role` (elle a transité par le chat).

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
