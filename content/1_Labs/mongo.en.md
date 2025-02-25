---
title: 'Understanding StatefulSets'
date: 2025-02-25T14:15:26+10:00
draft: false
weight: 20
tags: ["Kubernetes", "StatefulSet", "Storage", "MongoDB", "Installation", "CKA"]
---

## Semi-Manual Installation

Create a MongoDB StatefulSet.

Apply the [mongo-simple.yaml](https://github.com/k8s-school/k8s-school/blob/master/labs/1_kubernetes/15-10-mongo-simple.yaml) file to create the StatefulSet.
Then apply the [mongo-service.yaml](https://github.com/k8s-school/k8s-school/blob/master/labs/1_kubernetes/15-11-mongo-service.yaml) file to create the headless service.

Check that the pods start in order.

Start a shell in an Ubuntu pod (`kubectl run -i --rm --tty shell --image=ubuntu -- bash`), install `nslookup` or `dig`, and attempt a DNS resolution of:

* `mongo`
* `mongo-1.mongo`

What do you observe?

To initialize MongoDB, use the following commands:

```bash
kubectl exec -it mongo-0 -- mongo
# Inside the container
rs.initiate({_id: "rs0", members:[{_id: 0, host: "mongo-0.mongo:27017"}]});
rs.add("mongo-1.mongo:27017");
rs.add("mongo-2.mongo:27017");
```

Try scaling the StatefulSet using `kubectl scale`. What happens?

## Automated Installation

What are the areas for improvement for this StatefulSet?

{{%expand "Answers" %}}
- Support for scaling
- Automatic MongoDB cluster configuration
- Implementation of persistent storage
{{% /expand%}}

First, delete the MongoDB StatefulSet.

### Adding an Automated Configuration Script

Apply the [mongo-configmap.yaml](https://github.com/k8s-school/k8s-school/blob/master/labs/1_kubernetes/15-12-mongo-configmap.yaml) file.

### Adding Persistent Storage

Using [this example](https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/#components) as inspiration, modify the [mongo.yaml](https://github.com/k8s-school/k8s-school/blob/master/labs/1_kubernetes/15-13-mongo.yaml) file to add a `volumeClaimTemplates` section.

{{%expand "Online Solution" %}}
https://github.com/k8s-school/k8s-school/blob/master/labs/1_kubernetes/.solution/15-14-mongo-pvc.yaml
{{% /expand%}}

Verify that the StatefulSet has started correctly, then list the `PVs` and `PVCs`.

Also, ensure that all nodes are subscribed to the cluster using the following command:

```bash
kubectl exec -it mongo-0 -- mongo --eval="printjson(rs.status())"
```

{{% notice note %}}
The configuration script in the `configmap` is not highly robust and has some side effects.
If one of the `mongo` pods is not present in the `mongo` replicaset, a simple solution is to delete the affected `pod` so that it is automatically recreated and the configuration script runs again.
{{% /notice %}}

### Data Loading

```bash
curl -O https://raw.githubusercontent.com/mongodb/docs-assets/primer-dataset/primer-dataset.json

cat primer-dataset.json | kubectl exec -it mongo-0 -- mongoimport --db test --collection restaurants --drop
```

Finally, test data access:

```bash
kubectl exec -it mongo-0 -- mongo test --eval "db.restaurants.find()"
```

---

Congratulations! You have worked with all the fundamental components needed to deploy an application on a Kubernetes cluster 🚀!
