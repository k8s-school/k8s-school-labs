---
title: 'Rappels jour 2'
date: 2024-05-28T14:15:26+10:00
draft: false
weight: 40
tags: ["docker", "12-facteurs", "conteneurs"]
---

# Kubernetes

## Installation avec kubeadm

## Architecture

### Les noeuds

- kubelet: gestion des pods/conteneurs
- kube-proxy: gère le réseau des services
- CNI: plugin réseau des pods (Calico, Cilium, ...)

### Le control-plane

- etcd: base de données stocke l'état souhaité/courant
- controller: mise en conformité état souhaité/courant
- api-server: point d'entrée unique du cluster
- scheduler: place les pods sur les nodes

### Add ons

- DNS
- Ingress
- Dashboard

## Les objects standards de l'API (ressources)

### Les namespaces

Isolation logique

### Les pods

- Ensemble de conteneurs
- Exposé sur le réseau
- Attacher du stockage

`kubectl exec`

### Les services

- Expose des pods
- Utilise le systèmes des selecteurs/labels
- Service par défaut: clusterIP
- NodePort: expose les applications en dehor du cluster (>30000)

### Les labels

clé-valeur, permet de regrouper/rechercher les objects de l'API standard


{{%expand "Les services" %}}

{{% /expand%}}