# Plan QA & Durcissement — Semaine du 1ᵉʳ juillet 2026

> **Contexte** : 29 commits de fonctionnalités livrés en 6 jours (24–30 juin). Avant
> d'ouvrir à de vrais utilisateurs, on valide et on durcit tout ce qui a été livré.
>
> **Objectif** : chaque flux critique testé end-to-end sur le preview Vercel **et**
> couvert par un smoke test qui passe en CI.
>
> **Note paiements** : l'intégration MonCash réelle (Digicel) est **bloquée** faute de
> credentials marchands. On garde le stub (`moncashSendPayout` / `moncashVerifyTransaction`)
> et on le sort du chemin critique cette semaine.

## Stack de priorités

| Prio | Chantier | Definition of Done |
|------|----------|--------------------|
| **P0** | QA end-to-end des flux critiques sur le preview | Chaque flux ci-dessous validé manuellement ; bugs loggués en issues |
| **P1** | Élargir les smoke tests Playwright | Chemins heureux des features clés couverts + CI verte |
| **P2** | Durcir la machine escrow + disputes | Cas limites gérés, aucune transition d'état illégale |
| **P3** | Prépa MonCash (sans creds) | Env vars + structure sandbox prêtes pour le jour J |

---

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
