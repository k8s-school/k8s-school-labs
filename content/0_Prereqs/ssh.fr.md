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

Voici également quelques exemples supplémentaires:

```shell
# Lancer un pod Ubuntu depuis Docker Hub
kubectl run -it --rm shell --image=ubuntu --restart=Never -- date

# Lancer un pod depuis gcr.io
kubectl run shell --image=gcr.io/kuar-demo/kuard-amd64:1 --restart=Never
# Ouvrir un shell dedans et quitter
kubectl exec -it shell -- ash
exit
kubectl delete pod shell
```
