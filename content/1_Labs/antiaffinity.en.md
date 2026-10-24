---
title: 'Pod placement: affinity, anti-affinity, taints'
date: 2024-06-06T14:15:26+10:00
draft: false
weight: 20
tags: ["Kubernetes", "OpenShift", "Scheduling", "Affinity", "Taints"]
---

This lab runs on the kind cluster shared by all trainees, which has 3 worker nodes: switch to it first with `kubectx kind-kind`.

## Objective

Control where the scheduler places pods with:

- `podAntiAffinity`: spread the pods of a Deployment across nodes
- `nodeAffinity`: run pods only on nodes with a given label
- taints and tolerations: reserve nodes for some workloads

## Prerequisites

- A cluster with **3 worker nodes**: on a single-node cluster (CRC, SNO) most pods will stay `Pending`
- Rights to label and taint nodes (cluster-admin)
- The cluster can be shared by several trainees: each one works in their own namespace and with their own node label

{{% notice note %}}
All commands use `kubectl`, they work the same with `oc`.
The image `nginxinc/nginx-unprivileged` runs as a non-root user and listens on port 8080, so it also runs under the OpenShift `restricted-v2` SCC.
{{% /notice %}}

```bash
ID=$(whoami)
kubectl create namespace placement-$ID
kubectl config set-context --current --namespace=placement-$ID

# List the worker nodes, they will be used in the exercises below
kubectl get nodes -l '!node-role.kubernetes.io/control-plane'
WORKERS=($(kubectl get nodes -l '!node-role.kubernetes.io/control-plane' -o jsonpath='{.items[*].metadata.name}' | tr ' ' '\n' | sort))
SSD_NODE=${WORKERS[0]}
```

### Reserve a node for infrastructure pods

One worker is reserved for infrastructure pods, it is explained in exercise 3.
This setup is **shared by all trainees**: the first one creates it, the others reuse it.

First, look at the taints that already exist on the nodes:

```bash
kubectl get nodes -o custom-columns=NAME:.metadata.name,TAINTS:.spec.taints
```

{{% notice note %}}
The control plane node already has a taint: `node-role.kubernetes.io/control-plane:NoSchedule`.
It is set when the cluster is installed (by `kubeadm`, here through kind), so that regular pods never run next to the API server and etcd.
Only pods that tolerate it, such as the control plane components, are scheduled there.
If another trainee already reserved the infra node, its `dedicated=infra` taint is listed too.
{{% /notice %}}

Then reserve the infra node:

```bash
# Reuse the infra node if another trainee already reserved it, else reserve the last worker
INFRA_NODE=$(kubectl get nodes -l dedicated=infra -o jsonpath='{.items[*].metadata.name}')
INFRA_NODE=${INFRA_NODE:-${WORKERS[-1]}}
# If the node is already reserved, 'not labeled' and 'already has dedicated taint(s)' are expected
kubectl label node $INFRA_NODE dedicated=infra
kubectl taint node $INFRA_NODE dedicated=infra:NoSchedule
kubectl get nodes -L dedicated -o custom-columns=NAME:.metadata.name,TAINTS:.spec.taints
```

{{% notice warning %}}
Never use `--overwrite` or remove this label and taint: the exercises of the other trainees rely on them.
{{% /notice %}}

## Exercise 1: pod anti-affinity

### Create a nginx deployment with 2 pods

Use the image `nginxinc/nginx-unprivileged:alpine`, container port `8080`.

{{%expand "Solution" %}}
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx
spec:
  replicas: 2
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginxinc/nginx-unprivileged:alpine
        ports:
        - containerPort: 8080
