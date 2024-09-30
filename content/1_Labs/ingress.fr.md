---
title: 'Paramétrer les Ingresses'
date: 2024-07-11T14:15:26+10:00
draft: true
weight: 150
tags: ["Kubernetes", "Ingress", "nginx-controller", "CKA"]
---

## Prerequis

- Lancer la toolbox: `ktbx desk`

## Installer une application dans Kubernetes

- Créez un `namespace` `ingress-app-<ID>`
- Se placer dans ce `namespace` avec `kubens` ou `kubectl`

{{%expand "Réponse" %}}
```shell
kubectl create ns ingress-app
# Cette commande sera très utile durant la CKA
kubectl config set-context $(kubectl config current-context) --namespace=ingress-app
kubectl create deployment web -n "ingress-app" --image=gcr.io/google-samples/hello-app:1.0
kubectl expose deployment web -n "ingress-app" --port=8080
kubectl  wait -n "ingress-app" --for=condition=available deployment web
```
{{% /expand%}}

## Exposer l'application via Ingress

Vérifier que l'`ingress-controller` est bien présent dans le cluster et lister les classes ingress disponibles.

{{%expand "Réponse" %}}
```shell
kubectl get all -n ingress-nginx
kubectl get ingressclasses
```
{{% /expand%}}

Expliquer pourquoi un service du ingress est en état `Pending` et proposer une solution.

{{%expand "Réponse" %}}
```shell
Le service est de type `LoadBalancer` et `kind` ne supporte pas ce type de service, il faudrait changer le type du service en `NodePort`.
```
{{% /expand%}}

Utiliser la commande `kubectl create ingress -h` ou la [documentation officielle](https://kubernetes.io/docs/concepts/services-networking/ingress/) pour créer une règle ingress qui expose l'application

{{%expand "Solution en ligne" %}}
https://raw.githubusercontent.com/k8s-school/demo-nginx-controller/refs/heads/main/example-ingress.yaml
{{% /expand%}}

## Accès à la démo en ligne

Une démo avec le script d'installation complet est également disponible: [Démo Ingress](https://github.com/k8s-school/demo-nginx-controller.git)
