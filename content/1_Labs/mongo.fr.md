---
title: 'Comprendre les StatefulSet par l'exemple: MongoDB'
date: 2024-06-06T14:15:26+10:00
draft: false
weight: 20
tags: ["Kubernetes", "StatefulSet", "Stockage", "MongoDB", "Installation"]
---

# Installation semi-manuelle

Créez un Statefulset MongoDB.

Appliquez le fichier [mongo-simple.yaml](https://github.com/k8s-school/k8s-school/blob/master/labs/1_kubernetes/15-10-mongo-simple.yaml) pour créer le StatefulSet.
Appliquez ensuite le fichier [mongo-service.yaml](https://github.com/k8s-school/k8s-school/blob/master/labs/1_kubernetes/15-11-mongo-service.yaml) afin de créer le service headless.

Vérifiez que les pods démarrent bien dand l'odre.

Instanciez un shell dans un pod ubuntu (`kubectl run -i --rm --tty shell --image=ubuntu -- bash`), installez `nslookup` ou `dig` et tentez une résolution DNS de :

* `mongo`
* `mongo-1.mongo`

Que constatez vous ?

Pour initialiser mongoDB utilisez les commandes suivantes :

```bash
kubectl exec -it mongo-0 -- mongo
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

### Chargement des données

```bash
curl -O https://raw.githubusercontent.com/mongodb/docs-assets/primer-dataset/primer-dataset.json

cat primer-dataset.json | kubectl exec -it mongo-0 -- mongoimport --db test --collection restaurants --drop
```

Enfin, tester l'accés aux données :

```bash
kubectl exec -it mongo-0 -- mongo test --eval "db.restaurants.find()"
```

---

Félicitations, Vous avez manipulé toutes les briques de base pour déployer une application sur un cluster Kubernetes 🚀 !