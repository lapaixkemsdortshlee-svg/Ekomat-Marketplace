# CONTEXT.md

> Mon contexte personnel et professionnel pour Alita, mon assistant IA dédié à AyitiMarket.
> Ce fichier est chargé au début de chaque session. Il est mis à jour au fil du temps par Alita.

---

## Qui je suis

- **Prénom :** Thrasher
- **Ville / Pays :** Delmas, Haïti
- **Situation actuelle :** Fondateur d'AyitiMarket à plein temps, étudiant en anglais dans une école de langue, et graphic designer.
- **Profil dominant :** Entrepreneur (avec une casquette étudiant et une casquette créatif / designer)

---

## Ce que je fais

### Activité principale

Je construis **AyitiMarket**, une marketplace multi-vendeurs pensée pour la communauté haïtienne, en Haïti et dans la diaspora. Elle permet d'acheter et de vendre facilement en ligne, avec une interface entièrement en Kreyòl.

### Détails (profil entrepreneur)

- **Activité :** Marketplace en ligne pour Haïti et la diaspora.
- **Modèle économique :** Frais de plateforme (commission) sur les transactions, sécurisées par un système d'escrow (l'argent est bloqué jusqu'à la livraison).
- **Clients types :** Acheteurs et vendeurs haïtiens, plus la diaspora qui achète ou soutient des vendeurs locaux.

---

## Mes objectifs

### Objectifs déjà ATTEINTS ✅

- **Objectif A - QA & Durcissement** : flux escrow testés E2E, RLS/RPC durcis, audit sécurité complet traité (XSS, search_path, least-privilege) - advisors Supabase : zéro alerte non intentionnelle.
- **Objectif B - Croissance / Acquisition** : parrainage bout-en-bout (crédit parrain), SEO + AI-SEO (sitemap, llms.txt, landing pages Kreyòl), mesure du funnel AARRR. Reste seulement les ads (reportées, coût).
- **Objectif C - Observabilité escrow** : monitoring temps réel, réconciliation, alerting, error tracking - clôturé.
- **Déploiement mobile prêt** : app packageable PWA → Android (Google Play) et iOS (App Store) via Capacitor. Guide complet : `docs/DEPLOYMENT-GUIDE.md` (v2.0.0 MVP Final, `com.ayitidigital.ayitimarket`).

### Objectifs court terme (3 à 6 mois)

- Ne jamais arrêter de progresser sur AyitiMarket, pour en faire une entreprise fiable, au service de tous les Haïtiens.
- **Publier l'app sur les stores** : builds Android (.aab) + iOS (.ipa), comptes Google Play ($25) et Apple Developer ($99/an), soumission (voir `docs/DEPLOYMENT-GUIDE.md`).
- Brancher les vrais paiements MonCash (bloqué tant que les credentials Digicel ne sont pas obtenus).
- Lancer l'acquisition payante (ads Meta/Google) quand le budget le permet + activer Leaked Password Protection (plan pro).

### Objectifs long terme (1 à 3 ans)

- Faire d'AyitiMarket la marketplace de référence en Haïti et pour la diaspora.

---

## Mes projets en cours

- **AyitiMarket** (unique projet actif, tout mon focus est dessus).

---

## Mes outils et préférences

### Outils que j'utilise au quotidien

- GitHub (code et suivi via PR / issues)
- Supabase (base de données, RLS, edge functions)
- Vercel (déploiement et previews)
- Firebase Cloud Messaging (notifications push)
- MonCash / Digicel (paiements, intégration en attente de credentials)
- Claude Code (développement assisté)
- Outils de design graphique (casquette designer)

### Style de communication préféré

Direct, efficace et précis, mais bien détaillé quand il le faut. Français, tutoiement, sans tirets longs.

### Domaine où j'ai besoin du plus d'aide

Un mix : stratégie produit, développement, croissance / marketing, et productivité.

---

## Notes importantes

> Cette section se remplit au fil du temps avec les éléments de contexte qui émergent naturellement dans mes sessions.

- **Vision IA-first :** tout doit reposer sur l'IA. Alita est au centre du projet, pas un outil secondaire.
- **Veille par défaut (`/morning`) :** IA, e-commerce / marketplace, et tech en Haïti et pour la diaspora.
- **Règles techniques AyitiMarket à toujours respecter :** architecture single-file (`index.html`), chaînes de caractères en Kreyòl, soft-delete, machine à états escrow via RPC. Le workspace Alita ne doit jamais vivre dans `index.html`.
- **Arsenal de skills étendu et auto-extensible (depuis 2026-07-02) :** en plus des skills de base, on a une suite ASO (39 skills) pour la sortie stores, `markitdown` (fichiers vers Markdown), `claude-council` (stress-test de décisions, sans clé API), et un `deep-research` maison (recherche multi-sources via WebSearch/WebFetch, gratuit). `find-skills` permet d'en chercher/installer de nouveaux à la demande. Principe retenu : privilégier les skills gratuits qui tournent dans Claude Code, écarter les apps autonomes qui exigent des clés API payantes (Thrasher reste économe).
