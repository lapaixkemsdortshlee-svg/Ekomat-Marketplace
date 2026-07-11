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

## 3. Rituel skills + checklist obligatoire (2026-07-11)

- content: "Thrasher a recadré Alita DEUX FOIS le 2026-07-11 sur la même erreur : exécuter tête baissée sans activer les skills installés ni afficher de checklist. Règle durable (gravée dans CLAUDE.md) : avant toute tâche non triviale, activer les skills pertinents (typiquement 3 à 10 cumulés, ex. ayitimarket + quick-recap + skills métier), afficher une checklist visible des étapes, et nommer chaque skill activé en une ligne. Il a investi ~150 skills pour la puissance d'exécution : les négliger le déçoit plus qu'une erreur technique."
- concepts: rituel-skills-checklist, recadrage-methode-thrasher, activation-skills-multiple, discipline-execution
- files: CLAUDE.md

## 5. db-migrate échoue après reset du mot de passe DB (2026-07-11, récurrent)

- content: "Le workflow db-migrate.yml échoue à `supabase db push` avec `password authentication failed for user postgres (SQLSTATE 28P01)` quand le secret GitHub SUPABASE_DB_PASSWORD est périmé — typiquement après que Thrasher a reset le mot de passe DB dans Supabase (le `supabase link` passe quand même car il utilise SUPABASE_ACCESS_TOKEN, seul le push utilise le mot de passe DB). Déjà vu le 2026-07-05. Symptôme trompeur : list_migrations peut montrer une migration antérieure appliquée (poussée AVANT le reset) alors que la nouvelle échoue. Fix (Thrasher seul) : Supabase Settings→Database reset le mot de passe en le tapant, puis GitHub repo Settings→Secrets→Actions mettre SUPABASE_DB_PASSWORD = cette valeur exacte (PAS anon/service_role), puis re-run le workflow. Contournement agent quand une migration approuvée+validée+idempotente est bloquée par ça : l'appliquer via mcp Supabase apply_migration (elle reste cohérente, le push la sautera ensuite). Le GitHub MCP ne peut pas re-run un workflow (403)."
- concepts: db-migrate-password-auth-failed, supabase-db-password-secret-perime, reset-mot-de-passe-db, apply-migration-contournement, pipeline-migrations-casse
- files: .github/workflows/db-migrate.yml
