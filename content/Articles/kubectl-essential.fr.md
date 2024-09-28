---
title: 'Commandes kubectl Essentielles'
date: 2024-06-11T14:15:26+10:00
draft: false
weight: 1
tags: ["kubernetes", "kubectl", "CKA"]
---

**Durée:** 5 min de lecture

## Liste une ressource de l'API server
Pour récupérer les détails d'une ressource spécifique dans Kubernetes, utilisez la commande suivante :

```sh
kubectl get <resource-name> <obj-name> [-o yaml/json]
```

## Décrire une ressource de l'API server
Pour obtenir une description détaillée d'une ressource spécifique, utilisez :

```sh
kubectl describe <resource-name> <obj-name>
```

## Créer ou mettre à jour des ressources à partir d'un fichier
Pour créer ou mettre à jour des ressources à partir d'un fichier YAML, utilisez :

```sh
kubectl apply -f obj.yaml
```

## Supprimer des ressources à partir d'un fichier
Pour supprimer des ressources définies dans un fichier YAML, utilisez :

```sh
kubectl delete -f obj.yaml
# où bien pour détruire la ressource par son nom
kubectl delete <resource-name> <obj-name>
```

## Éditer une ressource dans la base de données de Kubernetes (c'est-à-dire etcd)
Pour éditer une ressource directement dans la base de données de Kubernetes, utilisez :

```sh
kubectl edit <resource-name> <obj-name>
```
> [En savoir plus sur les meilleures pratiques de création de microservices](https://12factor.net/codebase)

## Afficher la documentation en ligne (et fournir des exemples utiles)
Pour afficher l'aide et des exemples d'utilisation pour une commande spécifique, utilisez :

```sh
kubectl create job --help
# ou
kubectl help create job
```

## Décrire la spécification YAML
Pour obtenir une description de la spécification YAML pour un type de ressource spécifique, utilisez :

```sh
kubectl explain pods.spec [--recursive]
```

## Afficher les journaux pour un conteneur (c'est-à-dire stdout/stderr)
Pour afficher les journaux d'un conteneur spécifique, utilisez :

```sh
kubectl logs <pod-name> [ -c <container-name> ]
```
> [En savoir plus sur la gestion des journaux](https://12factor.net/logs)

## Ouvrir un shell interactif dans un conteneur
Pour ouvrir un shell interactif dans un conteneur, utilisez :

```sh
kubectl exec -it <pod-name> -- bash
```

## Ouvrir un accès réseau entre un pod et kubectl
Pour écouter sur le port 8080 localement et transférer les données vers/depuis le port 80 dans le pod, utilisez :

```sh
# Écouter sur le port 8080 localement, transférant les données vers/depuis le port 80 dans le pod
kubectl port-forward pod/mypod 8080:80 &

# Accéder au pod avec un client HTTP
curl http://localhost:8080
```

## Générer rapidement une spécification yaml

Les options `--dry-run=client -o yaml` permettent de générer du yaml sans créer la resources dans Kubernetes. Elles sont très utiles pour générer rapidement des fichiers yaml qui peuvent servir de base de travail. Voici un example d'utilisation:

```sh
kubectl create service clusterip my-service --tcp=5678:8080 --dry-run=client -o yaml
```

## Voir la liste des ressources en cours d'utilisation

Cette commande nécessite l'installation de 'kubernetes-sigs/metrics-server'
Pour afficher les métriques des nœuds et des pods, utilisez :

```sh
kubectl top nodes
kubectl top pods
```

## Copier des fichiers vers et depuis un conteneur
Pour copier des fichiers vers et depuis un conteneur, utilisez :

```sh
kubectl cp <pod-name:/path/to/remote/file> </path/to/local/file>
```