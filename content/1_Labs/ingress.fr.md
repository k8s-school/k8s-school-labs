---
title: 'Paramétrer les Ingresses'
date: 2024-07-11T14:15:26+10:00
draft: false
weight: 45
tags: ["Kubernetes", "Ingress", "nginx-controller", "CKA"]
---

## Prerequis

- Lancer la toolbox: `ktbx desk`

## Installer une application dans Kubernetes

- Créez un `namespace` `ingress-app-<ID>`
- Se placer dans ce `namespace` avec `kubens` ou `kubectl`

{{%expand "Réponse" %}}
```shell
namespace="ingress-app"
kubectl create ns $namespace
# Cette commande sera très utile durant la CKA
kubectl config set-context --current --namespace=$namespace
kubectl create deployment web -n "$namespace" --image=gcr.io/google-samples/hello-app:1.0
kubectl expose deployment web -n "$namespace" --port=8080
kubectl  wait -n "$namespace" --for=condition=available deployment web
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

Utiliser la commande `kubectl create ingress -h` ou la [documentation officielle](https://kubernetes.io/docs/concepts/services-networking/ingress/) pour créer une règle ingress qui expose l'application.
L'application sera joignable depuis l'extérieur du cluster avec la commande: `curl http://hello-world.info:<ingress-nodeport>/myapp-<ID>`

{{%expand "Solution en ligne" %}}
https://raw.githubusercontent.com/k8s-school/demo-nginx-controller/refs/heads/main/example-ingress.yaml
{{% /expand%}}

## Accès à la démo en ligne

Une démo avec le script d'installation complet est également disponible: [Démo Ingress](https://github.com/k8s-school/demo-nginx-controller.git)
