# /morning

> Commande raccourci pour démarrer ma journée en 30 secondes avec une veille personnalisée par Alita.

---

## Mission

Quand je lance `/morning`, exécute la séquence complète suivante en utilisant la skill **recherche-actualites-contextualisees**.

### Étape 1 : Charger mon contexte

Lis silencieusement :
1. `CLAUDE.md`
2. `context/CONTEXT.md`
3. `context/HISTORY.md`

Pas besoin de me résumer le contexte, je le connais. Charge juste pour bien filtrer la veille.

### Étape 2 : Effectuer la veille du jour

Lance la skill `recherche-actualites-contextualisees` avec ces paramètres par défaut :
- Périmètre : actualités IA, e-commerce / marketplace, et tech en Haïti et pour la diaspora
- Filtre : selon mon contexte chargé
- Format : présentation matinale claire

### Étape 3 : Ajouter le résumé de mon agenda (si possible)

Si un connecteur calendrier (Google Calendar, etc.) est actif :
- Récupère mes événements de la journée
- Présente-les brièvement après la veille

Si aucun connecteur calendrier actif, ne mentionne rien sur l'agenda.

### Étape 4 : Présenter le tout dans un format unique

Format de sortie attendu :

```
☀️ Bonjour Thrasher. Voici ta matinée.

📰 Ta veille du jour
[Résultat de la skill recherche-actualites-contextualisees]

📅 Ton agenda du jour (si connecteur disponible)
[Liste des événements de la journée]

🎯 Ton focus suggéré
[1 phrase qui propose le focus principal de la journée basé sur la veille + agenda + projets en cours]

Bonne journée. Alita est prête à t'aider.
```

---

## Règles importantes

- L'objectif de cette commande, c'est de remplacer 15 minutes de scroll matinal par 30 secondes de lecture utile
- Ne jamais dépasser 1 page de sortie, sinon c'est trop long pour une routine matinale
- Si quelque chose n'est pas disponible (pas de connecteur calendrier par exemple), ne pas le mentionner, juste passer à la section suivante
- Communication en français, tutoiement
- Pas de tirets longs (em dashes)
