# Workspace History

> Journal chronologique de toutes les sessions et décisions importantes.
> Le plus récent en haut. Mis à jour automatiquement par Alita.
>
> **Comment ça marche :** Après une session importante, ou quand je raconte un changement significatif, Alita ajoute une entrée ici. Je n'ai pas à écrire ce fichier manuellement.

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