```

```bash
kubectl apply -f deployment.yaml
kubectl get pods -o wide
```
{{% /expand%}}

Several pods may run on the same node: the scheduler does not guarantee spreading.

### Add a 'podAntiAffinity' section to the deployment

The goal is to distribute all pods of this deployment across different nodes.

Use the `affinity` of this example to write the `affinity` section in the `deployment.yaml` file:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: with-pod-antiaffinity
spec:
  affinity:
    podAntiAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
      - labelSelector:
          matchExpressions:
          - key: security
            operator: In
            values:
            - S1
        topologyKey: topology.kubernetes.io/zone
  containers:
  - name: with-pod-affinity
    image: registry.k8s.io/pause:3.9
```

{{% notice note %}}
The `topologyKey` value will be `kubernetes.io/hostname` because pods must not be on the same nodes.
{{% /notice %}}

{{%expand "Solution" %}}
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx
spec:
  replicas: 2
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchExpressions:
              - key: app
                operator: In
                values:
                - nginx
            topologyKey: kubernetes.io/hostname
      containers:
      - name: nginx
        image: nginxinc/nginx-unprivileged:alpine
        ports:
        - containerPort: 8080
```
{{% /expand%}}

### Apply the new rule to the running deployment

Apply the updated `deployment.yaml` and watch the rollout:

```bash
kubectl apply -f deployment.yaml
kubectl rollout status deployment nginx --timeout=60s
kubectl get pods -o wide
```

The rollout does not finish: a new pod stays `Pending`. Find out why, then fix it.

{{%expand "Solution" %}}
```bash
kubectl describe pod -l app=nginx | grep -A5 Events
# ... 0/4 nodes are available: 1 node(s) had untolerated taint {dedicated: infra},
# 1 node(s) had untolerated taint {node-role.kubernetes.io/control-plane: },
# 2 node(s) didn't match pod anti-affinity rules ...
```

Only 2 nodes can accept the pod: the control plane and the infra node are tainted.
The pods come from two ReplicaSets: the old one, without the rule, and the new one created by `kubectl apply`:

```bash
kubectl get rs -l app=nginx
```

With the default rolling update settings (`maxSurge: 25%`, `maxUnavailable: 25%`) and 2 replicas, Kubernetes may create 1 extra pod (25% of 2, rounded up) but never go below 2 available pods (25% of 2, rounded down, is 0).
So it creates the new pod **before** deleting an old one: that makes 3 pods, and each of the 2 workers that accept them already runs a pod with the label `app=nginx`.
The new rule forbids the new pod to run on the same node as them, so it cannot be scheduled anywhere: this `Pending` pod shows that the rule works.

Deleting the pods does not help: each ReplicaSet re-creates its own pods, in the same situation.
To fix it, remove the old pods before creating the new ones: re-create the Deployment (or set `strategy.type: Recreate` in it).

```bash
kubectl delete deployment nginx
kubectl apply -f deployment.yaml
```
{{% /expand%}}

- Check that all pods are running on different nodes using:
`kubectl get pods -o wide`

- Scale the `Deployment` to four pods and try to understand what's happening.

{{%expand "Solution" %}}
```bash
kubectl scale deployment nginx --replicas=4
kubectl get pods -o wide
# Extra pods stay Pending, see why:
kubectl get events --field-selector=reason=FailedScheduling
# ... 0/4 nodes are available: 1 node(s) had untolerated taint {dedicated: infra},
# 1 node(s) had untolerated taint {node-role.kubernetes.io/control-plane: },
# 2 node(s) didn't match pod anti-affinity rules ...
```

With `requiredDuringSchedulingIgnoredDuringExecution`, there can't be more pods than available worker nodes.
The pods of the other trainees do not interfere: by default, the `labelSelector` of a pod affinity only applies to the namespace of the pod.
Use `preferredDuringSchedulingIgnoredDuringExecution` to spread pods when possible, without blocking the scheduling.
{{% /expand%}}

### Clean up

```bash
kubectl delete deployment nginx
```

## Exercise 2: node affinity

### Label a node

Add the label `disk-$ID=ssd` to `$SSD_NODE`. The label key contains your id, so that each trainee has their own label.

{{%expand "Solution" %}}
```bash
kubectl label node $SSD_NODE disk-$ID=ssd
kubectl get nodes -L disk-$ID
```
{{% /expand%}}

### Run pods only on nodes with an SSD

Create a Deployment `nginx-ssd` with 3 replicas, whose pods run only on nodes labeled `disk-$ID=ssd`.
Use a `nodeAffinity` with `requiredDuringSchedulingIgnoredDuringExecution`.

{{%expand "Solution" %}}
```bash
cat <<EOF > nginx-ssd.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-ssd
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nginx-ssd
  template:
    metadata:
      labels:
        app: nginx-ssd
    spec:
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
            - matchExpressions:
              - key: disk-$ID
                operator: In
                values:
                - ssd
      containers:
      - name: nginx
        image: nginxinc/nginx-unprivileged:alpine
        ports:
        - containerPort: 8080
