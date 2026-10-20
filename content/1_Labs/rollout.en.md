---
title: 'Deployments: rolling update, rollback and canary'
date: 2026-10-20T08:00:00+02:00
draft: false
weight: 152
tags: ["kubernetes", "Deployment", "rollout", "canary", "OpenShift"]
---

## Objective

In this lab you will:

- Perform a rolling update and watch the Deployment manage its ReplicaSets
- Diagnose a stuck rollout and roll back to a working revision
- Pause a rollout to batch several changes into one revision
- Run a canary release with two Deployments behind one Service

Complete this lab in 45 minutes.

## Prerequisites

- A Kubernetes cluster (kind is fine) or an OpenShift cluster, with `kubectl`
- The slides `C_K8s_02_standard_API.pdf`, section *Deployments*

{{% notice note %}}
On OpenShift, `oc rollout` is the same command as `kubectl rollout` for Deployments. It also manages the deprecated DeploymentConfigs (`oc rollout latest dc/<name>`), which are not covered here.
{{% /notice %}}

```bash
ID=$(whoami)
NS=rollout-$ID
kubectl create namespace $NS
kubectl config set-context --current --namespace=$NS
mkdir -p $HOME/tmp
```

## Exercise 1: create the Deployment

```bash
cat <<EOF > $HOME/tmp/kuard.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: kuard
spec:
  selector:
    matchLabels:
      app: kuard
      track: stable
  replicas: 10
  strategy:
    rollingUpdate:
      maxSurge: 25%
      maxUnavailable: 25%
    type: RollingUpdate
  template:
    metadata:
      annotations:
        kubernetes.io/change-cause: "Create blue kuard"
      labels:
        app: kuard
        track: stable
    spec:
      containers:
      - name: kuard
        image: k8sschool/kuard-amd64:blue
        ports:
        - containerPort: 8080
        readinessProbe:
          httpGet:
            path: /ready
            port: 8080
EOF
kubectl apply -f $HOME/tmp/kuard.yaml
kubectl rollout status deployment kuard
```

### Questions

1. Which objects did the Deployment create? How are they linked?
2. How many pods can be unavailable, and how many extra pods can be created, during an update?

{{%expand "Solution" %}}
```bash
kubectl get deployment,replicaset,pods -l app=kuard
kubectl get replicaset -l app=kuard -o jsonpath='{.items[0].metadata.ownerReferences[0].kind}/{.items[0].metadata.ownerReferences[0].name}{"\n"}'
kubectl get pods -l app=kuard --show-labels
```

1. The Deployment owns a ReplicaSet, which owns the pods. The ReplicaSet name and the pod label `pod-template-hash` are a hash of the pod template: each template change creates a new ReplicaSet.
2. With 10 replicas, `maxUnavailable: 25%` rounds down to 2 pods and `maxSurge: 25%` rounds up to 3 pods: during an update there are at least 8 ready pods and at most 13 pods.
{{% /expand%}}

## Exercise 2: rolling update, blue to green

In a second terminal, watch the ReplicaSets:

```bash
kubectl get replicaset -l app=kuard -w
```

In `$HOME/tmp/kuard.yaml`, change the image to `k8sschool/kuard-amd64:green` and the annotation `kubernetes.io/change-cause` to `Update to green kuard`. Apply the file and monitor the update.

{{%expand "Solution" %}}
```bash
sed -i 's/kuard-amd64:blue/kuard-amd64:green/; s/Create blue kuard/Update to green kuard/' $HOME/tmp/kuard.yaml
kubectl apply -f $HOME/tmp/kuard.yaml
kubectl rollout status deployment kuard
kubectl get replicaset -l app=kuard
```

The new ReplicaSet is scaled up step by step while the old one is scaled down. The old ReplicaSet is kept with 0 replicas: it is what makes the rollback possible (`spec.revisionHistoryLimit`, 10 by default).
{{% /expand%}}

## Exercise 3: a broken update

Update the image to `k8sschool/kuard-amd64:1.9.10`, with the change cause `Update to kuard 1.9.10`, and monitor the update. What happens? Is the application still available?

{{%expand "Solution" %}}
```bash
sed -i 's/kuard-amd64:green/kuard-amd64:1.9.10/; s/Update to green kuard/Update to kuard 1.9.10/' $HOME/tmp/kuard.yaml
kubectl apply -f $HOME/tmp/kuard.yaml
kubectl rollout status deployment kuard --timeout=60s
# Waiting for deployment "kuard" rollout to finish: 5 out of 10 new replicas have been updated...
# error: timed out waiting for the condition
kubectl get replicaset -l app=kuard
kubectl get pods -l app=kuard
kubectl describe pod -l app=kuard | grep -A3 "Failed"
```

The tag `1.9.10` does not exist: the new pods are in `ErrImagePull` / `ImagePullBackOff`. The rollout is stuck, but the application is still available: the rolling update never removes more than `maxUnavailable` ready pods, so 8 green pods still serve traffic.

