---
title: 'Accès aux labs'
date: 2024-05-22T14:15:26+10:00
draft: false
weight: 20
tags: ["kubernetes", "ktbx", "pre-requis"]
---

## Accés SSH

Le mot de passe vous sera transmis par le formateur:
```bash
ssh k8s<ID>@<serverip>
```

## Accés Kubernetes

Le fichier `kubeconfig` permet de se connecter au serveur Kubernetes.

```bash
mkdir -p ~/.kube
cp /tmp/config $HOME/.kube/config
chmod 600 $HOME/.kube/config

# Lancer k8s-toolbox de manière interactive
ktbx desk

# Vérifier le statut de Kubernetes
kubectl cluster-info

# Vérifier le status des noeuds
kubectl get nodes

# Creer un namespace
kubectl create namespace <ID-first-name>

# Changer le namespace actif du contexte courant
kubens <ID-first-name>

# Creer un pod
# use "kubectl run --help" to retrieve the correct command
kubectl run <your-pod> ???

# ajouter un label sur le pod
kubectl label pod <your-pod> tutorial=true
```

## Télécharger les labs

Un fois dans la toolbox, lancer une des des commandes ci-dessous pour télécharger votre lab:

```shell
# Lab de la formation "CKA"
git clone https://github.com/k8s-school/CKA-prep

# Lab de la formation "Les fondamentaux Kubernetes"
git clone https://github.com/k8s-school/k8s-school

# Lab de la formation "Kubernetes avancé"
git clone https://github.com/k8s-school/k8s-advanced

# Lab de la formation "Openshift avancé"
git clone https://github.com/k8s-school/openshift-advanced
```