EOF
kubectl apply -f nginx-ssd.yaml
# All pods run on $SSD_NODE
kubectl get pods -l app=nginx-ssd -o wide
```
{{% /expand%}}

### Questions

1. Remove your label from `$SSD_NODE`. What happens to the running pods? And to new pods?
2. What is the difference with a `nodeSelector`?

{{%expand "Solution" %}}
```bash
kubectl label node $SSD_NODE disk-$ID-
kubectl get pods -l app=nginx-ssd -o wide
kubectl rollout restart deployment nginx-ssd
kubectl get pods -l app=nginx-ssd -o wide
```

1. Running pods are not evicted: the rule is `...IgnoredDuringExecution`. New pods, here created by the rollout, stay `Pending` until a node gets the label again, and the rollout is blocked.
2. `nodeSelector` only does exact label matching. `nodeAffinity` supports operators (`In`, `NotIn`, `Exists`, `DoesNotExist`, `Gt`, `Lt`) and soft rules (`preferredDuringSchedulingIgnoredDuringExecution`, with a `weight`).

```bash
kubectl delete deployment nginx-ssd
```
{{% /expand%}}

## Exercise 3: taints and tolerations

A node affinity attracts pods to nodes. A taint does the opposite: it repels all pods that do not tolerate it.

### Inspect the tainted node

`$INFRA_NODE` was tainted with `dedicated=infra:NoSchedule` in the prerequisites.
Display its taints, then create a Deployment `nginx` with 6 replicas and no affinity.
On which nodes do the pods run?

{{%expand "Solution" %}}
```bash
kubectl describe node $INFRA_NODE | grep Taints
kubectl create deployment nginx --image=nginxinc/nginx-unprivileged:alpine --replicas=6
# No pod runs on $INFRA_NODE
kubectl get pods -l app=nginx -o wide
```
{{% /expand%}}

### Reserve the node for infrastructure pods

Create a Deployment `infra` with 2 replicas, whose pods run **only** on `$INFRA_NODE`.

{{% notice tip %}}
A toleration allows a pod to run on a tainted node, it does not force it to go there.
You also need a node affinity: `$INFRA_NODE` has the label `dedicated=infra`.
{{% /notice %}}

{{%expand "Solution" %}}
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: infra
spec:
  replicas: 2
  selector:
    matchLabels:
      app: infra
  template:
    metadata:
      labels:
        app: infra
    spec:
      tolerations:
      - key: dedicated
        operator: Equal
        value: infra
        effect: NoSchedule
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
            - matchExpressions:
              - key: dedicated
                operator: In
                values:
                - infra
      containers:
      - name: nginx
        image: nginxinc/nginx-unprivileged:alpine
        ports:
        - containerPort: 8080
```

```bash
kubectl apply -f infra.yaml
# All pods run on $INFRA_NODE
kubectl get pods -l app=infra -o wide
```
{{% /expand%}}

### Trainer demo: evict pods with `NoExecute`

{{% notice warning %}}
A `NoExecute` taint evicts the pods of **all** trainees running on the node: on a shared cluster, this part is a trainer demo, do not run it.
{{% /notice %}}

