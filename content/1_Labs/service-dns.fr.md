---
title: 'Test de résolution DNS et connectivité des Services'
date: 2025-03-12T14:15:26+10:00
draft: false
weight: 35
tags: ["Service", "DNS", "Connectivity"]
---

Cet exercice vous guide à travers les tests de résolution DNS et de connectivité pour les Services Kubernetes en utilisant un pod de test.

## Prérequis

* Un cluster Kubernetes fonctionnel.
* `kubectl` configuré pour interagir avec votre cluster.
* Service `alpaca-prod` déployé (voir exercice précédent sur la création de Deployment et Service).

## Étapes

1. **Créer un pod de test et installer les outils DNS :**

Lancer un pod avec l'image `ubuntu:24.04` et ouvrir un shell interactif à l'intérieur.

{{%expand "Réponse" %}}
```bash
# Option 1: Avec kubectl run
kubectl run test-pod --image=ubuntu:24.04 --rm -it -- bash

# Option 2: Deployment temporaire
kubectl create deployment test-ubuntu --image=ubuntu:24.04 -- sleep 3600
kubectl exec -it deployment/test-ubuntu -- bash
```
{{% /expand%}}

Une fois dans le pod, installer les outils de diagnostic DNS :

{{%expand "Réponse" %}}
```bash
# Mettre à jour les packages et installer les outils DNS
apt update
apt install -y dnsutils

# Vérifier l'installation
which dig
which nslookup
```
{{% /expand%}}

2. **Effectuer une requête DNS pour le service alpaca-prod :**

Lancer une requête DNS pour récupérer l'adresse IP du service `alpaca-prod` :

{{%expand "Réponse" %}}
```bash
# Requête DNS avec nslookup
nslookup alpaca-prod

# Alternative avec dig
dig alpaca-prod

# Vérifier la configuration DNS du pod
cat /etc/resolv.conf
```

Résultat attendu : vous devriez obtenir l'IP du service (Cluster IP) qui correspond à celle visible avec `kubectl get service alpaca-prod`.
{{% /expand%}}

3. **Tester la connectivité avec le service :**

Se connecter à un pod alpaca-prod en utilisant l'adresse IP obtenue ou directement le nom du service :

{{%expand "Réponse" %}}
```bash
# Test de connectivité avec curl (remplacer XXXXX par l'IP du service)
curl http://alpaca-prod:8080

# Alternative avec l'IP directement
curl http://CLUSTER_IP:8080

# Test plus détaillé avec headers
curl -v http://alpaca-prod:8080

# Test de l'endpoint healthcheck si disponible
curl http://alpaca-prod:8080/healthz
```

Résultat attendu : vous devriez recevoir une réponse HTML de l'application kuard.
{{% /expand%}}

## Vérifications supplémentaires

1. **Test de résolution DNS avec FQDN :**

Testez la résolution DNS avec le nom complet du service :

{{%expand "Réponse" %}}
```bash
# Test avec le FQDN complet
nslookup alpaca-prod.default.svc.cluster.local

# Test avec dig pour plus de détails
dig alpaca-prod.default.svc.cluster.local
```
{{% /expand%}}

2. **Vérification des endpoints depuis le pod :**

Examinez la correspondance entre le service et ses endpoints :

{{%expand "Réponse" %}}
```bash
# Depuis une autre session kubectl (pas dans le pod)
kubectl get service alpaca-prod -o wide
kubectl get endpoints alpaca-prod

# Test de connectivité directe vers les endpoints
# (remplacer POD_IP par l'une des IPs des endpoints)
curl http://POD_IP:8080
```
{{% /expand%}}

## Nettoyage

N'oubliez pas de supprimer les ressources de test une fois l'exercice terminé :

{{%expand "Réponse" %}}
```bash
# Supprimer le pod de test (si créé avec deployment)
kubectl delete deployment test-ubuntu

# Optionnel : supprimer le service et le deployment alpaca-prod
kubectl delete service alpaca-prod
kubectl delete deployment alpaca-prod
```
{{% /expand%}}