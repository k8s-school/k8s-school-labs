---
title: 'Pre-requis'
date: 2024-05-22T14:15:26+10:00
draft: false
weight: 1
tags: ["kubernetes", "ktbx", "pre-requis"]
---

# La plateforme de cours

## Accès aux serveur des labs en SSH

Le mot de passe vous sera transmis par le formateur:
```bash
ssh k8s<ID>@<serverip>
```

## Accès à Kubernetes

Le fichier `kubeconfig` permet de se connecter au serveur Kubernetes.

```bash
mkdir -p ~/.kube
cp /tmp/config $HOME/.kube/config
chmod 600 $HOME/.kube/config

# Lancer k8s-toolbox de manière interactive
ktbx desk

# Vérifier le statut des noeuds
kubectl get pods
kubectl get nodes

# Creer un namespace
kubectl create namespace <ID-first-name>

# Changer le namespace actif du contexte courant
kubens <ID-first-name>

# Creer un pod
# use "kubectl run --help" to retrieve the correc command
kubectl run <your-pod> ???

# ajouter un label sur le pod
kubectl label pod <your-pod> tutorial=true

# Lancer un pod Ubuntu depuis Docker Hub
kubectl run -it --rm shell --image=ubuntu --restart=Never -- date

# Lancer un pod depuis gcr.io
kubectl run shell --image=gcr.io/kuar-demo/kuard-amd64:1 --restart=Never
# Ouvrir un shell dedans et quitter
kubectl exec -it shell -- ash
exit
kubectl delete pod shell
```

## Pré-requis

### Configuration de la machine locale

- Ubuntu LTS est recommandé
- 8 coeurs, 16 Go de RAM, 30Go pour la partition hébergeant les entités docker (images, volumes, conteneurs etc). Utiliser la commande `df` comme ci-dessous pour trouver sa taille.
```bash
sudo df -sh /var/lib/docker # ou /var/snap/docker/common/var-lib-docker/
```
- Accès internet **sans proxy**
- Accès `sudo`
- Installer les dépendances ci-dessous:
```shell
sudo apt-get install curl docker.io git vim

# puis ajouter l'utilisateur actuel au groupe docker
sudo usermod -a -G docker $USER
# ou redémarrer la session gnome
newgrp docker
```

### Configurer k8s-toolbox (client et outils Kubernetes):

Suivre les instructions officielles sur https://github.com/k8s-school/ktbx



- Lancer k8s-toolbox de manière interactive:

```shell
ktbx desk
```

puis valider que Kubernetes fonctionne:
```shell

```

## Jouer avec les exemples

Récupérer les exemples, démos et exercices de k8s-school en lançant:
```shell
clone-school.sh
# Durant la formation nous allons jouer avec kubectl et ces fichiers yaml :-)
```