After `spec.progressDeadlineSeconds` (600s by default), the Deployment reports the failure, but Kubernetes does **not** roll back automatically:

```bash
kubectl get deployment kuard -o jsonpath='{.status.conditions[?(@.type=="Progressing")]}' | jq
```
{{% /expand%}}

## Exercise 4: history and rollback

1. Display the rollout history, then the details of revision 2
2. Roll back to the last working version
3. Check the history again. What happened to revision 2?

{{%expand "Solution" %}}
```bash
kubectl rollout history deployment kuard
# REVISION  CHANGE-CAUSE
# 1         Create blue kuard
# 2         Update to green kuard
# 3         Update to kuard 1.9.10
kubectl rollout history deployment kuard --revision=2

kubectl rollout undo deployment kuard --to-revision=2
kubectl rollout status deployment kuard
kubectl rollout history deployment kuard
```

`kubectl rollout undo` without `--to-revision` goes back to the previous revision, which is enough here.
A rollback is a new rollout: revision 2 becomes revision 4, and revision 2 disappears from the history.
`$HOME/tmp/kuard.yaml` still references `1.9.10`: in a GitOps workflow, fix the file instead of running `kubectl rollout undo`, otherwise the next `apply` breaks the application again.
{{% /expand%}}

## Exercise 5: pause and resume

Pause the rollout, then change the image to `k8sschool/kuard-amd64:purple` **and** set a memory request of `64Mi`, with `kubectl set`. Resume the rollout. How many new revisions were created?

{{%expand "Solution" %}}
```bash
kubectl rollout pause deployment kuard
kubectl set image deployment kuard kuard=k8sschool/kuard-amd64:purple
kubectl set resources deployment kuard --requests=memory=64Mi
kubectl annotate deployment kuard kubernetes.io/change-cause="Update to purple kuard with memory request"
kubectl get replicaset -l app=kuard
# No new ReplicaSet while the Deployment is paused
kubectl rollout resume deployment kuard
kubectl rollout status deployment kuard
kubectl rollout history deployment kuard
```

Only one revision is created: pausing a Deployment batches several changes into a single rollout. A paused Deployment cannot be rolled back.
The `kubernetes.io/change-cause` annotation is set on the Deployment: Kubernetes copies it to the new ReplicaSet.
{{% /expand%}}

## Exercise 6: canary release

A rolling update replaces all the pods in a few minutes. A canary release sends a small part of the traffic to the new version, and keeps it there until it is validated.

1. Expose the Deployment `kuard` with a Service `kuard` which selects the label `app=kuard` only
2. Create a Deployment `kuard-canary` with 1 replica, the image `k8sschool/kuard-amd64:green` and the labels `app=kuard`, `track=canary`
3. Check which share of the requests reaches the canary
4. Promote the canary

{{%expand "Solution" %}}
```bash
kubectl expose deployment kuard --port=8080 --selector=app=kuard

cat <<EOF > $HOME/tmp/kuard-canary.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: kuard-canary
spec:
  selector:
    matchLabels:
      app: kuard
      track: canary
  replicas: 1
  template:
    metadata:
      labels:
        app: kuard
        track: canary
    spec:
      containers:
      - name: kuard
        image: k8sschool/kuard-amd64:green
        ports:
        - containerPort: 8080
        readinessProbe:
          httpGet:
            path: /ready
            port: 8080
EOF
kubectl apply -f $HOME/tmp/kuard-canary.yaml
kubectl rollout status deployment kuard-canary
kubectl get endpointslices -l kubernetes.io/service-name=kuard

# Send 100 requests to the Service, count the answers by Deployment
kubectl run curl --image=curlimages/curl:8.10.1 --restart=Never --rm -i --quiet -- sh -c '
  for i in $(seq 100); do
    curl -s http://kuard:8080/env/api | grep -o "\"HOSTNAME\":\"[^\"]*" | sed -E "s/.*:\"(.*)-[a-z0-9]+-[a-z0-9]+$/\1/"
  done | sort | uniq -c'
#      91 kuard
#       9 kuard-canary
```

The Service balances over the 11 ready pods: about 1 request out of 11 reaches the canary. The traffic share is set by the **number of replicas**, so a 1% canary needs 99 stable pods.

The Deployments select `app` **and** `track`, so their selectors do not overlap, while the Service selects `app` only. Two Deployments with overlapping selectors would fight over the same pods.

Promote the canary: update the stable Deployment to the canary image, then delete the canary.

```bash
kubectl set image deployment kuard kuard=k8sschool/kuard-amd64:green
kubectl rollout status deployment kuard
kubectl delete deployment kuard-canary
```

On OpenShift, a Route can split the traffic by weight between two Services, independently of the number of replicas: see `spec.alternateBackends` and `oc set route-backends`.
{{% /expand%}}

## Clean up

```bash
kubectl delete namespace $NS
```
