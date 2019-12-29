---
title: 'API Kubernetes: Mes manifestes YAML ne s’appliquent plus'
date: 2019-12-29T14:15:26+10:00
draft: false
tags: ["kubernetes", "API", "Deprecated"] 
---



**Auteur:** Karim AMMOUS ([LinkedIn](https://www.linkedin.com/in/karim-ammous)). 
**Date:** Dec 29, 2019 · 10 min de lecture

## Introduction
Si vous avez eu le message d'erreur ci-dessous ou un message similaire:

```
$ kubectl apply -f deployment.yaml
error: unable to recognize "deployment.yaml": no matches for kind "Deployment" in version "extensions/v1beta1"
```
ou que les exemples du fameux livre « Kubernetes : Up and Running » ne fonctionnent pas sur votre cluster, cet article devrait vous intéresser.

## Rupture de compatibilité

Certains manifestes YAML pour Kubernetes ne sont plus applicables sur des versions récentes de cluster Kubernetes. Ceci est dû à la suppression des APIs obselètes depuis la version 1.16 sortie en septembre 2019. En effet, quelques Objets Kubernetes ont changé de groupe d’API. A titre d’exemple, `DaemonSet`, `Deployment`, `StatefulSet` et `ReplicaSet` qui étaient servis sous le groupe d’API « extensions/v1beta1 » et « apps/v1beta2 » sont désormais uniquement disponibles sous « apps/v1 » API. La migration s’accompagne parfois par l’ajout/suppression d’attributs. Pour plus de détails sur ce qui changé, l’[article](https://kubernetes.io/blog/2019/07/18/api-deprecations-in-1-16/) posté sur le blog de kubernetes.io est une bonne lecture. On en parle entre autres d'un moyen de conversion automatique (voir paragraphe suivant).

## Migration ou conversion

La conversion des manifestes YAML peut s'effectuer en ligne de commande avec l'outil `kubectl`. La commande se présente comme suit:
```shell
kubectl convert -f <file> --output-version <group>/<version>
```
Appliquée à un ficier YAML décrivant un objet de type `Deployment`, celà donne:

```shell
kubectl convert -f deployment.yaml --output-version apps/v1
```

C’est certainement le moyen le plus rapide pour faire la conversion mais le résultat est à mon avis décevant. Les fichiers YAML résultants sont beaucoup plus verbeux que les fichiers d’origines à cause de l’ajout d’attributs avec les valeurs par défaut. Personnellement, je suis plutôt favorable à ce qu’on prenne connaissance des changements et les opérer manuellement. Cela a pour avantage de maintenir ses manifestes YAML aussi concis et lisibles que possible.

## Examples du livre "Kubernetes: Up And Running" 
Le [dépôt github](https://github.com/kubernetes-up-and-running/examples) avec les exemples du fameux livre « Kubernetes : Up and Running »  n’a pas été mis à jour depuis 2 ans. Plusieurs de ces exemples ne sont plus compatibles. J’ai procédé au fork de dépôt en question et à la mise à jour manuelle de tous les fichiers non compatibles. Le résultat est disponible sur la branche `v1.16`   repo github de [k8s-schoool/examples](https://github.com/k8s-school/examples/tree/v1.16). 
