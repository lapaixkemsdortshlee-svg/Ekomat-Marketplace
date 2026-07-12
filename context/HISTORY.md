# Workspace History

> Journal chronologique de toutes les sessions et décisions importantes.
> Le plus récent en haut. Mis à jour automatiquement par Alita.
>
> **Comment ça marche :** Après une session importante, ou quand je raconte un changement significatif, Alita ajoute une entrée ici. Je n'ai pas à écrire ce fichier manuellement.

---

## 2026-07-12 (session 2) : Session UI/UX intensive — Help Center + refonte fiches Komand + cartes profils (5 PR : #164 à #168)

Session lancée par `/prime` (branche `claude/prime-5m9n8n`, on repart de `main` à chaque PR — 5 PR courtes mergées d'affilée par Thrasher). Toutes les modifs dans `index.html` (single-file), Kreyòl, testées (syntaxe JS 8/8 + Playwright 12/12) avant merge. Le style CDN (Tailwind/Material Symbols) n'est pas dispo dans le sandbox, donc QA structurelle en local (audit DOM navigateur) + QA visuelle finale sur le preview Vercel côté Thrasher.

**#164 — Sant Èd (Help Center) dans Paramèt.** Nouvelle entrée « Sant Èd » en tête de Paramèt → Aksyon, ouvre une feuille avec **11 topics en accordéon** (rendu data-driven depuis `HELP_TOPICS`, échappé via `esc()`) + recherche filtrante. Chaque topic a intro + étapes numérotées + note « Poukisa ». Contenu **fidèle au vrai code** (escrow RPC, OTP livraison, MonCash + référence, vérif CIN/Paspò 24-48h + OTP SMS, 5 essais OTP → litige auto). Topics : commencer, escrow, MonCash, chat, vendre, recevoir paiement, panier, recherche, litige, referral, paramètres.

**#165 — Stepper escrow + boutons Komand.** (1) Ajout du **fil connecteur vertical** entre les puces du stepper (`.esc-step::before`, teal pour étapes faites, gris pour à venir) — les cercles étaient isolés/flottants (retour Thrasher « tèks twò santre »). Retrait de l'ancien CSS `.esc-line` mort (jamais généré). (2) Boutons d'action secondaires des fiches Komand (Anile, Pwoteste, Note vandè a, Envit yon zanmi, Kache/Demaske) passés en **icône seule** (36px + `aria-label`/`title`) ; CTA principaux gardent le texte. Décision Thrasher via AskUserQuestion.

**#166 — Fiches Komand alignées à gauche + boutons centrés + bump SW.** Le stepper, les boutons d'action et Kontakte sont **sortis de la colonne indentée** (`flex-1` après la vignette produit) → pleine largeur, ce qui récupère la gouttière vide à gauche sous l'en-tête (les textes semblaient trop à droite). Boutons d'action + Kontakte **centrés** (`justify-center`). **Bump service worker `aym-v36 → v37`** pour pousser Help Center + fiches Komand vers le cache assets des utilisateurs installés.

**#167 — Cartes en-tête profils vendeur & acheteur (style référence).** Thrasher a fourni une carte de réf (freelance : bannière + avatar bas-gauche + chip + rangée stats séparateurs + CTA pilule). Transposé la **forme** avec notre design (dégradé teal, Kreyòl), sur les deux profils. Décisions Thrasher : **juste la carte en-tête** (pas de refonte d'écran), CTA acheteur = **Vin Vandè**. Vendeur (public) : bannière teal + avatar 76px bas-gauche, **bookmark sur la bannière = Swiv** (remplace bouton texte), chip catégorie, stats Nòt/Lavant/Avi, pilule **Kontakte** (= Get in touch) ; absorbe l'ancien Trust Stats grid + duo Swiv/Mesaj ; `toggleFollowSeller` adapté à l'icône bookmark ; variable morte `starsHTML` retirée. Acheteur (own profile, role-aware) : icône edit sur bannière, chip rôle, stats Favori/Komand/Swiv (vendeur : Lavant/Nòt/Abonnen ; admin : mêmes 3 KPI, **mêmes ids** `kpiAdmin*` pour l'updater async), CTA acheteur→Vin Vandè / vendeur→Boutik / admin→Admin.

**#168 — Fix z-index bannière + photo cover.** Retour Thrasher (screenshot) : la bannière passait **par-dessus** l'avatar (tête cachée). **Leçon** : un sibling positionné (`position:relative`, ici la bannière avec ses orbes) peint AU-DESSUS d'un sibling statique même si celui-ci vient après dans le DOM. Fix : corps `position:relative;z-index:1` + avatar `z-index:2` → au-dessus de la bannière (sur les deux cartes). + **Feature photo de bannière** (own profile) : `uploadCoverPhoto()` **miroir de `uploadProfilePhoto`** (data URL stocké local dans `aym_user`, garde quota) ; affichée avec un **dégradé teal par-dessus** (`linear-gradient(rgba teal), url(cover)`, `background-size:cover`) pour un rendu pro/cohérent ; affordance icône caméra « Banyè ».

**Notes techniques / dette connue :**
- Le SW sert le **HTML en network-first** (depuis v29) → les changements `index.html` arrivent aux utilisateurs à la prochaine ouverture sans bump ; le bump v37 (#166) sert le cache des **assets**.
- **Upload photo profil ET bannière = data URL local seulement** (pas d'upload Supabase storage). Limite : pas cross-device, pas visible publiquement (bannière/avatar d'un vendeur pas vus par les acheteurs). Piste future si voulu : colonne `profiles.cover_url` (+ avatar réel) + upload storage. Choix assumé pour rester cohérent avec l'existant et sans migration.
- Workflow PR : auto-watch + check-in 1h programmé à chaque PR, annulé au merge ; commentaires `vercel[bot]` = notif preview Ready, skip silencieux.

**Reste côté Thrasher :** QA visuelle sur le preview (profils, fiches Komand, Help Center, rendu du fil connecteur et de la bannière cover) ; décider s'il veut la bannière/avatar persistés et publics (chantier Supabase séparé).

---

## 2026-07-12 : QA post-rebrand (produits/feed) + cadrage stratégie « pilote avant vendeurs »

Session de suite (branche `claude/prime-sta44n`, on repart de `main` à chaque PR ; PR #160/#161 déjà mergées au démarrage).

**Deux bugs QA remontés par Thrasher, diagnostiqués et corrigés (PR #162, mergée) :**
- **Diagnostic base réelle (via Supabase MCP)** : la table `products` ne contient que **3 produits au total, tous du même vendeur (edf9e083)** — 1 actif (« Headphone JBL »), 2 archivés. Le feed n'affiche que les actifs → il a réellement 1 seule carte. Vérifié au niveau RLS (simulation anon/authenticated) : le produit actif est lisible par tous, rien ne le cache. La sensation de vide = catalogue quasi vide + soft-delete qui masque les archivés, PAS un bug de fond.
- **Bug 1 (vrai)** : `renderSellerProfile()` filtrait le tableau **en mémoire `PRODUCTS`** au lieu d'interroger Supabase → la boutique publique d'un vendeur affichait « 0 pwodwi » selon le chemin de navigation. Fix : `loadSellerProductsFromSupabase(sellerId)` charge les produits actifs du vendeur avant le rendu.
- **Bug 2 (vrai)** : `emptyState()` renvoyait `col-span-2` (utilitaire **grid** Tailwind) alors que le feed est en `columns:2` (**multicol** CSS) → bloc écrasé dans une colonne, « positionnement incohérent ». Fix : pleine largeur dans tous les contextes (`grid-column:1/-1` + `column-span:all` + `width:100%`) + design refait (bulle dégradée teal, CTA pilule). Aperçu visuel envoyé à Thrasher.
- Bonus : variable morte `totalViews` retirée (flag CodeQL sur la ligne modifiée). `sw` : `aym-v35 → v36`.

**Correction d'une erreur d'Alita — gstack :** j'avais conclu « gstack pas installé » sur un `Unknown skill: browse`. FAUX : gstack est bien cloné (`~/.claude/skills/gstack`, restauré par le `session-start.sh`). Les sous-commandes (browse/qa/ship...) passent par le **routeur `gstack`**, pas comme skills autonomes. Ne plus jamais appeler `/browse` en direct → invoquer le routeur `gstack`.

**Cadrage stratégie (sparring) :** Thrasher refuse les données de démo. Objectif : préparer une infra prête pour de VRAIS résultats, pas d'acquisition de vendeurs avant que tout soit correct. Validé sur le fond (un faux catalogue tuerait la confiance). Recadrage accepté comme objectif court terme : remplacer « tout est correct » (infini) par **une transaction réelle E2E réussie**, testée en **pilote fermé 2-3 vrais vendeurs**. Prochaine action : **audit chemin-critique** (checklist rouge/jaune/vert des rails escrow/paiement/commandes/litiges/notifs/vérif) sur le vrai code + la vraie base. Ajouté aux objectifs court terme dans CONTEXT.md.

**Autonomie :** Thrasher parti pour la nuit, Alita en auto — gère CI/PR sans attendre de validation, ni merge des PR. Il attend les routines à l'heure prévue.

---

## 2026-07-11 (session 2) : Ekomat post-rebrand — design, features onboarding, durcissement DB, et pipeline mis de côté

Grosse session de suite (branche `claude/prime-sta44n`, repo renommé `Ekomat-Marketplace`, on repart de main à chaque PR). Beaucoup de PR courtes mergées d'affilée. Le pipeline `db-migrate` étant cassé (voir plus bas), les migrations DB ont été appliquées **via le MCP Supabase** (`apply_migration`), pas par le pipeline.

**Logos & identité (PR #152, #157, #158) :**
- Fichiers logo officiels de Thrasher rangés dans `brand/` ; login/splash passés en logo transparent, icônes 192/512, favicon, og-image régénérés. `index.html` allégé (~240 Ko de base64 retirés).
- Header : wordmark texte → vrai logo image (28px). Login 240→150px, splash 280→200px (sur retour Thrasher « trop gros/centré »).
- Splash : wordmark → **icône « e » turquoise** (`brand/splash-icon-teal.png`, recadrée de `mark-teal.png`) centrée style WhatsApp. Fix CSS : `.screen.on{display:block}` cassait le flex du splash → ajout `#s-splash.on{display:flex;center;fixed;inset:0}` (spécificité id+classe, indépendant de Tailwind). Toast « Lang: Kreyòl » retiré à l'ouverture (ne s'affiche plus que sur vrai changement).

**Features onboarding (PR #159, #160) :**
- **Carte de bienvenue** teal en haut du feed (remplace le toast noir `toast('Byenveni …')`) : icône + prénom + message Kreyòl, se ferme, auto-dismiss 7s.
- **Tutoriel coach-marks** (nouveau compte, 1 fois, flag `aym_tutorial_done`, passable) : moteur vanilla single-file — backdrop assombri + spotlight (box-shadow troué) + anneau teal pulsant + badge `touch_app` animé + bulle Kreyòl + points + Pase/Anvan/Swivan/Fini. Étapes Feed/Rechèch/Mesaj/Pibliye/Vann rapid(+)/Komand/Panye/Pwofil, saute les cibles cachées. Bouton Swivan/Fini animé (pulse) sur retour Thrasher.

**Durcissement DB (PR #154, #155 mergées ; appliqué en prod via MCP car pipeline cassé) :**
- **Perf** : 78 lints advisor traités — 18 index couvrants sur FK + 60 réécritures `auth.uid()/auth.role()` → `(select …)` (RLS initplan). DDL généré par Postgres, validé en rollback prod. 143→83 lints (les 27 `unused_index` restants = normal, dont les 18 FK neufs ; ne PAS dropper avant trafic).
- **Sécurité** : 2 fuites RLS fermées — `profiles_select_public` (USING true → exposait moncash_number/phone/location à l'anon) et `reviews_insert_own` (permettait de poster un avis sans achat). Validé par Thrasher.
- **Écran de rôle** : bug « l'écran Ki wòl ou? ne s'affiche pas pour un nouveau compte » → cause : `profiles.role` avait DEFAULT 'buyer' + trigger `handle_new_user` → nouveau compte toujours 'buyer', donc `needsRoleSelection` jamais vrai. Fix validé Thrasher : `ALTER TABLE profiles ALTER COLUMN role DROP DEFAULT` (appliqué via MCP). Le code gère déjà le rôle NULL → écran affiché → `supabaseSaveRole` persiste.

**Alerte secret scanning** : GitHub a flaggé la clé Web Firebase → faux positif (publique par design). Documenté dans SECURITY.md ; à restreindre côté Google Cloud (referrers + API) + fermer l'alerte = action Thrasher.

**⚠️ Dette infra — pipeline db-migrate CASSÉ (décision : mis de côté 2026-07-11).** Le workflow `.github/workflows/db-migrate.yml` échoue à `supabase db push` avec `password authentication failed` (SASL, pooler Supavisor). Thrasher a reset le mot de passe DB et mis à jour le secret GitHub `SUPABASE_DB_PASSWORD` plusieurs fois, re-run plusieurs fois → toujours l'erreur. Vérifié via docs officielles (read-the-damn-docs + Supabase search_docs) : pas de ban IP (vérifié dashboard), donc **simple mismatch de valeur** entre le secret et le vrai mot de passe DB. **Décision Thrasher : on laisse le pipeline de côté** — les migrations sont déployées via MCP `apply_migration` (fiable, déjà fait 3× cette session). À reprendre tête reposée : reset password + coller la MÊME valeur alphanumérique des deux côtés en une fois.

**Routines Alita (rappel, du matin) :** recréées en Ekomat mais l'environnement CCR « Thrasher » (env_01RAYcqggJeAogVDUbDcwaqZ) doit être ré-attaché au repo `Ekomat-Marketplace` par Thrasher (le test de session fraîche échouait encore : repo pas cloné). Action console, non automatisable.

**Reste côté Thrasher :** réparer le secret DB (ou laisser, MCP suffit) ; ré-attacher le repo aux routines ; restreindre + fermer l'alerte clé Firebase ; redéployer edge functions send-email/send-push ; renommer Firebase/Google OAuth ; vérifier collisions « Ekomat » puis acheter le domaine ; QA appareil des features onboarding.

---

## 2026-07-11 : REBRAND COMPLET — AyitiMarket devient EKOMAT (PR #151 mergée + PR #152 logos)

Thrasher a tranché le rebrand (décidé le 2026-07-04) : le nouveau nom est **Ekomat**, avec une identité visuelle créée par lui : un « e »-boule rust (#97422B) avec une anse teal (#00666F) façon sac de course, wordmark « eko » rust + « mat » teal sur fond cream, alignée sur la palette BRAND.md (PR #150).

**PR #151 (mergée) — rebrand texte complet :**
- `index.html` (53 chaînes : meta/OG/title, strings Kreyòl, notifs, bot « Asistan Ekomat », console), `manifest.json`, `onboarding.html`, `firebase-messaging-sw.js`, wordmark header « eko/mat », `sw.js` bump `aym-v30`.
- Landing pages regénérées, `llms.txt`, `README`, `SECURITY.md`, `.env.example`, docs (guide déploiement : **bundle ID → `com.ayitidigital.ekomat`**, jamais publié sous l'ancien donc sans risque), templates email/push des edge functions, tests Playwright, `package.json`.
- **Pas touché (volontaire)** : IDs Firebase `ayitimarket-19c78`, URLs `ayiti-market.vercel.app` (domaine pas encore acheté), clés localStorage `aym_*`, project_id Supabase CLI, migrations SQL historiques, chemins d'infra.

**PR #152 — logos officiels intégrés :**
- Thrasher a déposé ses 6 fichiers PNG sur `main` ; rangés dans `brand/` (noms web-safe). Le wordmark transparent remplace les 2 mascottes base64 du login/splash (celle du login se fond dans la page cream, comme demandé) ; **`index.html` passe de ~1.08 Mo à 842 Ko**.
- Icônes 192/512 régénérées depuis le mark (cream, mark à 62% du cadre, maskable OK), `favicon.png`+`favicon.ico` + links (onglet navigateur Vercel), `og-image.png` 1200×630 depuis le logo officiel, vrai logo dans le header des landing pages, `sw.js` bump `aym-v31` + précache.
- Vérifié : JS OK, 12/12 Playwright, rendu navigateur contrôlé.

**Renommages faits par Thrasher dans la foulée :** projet Vercel → `ekomat-marketplace`, repo GitHub → `Ekomat-Marketplace`. Les redirections GitHub/Vercel fonctionnent : workflow migrations, remote git et accès continuent sans changement. Docs alignées.

**CodeQL rouge sur les 2 PR = faux positif de baseline** (connu depuis juillet) : sur ce fichier énorme, tout gros diff fait re-signaler les alertes baseline comme « nouvelles ». Prouvé mécaniquement cette fois (diff symétrique normalisé : zéro logique JS changée) et documenté en commentaire sur chaque PR. Leçon détaillée sauvée dans agentmemory.

**Leçon de méthode (recadrage Thrasher, x2) :** (1) j'ai tenté de recréer son logo en SVG depuis les captures d'écran → veto net (« pa defòme li ») : les assets de marque sont SES fichiers, on demande les originaux, on ne les réinvente pas (les dérivés mécaniques resize/crop/fond restent OK) ; (2) charger les skills du repo et afficher une checklist AVANT d'exécuter, pas d'exécution tête baissée.

**Reste côté Thrasher :** QA visuelle du preview puis merge #152 ; redéployer les edge functions `send-email`/`send-push` ; renommer Firebase + écran de consentement Google OAuth ; vérifier collisions « Ekomat » (marque + domaine) PUIS acheter le domaine et mettre à jour les URLs.

---

## 2026-07-05 : ALITA DEVIENT AUTONOME — sous-agent intent, roadmap, et les 4 chantiers livrés (5 PR : #141 à #145)

La session qui transforme Alita d'outil en agent. Point de départ : la question de Thrasher « qu'est-ce qui manque à Alita pour devenir un agent puissant ? ». Diagnostic sparring : ce ne sont pas les capacités qui manquent (~150 skills, 10+ connecteurs), ce sont les **boucles fermées** (agir sans session, déployer sans humain, mémoriser, notifier). Roadmap validée par Thrasher, puis exécutée dans la même session.

**PR mergées :**
- **#141** — Sous-agent **`alita-intent`** (`.claude/agents/alita-intent.md`) : analyse les demandes ambiguës de Thrasher (courtes, mélange FR/kreyòl, fautes de frappe) AVANT exécution → intention probable, lectures alternatives, prompt amélioré, signaux sparring. Câblé dans CLAUDE.md. Lecture seule, ne bloque pas si l'intention est claire à 80 %+.
- **#142** — **`context/ROADMAP-AUTONOMIE.md`** : les 4 chantiers avec checklist, qui-fait-quoi (Alita vs Thrasher), critères de vérification, garde-fou permanent (routines en lecture/rapport, actions d'argent = Thrasher).
- **#143** — **Chantiers 1, 3, 4 exécutés** :
  - **Routines créées** (sessions fraîches, lecture seule) : Morning brief (12h UTC = 7h Haïti, quotidien, push), Santé hebdo (lundi 13h UTC, advisors + erreurs + escrow + KPIs, push+email), Sentinelle (22h UTC, silencieuse si RAS, push+email). Test manuel déclenché → **notification reçue et confirmée par Thrasher**.
  - **Mémoire** : 7 leçons durables semées dans agentmemory (project `ayitimarket`) + discipline remember/recall câblée dans CLAUDE.md + hygiène HISTORY dans /update.
  - **Canal** : décision Thrasher = push + email seulement, WhatsApp écarté (payant), à revoir dans 1 mois.
- **#144** — **Chantier 2 : pipeline de déploiement auto des migrations** : `.github/workflows/db-migrate.yml` (`supabase link` + `db push` sur push main touchant `supabase/migrations/**`, pattern officiel vérifié dans les docs), `supabase/config.toml`, migration no-op de test, règle CLAUDE.md (nouvelles migrations = `supabase/migrations/<timestamp>_nom.sql`, destructif = revue Thrasher). Baseline : les anciens `migration-2026-*.sql` restent historiques, jamais rejoués.
- **#145** — Clôture chantier 2 après validation en prod.

**Debug du premier run (leçon utile) :** run 1 rouge → logs : `password authentication failed` sur `db push` (le `link` passait, donc token OK). Cause : le secret `SUPABASE_DB_PASSWORD` ne contenait pas le vrai mot de passe **DB** (piège : ce n'est ni l'anon key ni la service_role). Fix : reset du mot de passe dans Supabase (Settings → Database) en le TAPANT soi-même, même valeur dans le secret GitHub (Actions → Repository secrets), re-run → vert. Vérifié : `20260705050000 (pipeline_test)` enregistrée dans `schema_migrations` en prod via `list_migrations`.

**⚠️ Sécurité à faire par Thrasher :** son mot de passe DB était visible dans une capture d'écran partagée dans le chat → refaire un reset + update du secret GitHub (2 min, même manipulation).

**État final : 18/21 étapes de la roadmap.** Restent : 1.6 (bilan bruit des routines, ~1 semaine), 3.4 (vérifier recall en prochaine session), 4.3 (décision WhatsApp, ~1 mois). Premier Morning brief réel : 2026-07-06 7h Haïti.

**Notes opérationnelles :**
- GitHub MCP ne peut PAS déclencher/re-lancer un workflow (403 « Resource not accessible by integration ») → le « Re-run all jobs » reste un clic Thrasher.
- Le classifier de sécurité de session bloque (à juste titre) un psql avec mot de passe en clair dans la commande → passer par le MCP Supabase (lecture seule) pour vérifier.

---

## 2026-07-04 : Suite session — sparring mode, skills BuilderIO, mot de passe oublié, décision rebrand (5 PR + décisions)

Prolongement de la session recherche (voir entrée suivante). Toujours branche `claude/prime-11fc5t`, on repart de `main` à chaque PR. Le mode **sparring partner** a été activé en cours de route et appliqué au reste de la session.

**PR mergées :**
- **#136** — Activation du **mode sparring partner** comme posture par défaut d'Alita. Le fichier `CLAUDE-sparring-partner.md` existait à la racine mais rien ne le chargeait (config morte) : câblé dans `CLAUDE.md` (auto-chargé) + `/prime`. Verdict d'abord, zéro flatterie, steelman-puis-attaque, garde-fou anti-contrarien.
- **#137** — Installation du pack **BuilderIO/skills** (10 skills agent-workflow : visual-plan, visual-recap, plan-arbiter, agent-watchdog, plow-ahead, read-the-damn-docs, quick-recap, stay-within-limits, efficient-fable, adding-a-skill) via `npx skills add BuilderIO/skills`, + réf dans `CLAUDE.md`. **Aucun secret committé** : le `mcp_token` du service hébergé (liens visual-plan/recap) reste hors git ; l'auth hébergée est à faire par Thrasher en local (`npx @agent-native/core connect ...`). Note : l'installeur interactif hang dans le sandbox remote (pas de TTY) ; le CLI Vercel `skills` détecte l'agent et installe non-interactivement.
- **#138** — Flux **« mot de passe oublié »** (n'existait pas). Lien « Modpas bliye? » en mode login → `resetPasswordForEmail(redirectTo: window.location.origin)` → événement `PASSWORD_RECOVERY` → feuille « Nouvo modpas » → `updateUser`. Kreyòl. **Dépendance dashboard côté Thrasher (indispensable en prod) : whitelister les Redirect URLs (Auth → URL Configuration) + configurer un SMTP custom** (le SMTP Supabase par défaut est limité ~3-4/h, test only ; reco : Resend).
- **#135** — Log de la session recherche (voir entrée suivante).
- **#139** — Objectifs Alita ajoutés à `CONTEXT.md` : **rebrand + domaine** (renommer AVANT d'acheter le domaine) et **acquisition de vendeurs** (prévu, pas maintenant).

**Décision produit majeure — REBRAND :** analyse sparring de la collision de nom. Constat clé (recherche web) : « AyitiMarket » n'est pas juste en collision avec **myayitimarket.com**, c'est un **terme générique** partagé par plusieurs entités (ayitimarket.com « Ayiti Market » actif, Ayimarket, Market Haiti, Caribbean Marketplace...). Donc SEO indifférenciable + marque quasi indéposable. Verdict : renommer est justifié (la vraie raison de Thrasher, #3, était « trop générique » — pas la peur du concurrent). **Timing** : pré-lancement + pré-traction (1 vendeur) = moment le moins cher pour renommer ; le bundle ID `com.ayitidigital.ayitimarket` devient permanent une fois publié sur les stores, donc renommer AVANT publication. Brainstorm de noms distinctifs (Konbit(a), Sara/Madan Sara, Lakou, Potomitan, Twòk...) fait ; **Thrasher gère le choix final du nom + l'identité visuelle, on en reparle.**

**Découverte technique en passant** : la colonne `profiles.categories` **n'existe pas** en prod (le code de vérification vendeur tente d'y écrire en silence sans succès) — d'où le choix de dériver les catégories vendeur de leurs produits (#134). À réparer proprement un jour (le write cassé dans le flux verification).

**État de déploiement (mis à jour) :**
- ✅ `migration-2026-seller-search-cat.sql` : **déployée** par Thrasher (recherche floue + filtre catégorie + zone ILIKE actifs).
- ⏳ Reste côté Thrasher : les 2 réglages Auth pour le mot de passe oublié (Redirect URLs + SMTP), et le rebrand (nom + identité + domaine).

---

## 2026-07-03 (session 2) : Recherche boutique/vendeur — 3 PR mergées (nom, flou pg_trgm, filtre catégorie/zone, écran « Tout Boutik »)

Session lancée par `/prime`. Point de départ : Thrasher voulait qu'un utilisateur puisse chercher précisément le nom d'une boutique OU d'un vendeur, dans une zone précise. On a d'abord challengé l'hypothèse (esprit council/brainstorming) avant de coder. Chaque lot testé (7 blocs JS + 12/12 Playwright + vérif navigateur offline + validation SQL en lecture seule sur la vraie base via Supabase MCP) puis mergé via sa propre PR. Branche `claude/prime-11fc5t`, on repart de `main` à chaque fois.

**Découvertes qui ont recadré le design (en lisant la vraie donnée) :**
- **« boutique » et « vendeur » = le même champ** `display_name` (pas de table boutique séparée). Le « OU » de l'hypothèse était en fait une seule recherche.
- La recherche existante ne cherchait **que les produits** (le placeholder « vandè » était mensonger).
- La colonne `categories` sur `profiles` **n'existe pas** : le code de vérification vendeur tentait d'y écrire en silence sans succès. → on **dérive** les catégories d'un vendeur de ses produits actifs.
- Les `location` vendeur sont du **texte libre** (ex. « Village Eden, Commune de Delmas »), donc le filtre zone en match exact ratait tout → corrigé en `ILIKE`.

**PR mergées :**
- **#132** — Recherche par nom boutique/vendeur (section « Boutik / Vandè » dans la feuille de recherche, résultats cliquables vers l'écran boutique existant) + filtre zone optionnel + **zone rendue éditable** dans le profil vendeur (avant : figée à l'inscription). Bug latent `merged` hors scope corrigé au passage. 100% client-side.
- **#133** — Recherche **floue `pg_trgm`** (`word_similarity > 0.4` + `ILIKE`, ex. « Berli » trouve « Berlly Lapaix ») via RPC `search_sellers(q, zone)` SECURITY INVOKER (RLS s'applique, zéro escalade), `search_path` figé, index GIN trigram. Client **résilient** : tente le RPC, retombe sur l'`ILIKE` direct si la migration n'est pas déployée.
- **#134** — **Filtre catégorie** (produits + boutiques, catégories dérivées des produits, affichées en étiquettes) + **fix zone `ILIKE`** + **écran « Tout Boutik »** (écran séparé ouvert via bouton « Gade tout boutik » dans la recherche, filtres zone+catégorie, pas de nouveau tab dans la barre de nav) + **note Alita** (objectif long terme n8n). RPC `search_sellers(q, zone, cat)` v2 (EXISTS sur produits, retourne les catégories dérivées) qui **remplace** la v1 de #133.

**Décisions de Thrasher :**
- Recherche sur le nom **public** seulement (`display_name`), pas le nom personnel (vie privée).
- Filtre zone **optionnel** + recherche **floue** (pas exacte).
- Zone rendue éditable côté vendeur.
- Onglet « Boutik » = **écran séparé** depuis la recherche (pas un 5e tab dans la barre de nav).
- Nouvel **objectif long terme** ajouté à `CONTEXT.md` : automatiser toutes les tâches admin par l'IA via **n8n** (à l'avenir, pas maintenant).

**À déployer côté Thrasher (SQL Editor) :**
- `migration-2026-seller-search-cat.sql` — version **finale et autonome** du RPC : elle **remplace** `migration-2026-seller-search.sql` (#133), donc déployer **uniquement celle-là**. Sans elle, le fallback ILIKE tourne (mais sans filtre catégorie ni flou).

**Note infra récurrente :** la QA navigateur ne peut pas joindre Supabase depuis le sandbox → validation faite en 3 couches (syntaxe JS, Playwright offline, et logique SQL testée en **lecture seule sur la vraie base prod** via Supabase MCP, aucune écriture). La QA UI réelle reste à faire par Thrasher sur le preview/prod.

---

## 2026-07-03 : Grosse session UX/produit — 12 PR mergées (états UX, reco feed, parrainage, E2E, admin, masquage, graphiques)

Session très dense, lancée par `/prime`. Chaque lot testé (7 blocs JS + 12/12 smoke + vérif navigateur) puis mergé via sa propre PR. On repart de `main` à chaque fois (branche `claude/prime-mfsxam`).

**Expérience & états UI**
- **#117** — Loading states: loaders contextuels (skeleton/spinner/barre selon le contexte) + couche « psychologie du chargement » (texte rassurant dynamique au-delà de 5s) branchée sur les flux argent/escrow qui n'avaient aucun feedback réseau. Helpers `btnBusy`, `withDelayedMessage`, `showBusy`.
- **#118** — État de succès: icône animée à l'entrée + célébration **confetti** self-contained (gated `prefers-reduced-motion`) sur « Vann fèt! » + a11y (`role=status`, focus).
- **#119** — États erreur + vide: `errorState()` avec bouton « Eseye ankò » (retry), `emptyState()` enrichi avec CTA + illustration.

**Croissance & algo**
- **#120** — Moteur de reco **feed à biais de confirmation** (type Pinterest/Shein), régime **équilibré (~25% exploration)**: vecteur d'intérêt récent `iv`/`sv` sur `A.prof` avec décroissance (demi-vie 2j), signaux recherche/ouverture/panier/favori, epsilon-greedy pour l'exploration. 100% client-side, aucune migration.
- **#121** — Parrainage **limité à 3 personnes** (`max_uses=3`, compteur « Rete X/3 ») + **test E2E promo** activé + **auto-run E2E** sur chaque déploiement Vercel (`deployment_status`).

**Infra QA**
- **Débloqué la QA E2E automatique**: le sandbox ne peut pas joindre Supabase depuis un navigateur (le proxy egress reset le TLS du navigateur; `curl`/MCP passent). Solution: GitHub Secrets (`AYM_E2E_URL/EMAIL/PASSWORD`) + **token Vercel Protection Bypass** (l'URL prod était derrière un « Security Checkpoint »). Depuis, le workflow tourne seul sur chaque preview.

**Admin & vendeur**
- **#123** — 5 correctifs admin/vendeur: barre « Kontakte vandè » fixe, fix erreur onglet Pwodwi (`products.seller_name` inexistante), onglets admin en icônes + nouvel onglet **Estatistik**, KPI **« Itilizatè »** (total inscrits).
- **#126** — **Graphiques animés** vendeur (sparkline « Lavant pa jou » qui se dessine + barres top-produits) et admin (funnel AARRR + revenu en barres). Skill `dataviz` utilisé; une seule teinte teal (magnitude), pas de dépendance.
- **#127** — Libellés admin en **Kreyòl simple** (« Kwasans — Antònwa AARRR » → « Kijan biznis la ap grandi »), + crash `p.sizes.length` gardé, + feedback admin en grand, + barre vendeur solide.
- **#128** — **Confusion localisation tranchée**: gardé « Zòn Kolekte » (pivot du flux pickup/escrow), retiré « Adrès mwen » (couche multi-adresses redondante — app pickup-based).

**Historique de commande — masquage (pas suppression)**
- **#124** — Boutons de commande qui respirent (flex-wrap) + masquage local (localStorage).
- **#125** — Masquage **par compte** (colonne `buyer_hidden` + RPC `hide_order`, cross-device) + message d'erreur admin dé-tronqué.
- **#129** — **Vraie cause du « le fix ne prend pas » trouvée**: le service worker servait `index.html` en cache-first sans bump de version → l'appareil tournait l'ancien code (d'où le TypeError `p.sizes` qui « revenait »). Corrigé: `sw.js` en **network-first** pour le HTML + bump `aym-v29`. + **modal stylé** `appConfirm` (remplace le `confirm()` natif) + **démasquage** (bouton « Demaske » + toggle « Wè komann kache yo »).
- **#130** — Carte de transaction: **vraie photo produit** (batch depuis `products.images`, fallback icône) + masquage/démasquage étendu au **vendeur** (colonne `seller_hidden`, RPC role-aware).

**Décisions produit de Thrasher**
- Modération produits obligatoire: **écartée** (goulot pour un admin solo alors que les vendeurs sont déjà vérifiés par pièce d'identité). Version légère « 1er produit » proposée si besoin.
- Migration parrainage `migration-2026-referral-cap.sql`: déjà exécutée.

**À exécuter côté Thrasher (SQL Editor), quand il veut le cross-device**
- `migration-2026-order-hide-both.sql` — version finale du masquage (acheteur + vendeur, `buyer_hidden`/`seller_hidden`, RPC role-aware, idempotente, supersede les anciennes `order-hide`/`order-unhide`).
- Sur son téléphone: rouvrir l'app une fois pour que le service worker charge la v29 (fait disparaître le crash en cache).

---

## 2026-07-02 (session 3) : Extension de l'arsenal de skills (ASO, visuel, décision, recherche, conversion)

Thrasher a fait installer plusieurs skills externes et un skill maison, chacun évalué avant install puis mergé via une petite PR dédiée.

- **`find-skills` activé** comme méta-skill (chercher/installer via `npx skills find` / `add`). Ça bouche le dernier trou : la boîte à outils est maintenant auto-extensible.
- **Installés + mergés :**
  - **ASO suite** (Eronred/aso-skills, 39 skills) pour la sortie stores : `app-marketing-context`, `aso-audit`, `keyword-research`, `metadata-optimization`, `android-aso`, `localization`, `screenshot-optimization`, `app-preview-video`, `app-launch`, `app-rejection-recovery`, `rating-prompt-strategy`, etc. (#112)
  - **visual-skills** (smixs) : `image`/`video` de génération de prompts IA (Nano Banana, GPT Image, Kling, Veo). Ils **remplacent** les anciens `image`/`video` marketing sous ces noms (récupérables via git). Choix validé par Thrasher. (#112)
  - **launch** (coreyhaines31) (#112)
  - **markitdown** (Microsoft, wrappé via `uvx`) : convertit PDF/Word/PPT/Excel/images/audio/HTML vers Markdown, sans install permanent (adapté à l'environnement éphémère). Testé sur le PDF du guide de déploiement. (#113)
  - **claude-council** (TorpedoD) : stress-test de décisions à 5 conseillers + débat + synthèse, tourne dans Claude Code, **sans clé API**. Revue sécu OK avant merge. Pour un fondateur solo qui décide seul. (#114)
  - **deep-research maison** : recherche multi-sources itérative (query → lecture → apprentissages cités → récursion → rapport) via `WebSearch`/`WebFetch`, **sans clé API ni service payant**. Alternative gratuite à dzhng/deep-research. Modes quick/standard/deep, rapport sous `research/`. (#115)
- **Évalués puis écartés :** `llm-council` (app autonome + clés API) et `dzhng/deep-research` (Firecrawl + OpenAI payants → remplacé par le skill maison). `superpowers` : vérifié déjà installé (15 skills présents).
- **Process récurrent :** comme la branche `claude/alita-rllci2` est mergée à chaque fois, on repart de `main` à jour (`git checkout -B ... origin/main`, push force-with-lease), draft PR, CI vérifiée, merge. 4 PR au total (#112 à #115).

---

## 2026-07-02 (session 2) : 🎯 Objectifs A/B/C ATTEINTS + guide de déploiement mobile

Thrasher acte la clôture. Mis à jour de `context/CONTEXT.md` (section « Objectifs déjà ATTEINTS »).

- **A (QA & Durcissement)** ✅ : flux escrow E2E, RLS/RPC durcis, audit sécurité complet traité — advisors Supabase re-vérifiés en live : **zéro alerte non intentionnelle** (reste que des WARN voulus + toggle Leaked Password pour le plan pro).
- **B (Croissance)** ✅ : parrainage bout-en-bout, SEO/AI-SEO, funnel AARRR. Reste : ads (reportées, coût).
- **C (Observabilité escrow)** ✅ : clôturé (monitoring, réconciliation, alerting, error tracking).
- **Nouveau milestone — déploiement mobile** : Thrasher a fourni `AyitiMarketDeploymentGuide.pdf` → converti en `docs/DEPLOYMENT-GUIDE.md`. L'app est prête à être packagée PWA → Android (Google Play) et iOS (App Store) via Capacitor 6.x (`com.ayitidigital.ayitimarket`, v2.0.0 MVP Final). Prochain objectif court terme : **publier sur les stores**.

---

## 2026-07-02 (session 2) : harden-p1c — retirer les fonctions trigger de l'API

Advisors re-vérifiés après `harden-p1b` : `advance_order_status`/`try_seller_otp` bien retirées de `anon` ✅. Restaient des WARN `0028`/`0029` sur des **fonctions trigger** exposées inutilement comme RPC. → `migration-2026-harden-p1c.sql` : `REVOKE EXECUTE FROM PUBLIC, anon, authenticated` sur `grant_referral_reward`, `handle_new_user`, `promo_codes_inc_used`, `update_seller_rating`, `rls_auto_enable`, `generate_order_number`, `update_updated_at`, `update_updated_at_column`.
- **Sûr** : une fonction trigger n'a pas besoin du privilège EXECUTE pour se déclencher (Postgres ne le vérifie pas). Vérifié aussi qu'aucune n'est appelée en `rpc()` dans le repo. **À déployer.**
- Laissées volontairement : `log_error`/`increment_views` (anon voulu), `validate_promo_code` (RPC checkout), `is_admin` (utilisée dans les policies RLS).
- Décisions Thrasher : Leaked Password Protection = **plus tard** (plan pro) ; `pg_trgm`/`pg_net` + `0029` sur les vraies RPC = accepté.

---

## 2026-07-02 (session 2) : Advisors post-déploiement — complément harden-p1b

Thrasher a déployé les migrations. Re-run des advisors sécurité :
- ✅ Résolu : `referral_rewards` (policy admin), `search_path` sur les 3 fonctions trigger, et `anon` retiré de `escrow_overview`/`escrow_attention_orders`/`funnel_overview`/`error_overview`.
- ⚠️ Résidu trouvé : `advance_order_status` et `try_seller_otp` restaient `anon`-exécutables car elles gardaient un grant **PUBLIC** (anon ∈ PUBLIC) que `REVOKE FROM anon` ne pouvait pas masquer. → `migration-2026-harden-p1b.sql` : `REVOKE ... FROM PUBLIC, anon` + `GRANT authenticated`. **À déployer.**
- 🟡 Accepté (by design) : les WARN `0029 authenticated_security_definer` (les RPC DOIVENT être appelables par les users connectés — gardes internes), `pg_trgm`/`pg_net` dans public, et `log_error`/`increment_views`/`validate_promo_code`/`is_admin` anon (voulu : erreurs front, vues publiques, self-reject). Reste dashboard : activer Leaked Password Protection.

---

## 2026-07-02 (session 2) : Audit sécurité → Info/accepté (clôture audit)

Dernier lot. P0 (#105) et P1 (#106) mergés. Ici on traite/documente le reste.

- **`referral_rewards` RLS sans policy** (INFO) → `migration-2026-referral-rewards-policy.sql` : policy SELECT admin (audit des récompenses possible ; écritures restent fermées, trigger only). Résout l'advisor.
- **`SECURITY.md`** : ajout d'une section « Odit sekirite 2026-07-02 » qui documente P0/P1/Info + les risques **acceptés** avec rationale : CSP `unsafe-eval` (requis Tailwind/Babel), `pg_trgm`/`pg_net` dans public (déplacement risqué), clé Firebase Web (publique par design).
- **Actions dashboard restantes** (Thrasher) : activer Leaked Password Protection ; déployer les migrations `harden-p1` + `referral-rewards-policy` ; relancer les advisors après.
- **Audit clôturé** : les 3 lots (P0/P1/Info) traités.

---

## 2026-07-02 (session 2) : Audit sécurité → P1 (durcissement)

P0 mergé (#105). **P1 = préparé** (`migration-2026-harden-p1.sql`, à déployer par Thrasher au SQL Editor). Bodies + grants inspectés via Supabase MCP (read-only) avant d'écrire, pour ne rien casser.

- **search_path figé** (`''`) sur les 3 fonctions trigger encore flaguées (`generate_order_number`, `update_updated_at`, `update_updated_at_column`) — corps vérifiés (builtins / `nextval('public.orders_id_seq')` qualifié), donc sûr.
- **REVOKE anon** sur les RPC admin (`escrow_overview`, `escrow_attention_orders`, `funnel_overview`, `error_overview`) + `advance_order_status` + `try_seller_otp`. Constat : Supabase **auto-grante `anon`** sur les nouvelles fonctions, donc mon `REVOKE FROM PUBLIC` initial ne suffisait pas. Non exploitable (gardes internes `is_admin`/`auth.uid()`) mais moindre privilège. `log_error` reste anon (voulu).
- **CSP `unsafe-eval`** : gardé — requis par le CDN Tailwind + Babel de `onboarding.html`. Documenté ; à retirer seulement si on précompile.
- **Restent hors-code (dashboard)** : activer Leaked Password Protection ; extensions `pg_trgm`/`pg_net` dans public (déplacement risqué, laissé). → ce sera le lot « Info/accepté ».

---

## 2026-07-02 (session 2) : Audit sécurité → correction P0 (XSS stockés)

Après un audit complet (code statique + advisors Supabase live), on corrige les findings **étape par étape**. **P0 = terminé.**

- **XSS contexte JS (issue #100 — confirmé RÉEL, pas un artefact CodeQL).** Le nom d'affichage choisi par un vendeur/utilisateur était interpolé brut dans des `onclick`, donc du JS arbitraire s'exécutait **dans la session admin** (prise de contrôle admin possible). Corrigé avec un nouveau helper **`jsAttr()`** (échappe JS puis HTML-attribut) appliqué à : `approveVerif`, `rejectVerif`, `openIDModal`, `openRejectSheet`, `toast('${u.name}…')`, `openVideoPlayer('${vr.reviewer}')`, `openConversation`, `openRatingSheet`, `addToLook`, block/unblock user. `jsAttr()` prouvé anti-breakout (test node : 9/9 payloads malicieux round-trip en simple chaîne inerte).
- **XSS attribut HTML (résidu du sweep esc()).** `alt="${p.t}"` et `src="${src}"` dans le carrousel produit → `esc()`. Affectait tous les acheteurs.
- Validé : 7 blocs JS sans erreur, 12/12 tests (le fail a11y initial était un timeout de chargement, vert au re-run).
- Reste sur l'audit : **P1** (durcissement : search_path sur 3 fonctions trigger, REVOKE anon sur RPC admin, CSP, leaked-password) puis **Info/accepté**.

---

## 2026-07-02 : RÉCAP GLOBAL DE SESSION — Objectifs A/B/C avancés + clôture

Session dense. Les trois objectifs (`docs/QA-PLAN.md`) sont maintenant solides.

**PR mergées aujourd'hui : #99 → #103.**

- **#99** — Finition Objectif A + démarrage B : sweep a11y (`alt` sur tous les `<img>`), Open Graph/Twitter, durcissement XSS HTML (helper `esc()` sur ~76 sinks, dont un vrai XSS stocké dans le chat admin). Libération de 3 commandes bloquées → 6426 HTG dus aux vendeurs.
- **#101** — Parrainage bout-en-bout : le trou était le **crédit parrain** (`referred_by` stocké mais parrain jamais récompensé). `migration-2026-referral-rewards.sql` : trigger qui donne 100 HTG one-time au parrain quand un filleul complète une commande. + invites au bon moment (post-achat/post-vente) + message WhatsApp. + image OG dédiée `og-image.png` 1200×630.
- **#102** — SEO/AI-SEO : `robots.txt`, `sitemap.xml`, `llms.txt`, 6 landing pages Kreyòl sous `/l/` (contenu unique + JSON-LD), générateur `scripts/gen-landing.mjs`.
- **#103** — Mesure funnel AARRR : `migration-2026-funnel.sql` (`funnel_overview()` dérivée des tables existantes, gratuite, rétroactive) + carte admin « Kwasans — Antònwa AARRR ».

**Décisions de Thrasher :**
- Refactor des sinks XSS en contexte JS (`onclick`) → différé, tracké dans **issue #100**.
- **Ads reportées** (pas d'abonnement payant pour l'instant) → on a fait la mesure gratuite à la place.
- Déploiements Supabase : Thrasher a confirmé qu'il les fait au fur et à mesure.

**À déployer (SQL Editor) — seule action restante côté Thrasher :**
`migration-2026-referral-rewards.sql` et `migration-2026-funnel.sql` (+ vérifier `error-logs`/`promo-hardening` si pas encore faits). Puis payer les 6426 HTG aux vendeurs.

**Note technique récurrente :** après chaque merge (squash ou merge commit), le stop-hook signale le commit de merge créé par GitHub (`noreply@github.com`) comme « unverified ». C'est normal : ce n'est pas un de nos commits, il est déjà sur `main`, on ne le réécrit pas. Nos commits à nous sont bien signés `noreply@anthropic.com`.

**Reste pour plus tard :** Objectif A → refactor XSS JS-context (#100) + passe QA navigateur ; Objectif B → ads + leviers organiques quand budget/envie ; routine advisors Supabase ~1×/semaine.

---

## 2026-07-02 : Objectif B — Mesure du funnel AARRR (gratuit)

- Thrasher a confirmé : **déploiements Supabase déjà faits** (rien en attente de son côté) ; **ads mises de côté** (pas d'abonnement payant pour l'instant).
- Choix : mesurer avant de dépenser. Ajout de `supabase/migration-2026-funnel.sql` — RPC `funnel_overview()` (admin-only, lecture seule) qui calcule tout l'AARRR **à partir des tables existantes** (`profiles`, `orders`, `promo_codes`) : donc rétroactif, aucun pipeline d'events à maintenir, 100% gratuit (pas d'events Vercel qui coûtent).
  - Acquisition : total users, +7j/+30j, acquis par referral.
  - Activation : achtè (≥1 commande), activés (aha = 1ère livraison otp/released/completed), taux signup→achtè.
  - Rétention : repeat buyers (≥2 commandes) + %.
  - Referral : signups parrainés + codes de récompense accordés.
  - Revenue : GMV, net vendeurs, commissions, commandes payées, panier moyen.
- Carte admin « Kwasans — Antònwa AARRR » (`renderFunnelHealth()`) dans l'onglet Verifikasyon, à côté de Sante Sistèm/Escrow (même pattern que `escrow_overview`/`error_overview`).
- Validé : logique testée sur Postgres 16 (chiffres corrects sur jeu de données seed, garde `is_admin` rejette non-admin), 7 blocs JS sans erreur, 12/12 tests.
- Reste sur Objectif B : acquisition payante (ads, reporté pour cause de coût) + leviers organiques.

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
