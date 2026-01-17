---
title: 'Présentation'
date: 2024-09-21T14:15:26+10:00
draft: false
weight: 1
tags: ["kubernetes", "CKA", "CKAD"]
---

## Les certifications Kubernetes

La `Cloud Native Computing Foundation` propose trois certifications majeures pour valider vos compétences et votre expertise dans la gestion des clusters Kubernetes. Ces certifications sont reconnues mondialement et permettent de valider vos connaissances auprès des recruteurs et des entreprises.

### **CKA (Certified Kubernetes Administrator)**

La **CKA** est destinée aux administrateurs de systèmes qui souhaitent démontrer leur maîtrise de l'administration d'un cluster Kubernetes. Elle couvre les aspects essentiels de la gestion et de l'exploitation d'un cluster Kubernetes.

### **CKAD (Certified Kubernetes Application Developer)**

La **CKAD** est adaptée aux développeurs qui souhaitent prouver leur capacité à concevoir, créer et déployer des applications cloud-native sur Kubernetes. Cette certification se concentre sur les compétences de développement et l'utilisation de Kubernetes pour exécuter des applications.

### **CKS (Certified Kubernetes Security Specialist)**

La **CKS** est une certification avancée orientée sécurité. Elle est idéale pour les professionnels Kubernetes qui veulent approfondir leur expertise en sécurisant les clusters et les applications Kubernetes, y compris la configuration de réseau, des politiques de sécurité, et la gestion des vulnérabilités.

## Déroulement d’une certification

Les certifications Kubernetes sont des examens pratiques en ligne qui nécessitent l'utilisation d'un terminal pour résoudre des scénarios réels. Vous aurez accès à un cluster Kubernetes et devrez accomplir plusieurs tâches en un temps limité.

### **Structure de l'examen**

- **Durée :** 2 heures (environ).
- **Mode :** 100% en ligne.
- **Questions :** 15 à 20 scénarios à résoudre sur un cluster Kubernetes réel.
- **Format :** Examen dans un terminal embarqué dans un navigateur, avec accès à la documentation officielle Kubernetes (https://kubernetes.io/).

### **Préparation**

Il est recommandé d’avoir une bonne connaissance des outils en ligne de commande (CLI) et de Kubernetes avant de se lancer dans les certifications. L’examen est très orienté vers la pratique, donc il est essentiel de s'exercer avec des clusters Kubernetes.

## L’environnement

L'environnement d'examen est un espace sécurisé, où vous aurez accès à un terminal pour interagir avec un cluster Kubernetes. Voici quelques éléments à connaître avant de passer l'examen :

- **Accès à la documentation officielle :** Vous avez le droit de consulter la documentation Kubernetes officielle pendant l’examen. Il est crucial de savoir naviguer rapidement dans la documentation.
- **Restrictions :** Vous ne pouvez pas utiliser des outils locaux sur votre machine, ni copier/coller des scripts externes. Tout doit être fait dans l’environnement fourni.
- **Supervision en temps réel :** Une personne vous surveillera via une webcam tout au long de l'examen pour garantir son intégrité.

## Les compétences nécessaire pour la CKA (Certified Kubernetes Administrator)

Les attentes sont recensées dans le [CKA Curriculum](https://github.com/cncf/curriculum/tree/master). Attention de bien regarder la version à jour.

Voici le contenu de la version `1.30` du Curriculum:

**Contenu du Curriculum**
==========================

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
