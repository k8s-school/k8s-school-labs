---
title: 'Kubernetes Controllers'
date: 2025-03-23T14:15:26+10:00
draft: false
weight: 8
tags: ["kubernetes", "control-place", "controller"]
---

## Objective
This lab will help you understand the role of Kubernetes controllers in managing the desired/actual state of cluster resources.

## Prerequisites

- A Kubernetes cluster (Minikube, Kind, or a cloud-based Kubernetes cluster)
- `kubectl` installed and configured

---

## Step 1: Understanding Controllers

Kubernetes controllers are control loops that monitor the state of the cluster and make or request changes where needed. The key controllers include:
- **Deployment Controller** (manages ReplicaSets for stateless applications)
- **ReplicaSet Controller** (ensures a specified number of pod replicas)
- **StatefulSet Controller** (manages stateful applications)
- **DaemonSet Controller** (ensures a copy of a pod runs on each node)
- **Job Controller** (runs batch jobs to completion)
- **CronJob Controller** (manages periodic tasks)

---

## Step 2: Create a ReplicaSet

A **ReplicaSet** ensures a specified number of pod replicas run at all times.


{{%expand "Answer" %}}
Create a file called `replicaset.yaml`:

```yaml
apiVersion: apps/v1
kind: ReplicaSet
metadata:
  name: my-replicaset
spec:
  replicas: 3
  selector:
    matchLabels:
      app: my-app
  template:
    metadata:
      labels:
        app: my-app
    spec:
      containers:
      - name: my-container
        image: nginx
        ports:
        - containerPort: 80
```

Apply the ReplicaSet:
```sh
kubectl apply -f replicaset.yaml
```
{{% /expand%}}

Verify the ReplicaSet.

{{%expand "Answer" %}}
```sh
# Observe pod lifecycle
kubectl get pods --watch

# In a second terminal, then go back to previous command
kubectl get replicaset
```
{{% /expand%}}

Delete a pod and observe self-healing.

{{%expand "Answer" %}}
```sh
kubectl delete pod <pod-name>
kubectl get pods
```
{{% /expand%}}

Check the ReplicaSet description to see controller activity.

{{%expand "Answer" %}}
```sh
kubectl describe replicaset my-replicaset
```
{{% /expand%}}

Observe Pod Events for the current namespace.

{{%expand "Answer" %}}
```sh
kubectl get events --sort-by=.metadata.creationTimestamp
```
{{% /expand%}}

View logs related to the ReplicaSet controller, and extract the one related to `<my-namespace>/my-replicaset`.
{{%expand "Answer" %}}
```sh
kubectl logs -n kube-system kube-controller-manager-kind-control-plane
```
{{% /expand%}}

You should see that Kubernetes automatically creates a new pod to maintain the desired state.

---

## Step 3: Scaling the ReplicaSet

Scale the ReplicaSet to 5 replicas:
```sh
kubectl scale replicaset my-replicaset --replicas=5
```

Check the number of pods:
```sh
kubectl get pods
```

---

## Step 4: Cleanup
Delete the ReplicaSet:
```sh
kubectl delete replicaset my-replicaset
```

Verify resources are removed:
```sh
kubectl get all
```

---

## Conclusion
You have successfully learned how Kubernetes controllers maintain the desired state of your applications. Explore other controllers like **StatefulSet**, **DaemonSet**, and **Jobs** to deepen your understanding!

