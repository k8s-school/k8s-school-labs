---
title: 'Installer EFK'
date: 2024-07-11T14:15:26+10:00
draft: false
weight: 175
tags: ["Kubernetes", "ElasticSearch", "Logs", "Kibana"]
---

## Prerequis

- Lancer la toolbox: `ktbx desk`
- Créez un `namespace` `elastic-<ID>`
- Se placer dans ce `namespace` avec `kubens`


## Deployer ECK

`ECK` comprend l'operateur `ElasticSearch` et les `CRDs` associées, Voici la commande pour l'installer:

```bash
kubectl apply -f https://download.elastic.co/downloads/eck/2.13.0/crds.yaml
kubectl apply -f https://download.elastic.co/downloads/eck/2.13.0/operator.yaml
```

Lancer `kubectl get crds` pour vérifier que les CRDs sont bien présentes.
Déterminer également le `namespace` dans lequel l'opérateur a été installé.

Pour plus d'informations: https://www.elastic.co/guide/en/cloud-on-k8s/2.13/k8s-deploy-eck.html


## Deployer Elasticsearch

https://www.elastic.co/guide/en/cloud-on-k8s/2.13/k8s-deploy-elasticsearch.html

## Deployer Kibana

https://www.elastic.co/guide/en/cloud-on-k8s/2.13/k8s-deploy-kibana.html

## Déployer Beat

https://www.elastic.co/guide/en/cloud-on-k8s/2.13/k8s-beat-quickstart.html

## Accéder à Kibana

Lancer un `port-forward` vers `Kibana`:
```bash
kubectl port-forward service/quickstart-kb-http 560<ID>:5601
```

Créer un SSH tunnel, puis se connecter à Kibana avec son navigateur sur https://localhost:5601
Se connecter avec le login `elastic` et le mot de passe suivant:

```bash
PASSWORD=$(kubectl get secret quickstart-es-elastic-user -o go-template='{{.data.elastic | base64decode}}')
```

Dans Kibana, aller dans la section `Discover` (en haut à gauche), puis ajouter une source de données avec un index "filebeat-<version>*" et un `filter` "@timestamp", ensuite retourner dans la section `Discover` et rechercher `nginx`.

## Accès à la démo en ligne

Une démo avec le script d'installation complet est également disponible: [Démo EFK](https://github.com/k8s-school/demo-efk.git)
