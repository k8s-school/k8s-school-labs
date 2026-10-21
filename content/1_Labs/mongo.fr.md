---
title: 'Comprendre les StatefulSets'
date: 2024-06-06T14:15:26+10:00
draft: false
weight: 195
tags: ["Kubernetes", "StatefulSet", "Stockage", "MongoDB", "Installation", "CKA"]
---

## Installation semi-manuelle

Créez un Statefulset MongoDB.

Appliquez le fichier [mongo-simple.yaml](https://github.com/k8s-school/k8s-school/blob/master/labs/1_kubernetes/15-10-mongo-simple.yaml) pour créer le StatefulSet.
Appliquez ensuite le fichier [mongo-service.yaml](https://github.com/k8s-school/k8s-school/blob/master/labs/1_kubernetes/15-11-mongo-service.yaml) afin de créer le service headless.

Vérifiez que les pods démarrent bien dand l'odre.

Instanciez un shell dans un pod ubuntu (`kubectl run -i --rm --tty shell --image=ubuntu:24.04 -- bash`), installez `nslookup` ou `dig` et tentez une résolution DNS de :

* `mongo`
* `mongo-1.mongo`

Que constatez vous ?

Pour initialiser mongoDB utilisez les commandes suivantes :

```bash
kubectl exec -it mongo-0 -- mongosh
# Dans le conteneur
rs.initiate({_id: "rs0", members:[{_id: 0, host: "mongo-0.mongo:27017"}]});
rs.add("mongo-1.mongo:27017");
rs.add("mongo-2.mongo:27017");
```

Tenter un passage à l'échelle du StatefulSet avec `kubectl scale`, que se passe t'il?

## Installation automatisée

Quels sont les axes d'amélioration pour ce StatefulSet?

{{%expand "Réponses" %}}
- support du passage à l'échelle
- configuration automatique du cluster MongoDB
- mise en oeuvre d'un stockage persistent.
{{% /expand%}}

Supprimer d'abord le StatefulSet MongoDB.

### Ajout d'un script de configuration automatisée

Appliquer le fichier [mongo-configmap.yaml](https://github.com/k8s-school/k8s-school/blob/master/labs/1_kubernetes/15-12-mongo-configmap.yaml).


### Ajout d'un stockage persistent

En s'inspirant de [cet example](https://kubernetes.io/fr/docs/concepts/workloads/controllers/statefulset/#composants), modifier le fichier [mongo.yaml](https://github.com/k8s-school/k8s-school/blob/master/labs/1_kubernetes/15-13-mongo.yaml) pour ajouter une section `volumeClaimTemplates`

{{%expand "Solution en ligne" %}}
https://github.com/k8s-school/k8s-school/blob/master/labs/1_kubernetes/.solution/15-14-mongo-pvc.yaml
{{% /expand%}}


Vérifier que ls StatefulSet a bien démarré puis lister les `PVs` et les `PVCs`.

Vérifier également que tous les noeuds sont abonnés au cluster avec la commande suivante:

```bash
kubectl exec mongo-0 -c mongodb -- mongosh --quiet --eval 'rs.status().members.map(m => m.name + " " + m.stateStr)'
```

{{% notice note %}}
Le script de configuration présent dans le `configmap` n'est pas extrêmement robuste et présente des effets de bord. Si un des `pods` `mongo` n'est pas présent dans le `replicaset` `mongo` alors une solution simple est de supprimer le `pod` concerné afin qu'il soit recréé automatiquement et que le script de configuration soit de nouveau exécuté.
{{% /notice %}}


### Chargement des données

```bash
curl -O https://raw.githubusercontent.com/mongodb/docs-assets/primer-dataset/primer-dataset.json

# Only the primary accepts writes: connect to the replica set, not to a pod
RS="mongodb://mongo-0.mongo:27017/test?replicaSet=rs0"
kubectl exec -i mongo-0 -c mongodb -- mongoimport --uri "$RS" --collection restaurants --drop < primer-dataset.json
```

Enfin, tester l'accés aux données :

```bash
kubectl exec mongo-0 -c mongodb -- mongosh --quiet "$RS" --eval "db.restaurants.findOne()"
```

## Mise à jour progressive

Canary avec `partition`, ordre des pods, bascule du primaire et rollback : voir la section [Rolling Update](https://k8s-school.fr/labs/k8s/en/1_labs/mongo/index.html#rolling-update) du lab en anglais.

---

Félicitations, Vous avez manipulé toutes les briques de base pour déployer une application sur un cluster Kubernetes 🚀 !