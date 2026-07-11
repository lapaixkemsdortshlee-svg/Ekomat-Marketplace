# Memory inbox — leçons en attente de memory_save

> File d'attente pour agentmemory. Quand le moteur est disponible (il ne l'était
> pas dans la session du 2026-07-11 : binaire iii-engine absent + téléchargement
> GitHub Releases bloqué par la politique réseau), seeder chaque entrée avec
> `memory_save` (project: ayitimarket) puis la retirer d'ici.

## 1. CodeQL baseline sur index.html (2026-07-11)

- content: "CodeQL re-signale les alertes baseline d'index.html (fichier ~850 Ko) comme « new alerts » sur TOUT gros diff qui le touche, même un pur remplacement de texte (vu sur PR #99, #151, #152 — son résumé dit « code changes were too large »). Méthode de preuve avant de conclure au faux positif : normaliser les tokens variables du diff (sed marque/version) puis vérifier que chaque ligne +/- s'apparie exactement (sort | uniq -c, tout à 2) → zéro logique JS changée. Documenter en commentaire de PR et merger."
- concepts: codeql-baseline-faux-positif, index-html-gros-diff, preuve-diff-symetrique, ci-pr-rouge
- files: index.html

## 2. Assets de marque = fichiers de Thrasher (2026-07-11)

- content: "Les assets de marque Ekomat (logo wordmark, mark « e » à anse, icônes, favicon, og-image, palette BRAND.md) sont les fichiers créés par Thrasher (designer). Ne JAMAIS les recréer ou les approximer (veto explicite « pa defòme li » quand Alita a tenté une recréation SVG depuis des captures) : demander les originaux (upload GitHub). Les dérivés mécaniques de SES fichiers (resize, crop, pose sur fond cream, conversion ico) sont OK. Fichiers canoniques dans brand/."
- concepts: assets-marque-thrasher, logo-ekomat-originaux, pas-de-recreation, brand-folder
- files: brand/logo-ekomat.png, brand/mark-cream.png, BRAND.md
