---
title: 'Understanding StatefulSets'
date: 2025-02-25T14:15:26+10:00
draft: false
weight: 190
tags: ["Kubernetes", "StatefulSet", "Storage", "MongoDB", "Installation", "CKA"]
---

## Setup

The cluster is shared by the trainees: work in a namespace of your own, labeled with your account.

```bash
ID=$(whoami)
NS=mongo-$ID
kubectl create namespace $NS
kubectl label namespace $NS mongo=$ID
kubectl config set-context --current --namespace=$NS
```

## Semi-Manual Installation

Create a MongoDB StatefulSet.

Apply the [mongo-simple.yaml](https://github.com/k8s-school/k8s-school/blob/master/labs/1_kubernetes/15-10-mongo-simple.yaml) file to create the StatefulSet.
Then apply the [mongo-service.yaml](https://github.com/k8s-school/k8s-school/blob/master/labs/1_kubernetes/15-11-mongo-service.yaml) file to create the headless service.

Check that the pods start in order.

Start a shell in an Ubuntu pod (`kubectl run -i --rm --tty shell --image=ubuntu:24.04 -- bash`), install `nslookup` or `dig`, and attempt a DNS resolution of:

* `mongo`
* `mongo-1.mongo`

What do you observe?

To initialize MongoDB, use the following commands:

```bash
kubectl exec -it mongo-0 -- mongosh
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
kubectl exec mongo-0 -c mongodb -- mongosh --quiet --eval 'rs.status().members.map(m => m.name + " " + m.stateStr)'
```

{{% notice note %}}
The configuration script in the `configmap` is not highly robust and has some side effects.
If one of the `mongo` pods is not present in the `mongo` replicaset, a simple solution is to delete the affected `pod` so that it is automatically recreated and the configuration script runs again.
{{% /notice %}}

### Data Loading

```bash
curl -O https://raw.githubusercontent.com/mongodb/docs-assets/primer-dataset/primer-dataset.json

# Only the primary accepts writes: connect to the replica set, not to a pod
RS="mongodb://mongo-0.mongo:27017/test?replicaSet=rs0"
kubectl exec -i mongo-0 -c mongodb -- mongoimport --uri "$RS" --collection restaurants --drop < primer-dataset.json
```

Finally, test data access:

```bash
kubectl exec mongo-0 -c mongodb -- mongosh --quiet "$RS" --eval "db.restaurants.findOne()"
```

{{% notice warning %}}
OpenShift administration training: stop here. The Rolling Update section below is done later, with the other rolling update labs.
{{% /notice %}}

## Rolling Update

Upgrade MongoDB from `7.0.43` to `7.0.45`, without losing the data and while the replica set keeps a primary.

Work in your namespace, and set the replica set URI again if you start a new shell:

```bash
kubectl config set-context --current --namespace=mongo-$(whoami)
RS="mongodb://mongo-0.mongo:27017/test?replicaSet=rs0"
```

### Canary on one pod

Display the update strategy of the StatefulSet. Then update **only** `mongo-2` to `docker.io/library/mongo:7.0.45`, and check the MongoDB version of each member.

{{%expand "Solution" %}}
```bash
kubectl get statefulset mongo -o jsonpath='{.spec.updateStrategy}{"\n"}'
# {"rollingUpdate":{"maxUnavailable":1,"partition":0},"type":"RollingUpdate"}

# Only the pods with an ordinal >= partition are updated
kubectl patch statefulset mongo -p '{"spec":{"updateStrategy":{"rollingUpdate":{"partition":2}}}}'
kubectl set image statefulset/mongo mongodb=docker.io/library/mongo:7.0.45 init-mongo=docker.io/library/mongo:7.0.45
kubectl rollout status statefulset/mongo
# partitioned roll out complete: 1 new pods have been updated...

kubectl get pods -l app=mongo -o custom-columns='NAME:.metadata.name,IMAGE:.spec.containers[0].image,REV:.metadata.labels.controller-revision-hash'
# NAME      IMAGE                            REV
# mongo-0   docker.io/library/mongo:7.0.43   mongo-844478b6d8
# mongo-1   docker.io/library/mongo:7.0.43   mongo-844478b6d8
# mongo-2   docker.io/library/mongo:7.0.45   mongo-74bcf55988

for i in 0 1 2; do echo "mongo-$i $(kubectl exec mongo-$i -c mongodb -- mongosh --quiet --eval 'db.version()')"; done
```

The `controller-revision-hash` label points to a `ControllerRevision`: the StatefulSet keeps its pod templates in these objects (`kubectl get controllerrevisions`), like a Deployment keeps its ReplicaSets.

`partition` is the canary of a StatefulSet: the pods with an ordinal below the partition keep the old revision, even if they are deleted and recreated.
{{% /expand%}}

### Finish the update

Update the other members. In which order are the pods updated? Which member is the primary at the end? Are the data and the PVCs still the same?

{{%expand "Solution" %}}
```bash
kubectl get pods -l app=mongo -w &
kubectl patch statefulset mongo -p '{"spec":{"updateStrategy":{"rollingUpdate":{"partition":0}}}}'
kubectl rollout status statefulset/mongo
kill %1

kubectl exec mongo-0 -c mongodb -- mongosh --quiet --eval 'rs.status().members.map(m => m.name + " " + m.stateStr)'
# [
#   'mongo-0.mongo:27017 SECONDARY',
#   'mongo-1.mongo:27017 SECONDARY',
#   'mongo-2.mongo:27017 PRIMARY'
# ]
kubectl exec mongo-0 -c mongodb -- mongosh --quiet "$RS" --eval "db.restaurants.countDocuments()"
kubectl get pvc -o custom-columns=NAME:.metadata.name,VOLUME:.spec.volumeName
```

- The pods are updated one at a time, in **reverse ordinal order** (`mongo-1`, then `mongo-0`), and each pod must be `Ready` before the next one is deleted.
- When the pod of the primary is deleted, the replica set elects a new primary among the secondaries: the primary is not `mongo-0` any more. This is why the clients must connect to the replica set (`?replicaSet=rs0`) and not to a pod.
- Each new pod gets the PVC of its ordinal back (`database-mongo-<i>`, same volume): the data is not copied, it stays in the volume.
{{% /expand%}}

### Rollback

Roll back the StatefulSet to the previous version, and check the versions and the data.

{{%expand "Solution" %}}
```bash
kubectl rollout history statefulset/mongo
kubectl rollout undo statefulset/mongo
kubectl rollout status statefulset/mongo
for i in 0 1 2; do echo "mongo-$i $(kubectl exec mongo-$i -c mongodb -- mongosh --quiet --eval 'db.version()')"; done
# mongo-0 7.0.43
# mongo-1 7.0.43
# mongo-2 7.0.43
```

The rollback is a rolling update to the previous `ControllerRevision`. Kubernetes only rolls back the pod template, never the data: a patch downgrade (`7.0.45` to `7.0.43`) is safe, but a major downgrade (`8.0` to `7.0`) needs to lower the `featureCompatibilityVersion` of MongoDB **before**. This is the job of a database operator.
{{% /expand%}}

### Going further

- `updateStrategy.type: OnDelete`: the StatefulSet only updates a pod when you delete it, which gives full control on the order (for example: the secondaries first, then `rs.stepDown()` on the primary).
- A database operator (CloudNativePG for PostgreSQL, MongoDB Community Operator) knows the topology: it updates the replicas first and switches the primary over in a controlled way.
- The correction scripts: [MONGODB-install.sh](https://github.com/k8s-school/k8s-school/blob/master/labs/1_kubernetes/.solution/MONGODB-install.sh), [MONGODB-test.sh](https://github.com/k8s-school/k8s-school/blob/master/labs/1_kubernetes/.solution/MONGODB-test.sh), [MONGODB-update.sh](https://github.com/k8s-school/k8s-school/blob/master/labs/1_kubernetes/.solution/MONGODB-update.sh)

## Clean up

```bash
kubectl delete namespace -l mongo=$(whoami)
kubectl config set-context --current --namespace=default
```

---

Congratulations! You have worked with all the fundamental components needed to deploy an application on a Kubernetes cluster 🚀!