Add the taint `maintenance=true:NoExecute` to `${WORKERS[1]}`. What happens to the `nginx` pods running on it?

{{%expand "Solution" %}}
```bash
kubectl get pods -l app=nginx -o wide
kubectl taint node ${WORKERS[1]} maintenance=true:NoExecute
kubectl get nodes -o custom-columns=NAME:.metadata.name,TAINTS:.spec.taints
# Pods on ${WORKERS[1]} are evicted at once and recreated on the other untainted node
kubectl get pods -l app=nginx -o wide
```
{{% /expand%}}

Now update the `infra` Deployment so that its pods tolerate the `maintenance` taint for 60 seconds only.
Then put `$INFRA_NODE` in maintenance too, and watch the `infra` pods.

{{%expand "Solution" %}}
Append the toleration to the `infra` pods with a JSON patch, without editing `infra.yaml`
(`/-` adds an item at the end of the existing `tolerations` list):

```bash
kubectl patch deployment infra --type=json -p '[{
  "op": "add",
  "path": "/spec/template/spec/tolerations/-",
  "value": {"key": "maintenance", "operator": "Exists", "effect": "NoExecute", "tolerationSeconds": 60}
}]'
kubectl get deployment infra -o jsonpath='{.spec.template.spec.tolerations}' | jq
kubectl rollout status deployment infra
kubectl taint node $INFRA_NODE maintenance=true:NoExecute
kubectl get pods -l app=infra -o wide -w
```

The `infra` pods stay on `$INFRA_NODE` for 60 seconds, then they are evicted.
Their replacements are scheduled on `$INFRA_NODE` again: the toleration also matches at scheduling time, whatever `tolerationSeconds` is. They are evicted 60 seconds later, and so on.
`tolerationSeconds` is meant to ride out a short node outage, not to drain a node: use `kubectl drain` (`oc adm drain`) for maintenance.

Kubernetes uses this mechanism itself: each pod gets default tolerations for `node.kubernetes.io/not-ready` and `node.kubernetes.io/unreachable` with `tolerationSeconds: 300`.

```bash
kubectl get pod -l app=nginx -o jsonpath='{.items[0].spec.tolerations}' | jq
# End of the demo
kubectl taint node ${WORKERS[1]} maintenance-
kubectl taint node $INFRA_NODE maintenance-
```
{{% /expand%}}

### Questions

1. Why don't regular pods run on control-plane nodes?
2. On OpenShift, how are infra nodes (router, registry, monitoring) usually isolated?

{{%expand "Solution" %}}
```bash
kubectl get nodes -o custom-columns=NAME:.metadata.name,TAINTS:.spec.taints
```

1. Control-plane nodes have the taint `node-role.kubernetes.io/control-plane:NoSchedule` (`node-role.kubernetes.io/master:NoSchedule` on OpenShift). Only system pods tolerate it.
2. Infra nodes get the label `node-role.kubernetes.io/infra` and usually the taint `node-role.kubernetes.io/infra:NoSchedule` (set in their `MachineSet`). Infra components are then moved there with a `nodeSelector` and a toleration, in the `IngressController`, the image registry config and the `cluster-monitoring-config` ConfigMap.
{{% /expand%}}

## Automated run

The whole lab is automated and validated in [openshift-advanced](https://github.com/k8s-school/openshift-advanced/blob/master/labs/5_scheduler/ex1-placement.sh):

```bash
# Trainee: exercises 1 to 3, several trainees can run it at the same time
./labs/5_scheduler/ex1-placement.sh
# Trainer: also run the NoExecute demo
./labs/5_scheduler/ex1-placement.sh -s
# Trainer, at the end of the training: remove the shared infra node setup
./labs/5_scheduler/ex1-placement.sh -c
```

## Clean up

```bash
kubectl delete namespace placement-$ID
kubectl label node $SSD_NODE disk-$ID- || true
kubectl config set-context --current --namespace=default
```

The shared infra node setup is removed by the trainer at the end of the training.
