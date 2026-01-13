---
title: 'QCM sur les "12 Factors"'
date: 2025-03-11T14:15:26+10:00
draft: false
weight: 220
tags: ["micro-services", "12 factors", "conteneurs", "scalabilité"]
---

Une seule bonne réponse par question.

## I. Codebase

1. Quelle est la règle fondamentale concernant la gestion de la base de code dans une application 12 Factors ?
   - A) Il doit y avoir un seul dépôt de code partagé entre plusieurs applications distinctes.
   - B) Chaque application a son propre dépôt et peut être déployée indépendamment.
   - C) Une application peut avoir plusieurs dépôts avec des versions différentes en production.

2. Dans une architecture 12 Factors, comment sont gérées les branches de la base de code ?
   - A) Chaque environnement (dev, test, prod) a sa propre branche permanente.
   - B) Les branches sont utilisées pour le développement et fusionnées dans la branche principale.
   - C) Chaque développeur a son propre dépôt et fusionne dans une branche commune.

{{%expand "Réponses" %}}
1-B, 2-B
{{% /expand%}}

---

## II. Dépendances

1. Comment une application 12 Factors doit-elle gérer ses dépendances ?
   - A) Elles doivent être installées globalement sur le système hôte.
   - B) Elles doivent être déclarées explicitement dans un fichier de gestion de dépendances.
   - C) Elles doivent être intégrées directement dans le code source.

2. Quel est l'outil recommandé pour gérer les dépendances dans une application 12 Factors ?
   - A) Un fichier de configuration spécifique (ex : `requirements.txt`, `package.json`, `Dockerfile`).
   - B) Un fichier texte sans format particulier listant les versions des dépendances.
   - C) Une installation manuelle sur chaque serveur.

{{%expand "Réponses" %}}
1-B, 2-A
{{% /expand%}}

---

## III. Configuration

1. Où une application 12 Factors doit-elle stocker sa configuration ?
   - A) Dans le code source.
   - B) Dans l'environnement (variables d'environnement, configmap)
   - C) Dans un fichier de configuration versionné avec le code.

2. Pourquoi est-il déconseillé de stocker la configuration dans le code source ?
   - A) Parce que cela complique le développement.
   - B) Parce que cela empêche la scalabilité.
   - C) Parce que cela pose un risque de sécurité et de portabilité.

{{%expand "Réponses" %}}
1-B, 2-C
{{% /expand%}}

---

## IV. Backing Services

1. Comment les services externes (base de données, cache, etc.) doivent-ils être traités ?
   - A) Comme des ressources interchangeables accessibles via des URLs ou credentials stockés dans l'environmment (variable d'environnement, fichier de configuration)
   - B) Comme des composants fixes du code source.
   - C) Comme des services internes intégrés dans l'application.

2. Pourquoi est-il important de traiter les services backing comme des ressources attachées ?
   - A) Pour permettre leur remplacement facile sans changer le code.
   - B) Pour éviter la duplication de code.
   - C) Pour s'assurer qu'ils fonctionnent uniquement sur un serveur spécifique.

{{%expand "Réponses" %}}
1-A, 2-A
{{% /expand%}}

---

## V. Build, Release, Run

1. Quelles sont les trois étapes distinctes du cycle de vie d’une application 12 Factors ?
   - A) Développement, test, production.
   - B) Build, Release, Run.
   - C) Commit, Merge, Deploy.

2. Pourquoi séparer les étapes de Build, Release et Run ?
   - A) Pour garantir la reproductibilité des déploiements.
   - B) Pour accélérer l’exécution du code.
   - C) Pour réduire la consommation de ressources.

{{%expand "Réponses" %}}
1-B, 2-A
{{% /expand%}}

---

## VI. Processus

1. Comment une application 12 Factors doit-elle être exécutée ?
   - A) En tant qu’ensemble de processus statiques.
   - B) En tant que série de processus indépendants et sans état.
   - C) En tant qu’un seul processus monolithique.

2. Pourquoi privilégier des processus sans état ?
   - A) Pour simplifier le scaling horizontal.
   - B) Pour améliorer la rapidité du code.
   - C) Pour éviter les erreurs de compilation.

{{%expand "Réponses" %}}
1-B, 2-A
{{% /expand%}}

---

## VII. Liaison de ports

1. Comment une application 12 Factors expose-t-elle ses services ?
   - A) Par un port spécifié dans le code source ou dans la configuration
   - B) En se reliant directement aux services internes du serveur hôte.
   - C) Par des fichiers de configuration manuels.

2. Pourquoi utiliser la liaison de ports ?
   - A) Pour rendre l’application plus portable et accessible par le réseau
   - B) Pour limiter l’accès aux services.
   - C) Pour améliorer la performance.

{{%expand "Réponses" %}}
1-A, 2-A
{{% /expand%}}

---

## VIII. Concurrence

1. Comment une application 12 Factors gère-t-elle la concurrence ?
   - A) En utilisant des threads internes.
   - B) En scalant horizontalement par duplication de processus.
   - C) En augmentant la puissance d’un serveur unique.

2. Pourquoi est-il préférable de scaler horizontalement ?
   - A) Pour une meilleure résilience et flexibilité (haute-disponibilité et tolérance aux pannes)
   - B) Pour réduire la consommation d’énergie.
   - C) Pour éviter d’avoir plusieurs instances.

{{%expand "Réponses" %}}
1-B, 2-A
{{% /expand%}}

---

## IX. Disposability

1. Quelle caractéristique doit avoir un processus 12 Factors pour être disposable ?
   - A) Il doit démarrer et s’arrêter rapidement.
   - B) Il doit être long à initialiser mais stable.
   - C) Il doit nécessiter une configuration manuelle avant chaque exécution.

2. Pourquoi est-ce important ?
   - A) Pour améliorer la résilience et la scalabilité.
   - B) Pour éviter les erreurs de compilation.
   - C) Pour garantir une exécution plus rapide du code.

{{%expand "Réponses" %}}
1-A, 2-A
{{% /expand%}}

---

## X. Parité développement/production

1. Pourquoi minimiser les différences entre dev et prod ?
   - A) Pour éviter les surprises en production.
   - B) Pour limiter les mises à jour.
   - C) Pour rendre le développement plus lent.

2. Comment assurer cette parité ?
   - A) En utilisant les mêmes dépendances et environnements.
   - B) En développant directement en production.
   - C) En limitant les mises à jour en développement.

{{%expand "Réponses" %}}
1-A, 2-A
{{% /expand%}}

---

## XI. Logs

1. Comment une application 12 Factors doit-elle gérer les logs ?
   - A) En les stockant localement sur le serveur.
   - B) En les écrivant sur stdout/stderr pour qu’un agrégateur les collecte.
   - C) En les insérant dans une base de données interne.

2. Pourquoi utiliser stdout/stderr ?
   - A) Pour une meilleure gestion et analyse centralisée.
   - B) Pour limiter la quantité de logs.
   - C) Pour stocker directement sur le serveur.

{{%expand "Réponses" %}}
1-B, 2-A
{{% /expand%}}

---

## XII. Tâches Admins

1. Comment exécuter les tâches administratives ?
   - A) En les intégrant directement dans le code principal.
   - B) En les exécutant sous forme de processus éphémères, via des conteneurs
   - C) En les exécutant manuellement sur le serveur.

2. Pourquoi utiliser des processus éphémères conteneurisés ?
   - A) Pour éviter la dépendance à l'infrastructure
   - B) Pour améliorer la sécurité.
   - C) Pour rendre l’application plus rapide.

{{%expand "Réponses" %}}
1-B, 2-A
{{% /expand%}}
