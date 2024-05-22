---
title: 'Bienvenue!'
date: 2024-05-22T14:15:26+10:00
draft: false
weight: 1
tags: ["kubernetes", "ktbx", "pre-requis"]
---

[<img src="http://k8s-school.fr/images/logo.svg" alt="Logo de K8s-school, expertise et formation Kubernetes" height="50" />](https://k8s-school.fr)

## Les supports de cours

Toutes les diapositives sont [sur notre site](https://k8s-school.fr/pdf)

## Le fichier d'échange

Durant la formation, nous allons échanger via ce [Framapad](https://annuel.framapad.org/p/k8s-school?lang=fr)

# La plateforme de cours

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
# Vérifier le statut des noeuds
kubectl get nodes

# Lancer un pod Ubuntu depuis Docker Hub
kubectl run -it --rm shell --image=ubuntu --restart=Never -- date

# Lancer un pod depuis gcr.io
kubectl run shell --image=gcr.io/kuar-demo/kuard-amd64:1 --restart=Never
# Ouvrir un shell dedans et quitter
kubectl exec -it shell -- ash
exit
kubectl delete pod shell
```

## Jouer avec les exemples

Récupérer les exemples, démos et exercices de k8s-school en lançant:
```shell
clone-school.sh
# Jouer avec kubectl et les fichiers yaml :-)
```

# Informations complémentaires

## L'écosystème Kubernetes

* [Démo ArgoCD](https://github.com/k8s-school/argocd-demo.git)
* [Démo Ingress](https://github.com/k8s-school/nginx-controller-example.git)
* [Démo Istio](ttps://github.com/k8s-school/istio-example.git)
* [Démo Telepresence](https://github.com/k8s-school/telepresence-demo.git)
