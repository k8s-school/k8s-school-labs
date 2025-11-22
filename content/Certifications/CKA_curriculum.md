---
title: 'CKA: compétences nécessaires'
date: 2025-09-21T14:15:26+10:00
draft: false
weight: 40
tags: ["kubernetes", "CKAD"]
---

Les attentes sont recensées dans le [CKA Curriculum](https://github.com/cncf/curriculum/tree/master). Attention de bien regarder la version à jour.

Voici le contenu de la version `1.30` du Curriculum:

## Contenu du Curriculum

*   **Déploiement d'applications (15%)**
    *   Compréhension des principes de base de Kubernetes
    *   Déploiement et mise à jour des applications
    *   Utilisation des ConfigMaps et Secrets pour configurer les applications
    *   Techniques de gestion des ressources et de leur impact sur les Pods
*   **Services et Réseau (20%)**
    *   Compréhension du réseau des Pods
    *   Utilisation de services Kubernetes :
        *   ClusterIP, NodePort et LoadBalancer
        *   Ingress controllers et Ingress ressources
    *   Configuration et utilisation de CoreDNS
*   **Stockage (10%)**
    *   Compréhension des classes de stockage et des volumes persistants (PVs/PVCs)
    *   Compréhension des type de volumes (RWO RWM), des mode d'accès et des politiques de rétention des données.
    *   Configuration des applications avec stockage persistant
*   **Architecture du Cluster et Configuration (25%)**
    *   Installation et configuration d'un cluster Kubernetes
    *   Gestion d'un cluster Kubernetes hautement disponible
    *   Prise en charge de l'infrastructure sous-jacente pour déployer un cluster Kubernetes
    *   Mise à jour de version sur un cluster Kubernetes en utilisant Kubeadm
    *   Sauvegarde et restauration des données d'`etcd`
    *   Contrôle d'accès basé sur les rôles (RBAC)
*   **Dépannage (10%)**
    *   Dépannage des erreurs d'application
    *   Dépannage des échecs des composants du cluster

Le programme de la formation s'appuie sur ce curriculum.
