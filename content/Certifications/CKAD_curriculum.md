---
title: 'CKAD: compétences nécessaires'
date: 2025-09-21T14:15:26+10:00
draft: false
weight: 30
tags: ["kubernetes", "CKAD"]
---

Les attentes sont recensées dans le [CKAD Curriculum](https://github.com/cncf/curriculum/tree/master). Attention de bien regarder la version à jour.

Voici le contenu de la version `1.34` du Curriculum:

# Programme CKAD

## 20% - Conception et Construction d'Applications

- Définir, construire et modifier des images de conteneurs
- Choisir et utiliser la bonne ressource de charge de travail (Deployment, DaemonSet, CronJob, etc.)
- Comprendre les modèles de conception de Pods multi-conteneurs (par exemple sidecar, init et autres) TODO
- Utiliser des volumes persistants et éphémères

## 25% - Environnement, Configuration et Sécurité des Applications

- Découvrir et utiliser les ressources qui étendent Kubernetes (`CRD`, `Operators`)
- Comprendre l'authentification, l'autorisation et le contrôle d'admission
- Comprendre les `requests`, `limits` et `quotas`
- Définir les exigences en ressources
- Comprendre les ConfigMaps
- Créer et consommer des Secrets
- Comprendre les ServiceAccounts
- Comprendre la sécurité des applications (SecurityContexts, Capabilities, etc.)

## 20% - Déploiement d'Applications

- Utiliser les primitives Kubernetes pour implémenter des stratégies de déploiement courantes (par exemple blue/green ou canary)
- Comprendre les Deployments et comment effectuer des mises à jour progressives (rolling updates)
- Utiliser le gestionnaire de paquets Helm pour déployer des paquets existants TODO
- Kustomize TODO

## 15% - Observabilité et Maintenance des Applications

- Comprendre les dépréciations d'API TODO
- Implémenter des sondes et des vérifications de santé (health checks)
- Utiliser les outils CLI intégrés pour surveiller les applications Kubernetes
- Utiliser les journaux de conteneurs
- Débogage dans Kubernetes

## 20% - Services et Réseaux

- Démontrer une compréhension de base des NetworkPolicies
- Fournir et dépanner l'accès aux applications via les services
- Utiliser les règles Ingress pour exposer les applications

Le programme de la formation s'appuie sur ce curriculum.


TODO
kuard image no more available