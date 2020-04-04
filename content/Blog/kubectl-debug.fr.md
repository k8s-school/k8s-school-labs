---
title: "kubectl debug tutorial"
date: 2020-04-06
draft: true
weight: 1
tags: ["kubernetes", "kubectl", "debug"] 
---
**Written by:** Karim AMMOUS ([LinkedIn](https://www.linkedin.com/in/karim-ammous)). 
**Date:** April 06, 2020 · 8 min read

## Introduction

L'utilitaire de débogage a été débattu depuis longtemps au sein de la SIG-CLI. Tout s'est accéléré avec l’avènement de la notion de containers éphémères. Il devient ainsi plus facile d’assister les développeurs avec des outils basés sur la commande `kubectl exec`.

## Rôle
La version 1.18 du CLI `kubectl` embarque la toute première version d'un outil de débogage. Cette commande permet d'attacher un container éphémère à un POD en exécution pour faire du débogage.

## Installation

Le tableau ci-dessous liste quelques combinaisons de versions de k8s client et server avec en dernière colonnes le support (ou non) de la commande de debug.
| Version client  | Version serveur | kubectl debug|
| :------:| :-----------: | :----------: |
| 1.17    | 1.18  |NON|
| 1.18    | 1.17  |**OUI**|
| >=1.18    | >=1.18 |**OUI**|


### Client

Les insctructions qui suivent permettent l'installation de la version v1.18 du CLI `kubectl` sur un linux 64 bits: 
```bash
KUBECTL_BIN="/usr/local/bin/kubectl"
K8S_VERSION_SHORT="1.18"
K8S_VERSION_LONG=$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable-$K8S_VERSION_SHORT.txt)
curl -Lo /tmp/kubectl https://storage.googleapis.com/kubernetes-release/release/"$K8S_VERSION_LONG"/bin/linux/amd64/kubectl
chmod +x /tmp/kubectl
sudo mv /tmp/kubectl "$KUBECTL_BIN"
source <(kubectl completion bash)
```

### Server
Pour créer rapidement un cluster kubernetes avec comme seule exigence un docker-engine, j'ai choisi la solution [kind](kind.sigs.k8s.io/). D'autres solutions s'offrent à nous telles que [k3s](https://k3s.io) ou [microk8s](https://microk8s.io/). La suite de l'article ne dépend pas de la solution choisie.

D'abord, on commence par installer la dernier version du CLI de `kind` (v0.7.0 au moment d'écriture de cet article).
```bash
KIND_BIN="/usr/local/bin/kind"
KIND_VERSION="v0.7.0"
curl -Lo /tmp/kind https://github.com/kubernetes-sigs/kind/releases/download/"$KIND_VERSION"/kind-linux-amd64
chmod +x /tmp/kind
sudo mv /tmp/kind "$KIND_BIN"
```
Ensuite, on lance la commande de création du cluster `kind`. Par défaut, la version v0.7.0 de `kind` crée un cluster kubernetes en v1.17. Nous ajoutons donc l'option `--image` pour forcer l'utilisation de l'image correspondant à la version 1.18 de kubernetes.
```bash
kind create cluster --image kindest/node:v1.18.0@sha256:0e20578828edd939d25eb98496a685c76c98d54084932f76069f886ec315d694
```

## Utilisation
Cette commande étant encore en alpha, elle n’est donc pas disponible par défaut en tant commande directement accessible sous kubectl. Elle est proposée comme sous-commande de `alpha` et est appelé `debug`. On peut avoir de l'aide spécifique avec l'option `--help` comme suit:
``` 
kubectl alpha debug --help
```

## Références
- [Issue #45922](https://github.com/kubernetes/kubernetes/issues/45922)
- [Pull Request #88004](https://github.com/kubernetes/kubernetes/pull/88004)
- [KEP 20190805 - Kubernetes Enhancement Proposal](https://github.com/kubernetes/enhancements/blob/master/keps/sig-cli/20190805-kubectl-debug.md)