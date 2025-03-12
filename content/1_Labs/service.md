---
title: 'Créer un Deployment et un Service'
date: 2025-03-12T14:15:26+10:00
draft: false
weight: 12
tags: ["Pod", "hostpath"]
---

Cet exercice vous guide à travers la création d'un Deployment et d'un Service Kubernetes pour déployer et exposer une application `alpaca-prod`.

## Prérequis

* Un cluster Kubernetes fonctionnel.
* `kubectl` configuré pour interagir avec votre cluster.

## Étapes

1.  **Créer le Deployment alpaca-prod :**

Analyser le fichier YAML nommé `7-1-alpaca-prod-readiness.yaml`.

Ce fichier définit un Deployment nommé `alpaca-prod` avec 3 réplicas. Chaque réplica exécute un conteneur `kuard` qui répond  sur le port 8080. Un `readinessProbe` est configuré pour vérifier que les pods sont prêts à recevoir du trafic.

Appliquez le fichier YAML pour créer le Deployment.

{{%expand "Réponse" %}}
```bash
kubectl apply -f 7-1-alpaca-prod-readiness.yaml
```
{{% /expand%}}

Regardez les labels des pods associés à ce déploiment.

{{%expand "Réponse" %}}
```bash
kubectl get pods --show-labels
```
{{% /expand%}}



2.  **Créer un Service pour les pods alpaca-prod :**

En vous référant à la documentation officielle sur les services, créez un fichier YAML nommé `alpaca-prod-service.yaml` qui expose les pods du déploiement ci-dessus. Attention de bien configurer son `selector` avec les labels des pods à exposer. Vous pouvez aussi utiliser `kubectl create service --help`, `kubectl expose --help` et l'option `--dry-run=client -o wide`.

{{%expand "Réponse" %}}
```yaml
apiVersion: v1
kind: Service
metadata:
name: alpaca-prod
spec:
selector:
   app: alpaca
   env: prod
   ver: 1
ports:
   - protocol: TCP
      port: 8080
      targetPort: 5678
```

Ce fichier définit un Service nommé `alpaca-prod` qui sélectionne les pods avec les labels `app: alpaca`, `env: prod`, `ver: 1`. Le Service expose le port 8080, qui redirige le trafic vers le port 8080 des pods.

Appliquez le fichier YAML pour créer le Service :

```bash
kubectl apply -f alpaca-prod-service.yaml
```
{{% /expand%}}


## Vérification

1.  **Vérifier le Deployment :**

Vérifiez que le Deployment est disponible et que tous les réplicas sont prêts.

{{%expand "Réponse" %}}
```bash
kubectl get deployments alpaca-prod
kubectl get pods -l app=alpaca-prod
```
{{% /expand%}}

2.  **Vérifier le Service :**

Vérifiez que le Service a été créé et qu'il expose bien les pods du deploiement `alpaca-prod`.

{{%expand "Réponse" %}}
```bash
kubectl get services alpaca-prod -o wide
kubectl get pods -o wide
# Les ips des endpoints doivent correspondre aux IPs des pods
kubectl get endpoints alpaca-prod
```
{{% /expand%}}
