---
title: 'Kubelet and static pods on Kubernetes'
date: 2026-10-27T11:00:00+01:00
draft: false
weight: 211
tags: ["kubernetes", "kubelet", "static pod", "control plane", "CKS"]
---

**Author:** Fabrice JAMMES ([LinkedIn](https://www.linkedin.com/in/fabrice-jammes-5b29b042/)).

## Objective

- Find the static pods of the control plane and the kubelet configuration
- Create a static pod, and understand its mirror pod

The control plane components of a kubeadm cluster (API server, etcd, scheduler, controller manager) are static pods: the kubelet runs them from files on the node, without the API server. Hardening them (CIS benchmark, audit logs, encryption at rest) means editing these files.

## Prerequisites

The lab writes on a node: use a kind cluster of your own, never a shared one.

```bash
CLUSTER=staticpod-$(whoami)
kind create cluster --name $CLUSTER
kubectx kind-$CLUSTER
CP=$CLUSTER-control-plane
```

`$CP` is the control plane node: kind runs it as a docker container, open a shell in it with `docker exec -it $CP bash`.

## Exercise 1: find the static pods

Find the kubelet process and its configuration file on the control plane node. Which directory holds the static pod manifests? Which pods are static pods?

{{%expand "Solution" %}}
```bash
docker exec $CP sh -c 'ps -ef | grep "/usr/bin/kubelet" | grep -v grep'
# --config=/var/lib/kubelet/config.yaml
docker exec $CP grep -i staticPodPath /var/lib/kubelet/config.yaml
# staticPodPath: /etc/kubernetes/manifests
docker exec $CP ls /etc/kubernetes/manifests
# etcd.yaml  kube-apiserver.yaml  kube-controller-manager.yaml  kube-scheduler.yaml
```

In the API, a static pod is owned by the `Node` it runs on, and its name ends with the name of the node:

```bash
kubectl get pods -n kube-system -o custom-columns=NAME:.metadata.name,OWNER:.metadata.ownerReferences[0].kind
```
{{% /expand%}}

## Exercise 2: create a static pod

Create a static pod `static-web` (image `nginx:1.27`) in the `default` namespace on the control plane node. Then try to delete it with `kubectl`. What happens?

{{%expand "Solution" %}}
```bash
cat <<EOF | docker exec -i $CP tee /etc/kubernetes/manifests/static-web.yaml
apiVersion: v1
kind: Pod
metadata:
  name: static-web
  namespace: default
spec:
  containers:
  - name: web
    image: nginx:1.27
EOF
# The kubelet checks the directory every 20 seconds
until kubectl get pod static-web-$CP 2>/dev/null; do sleep 5; done
kubectl wait --for=condition=Ready pod/static-web-$CP --timeout=120s
kubectl get pods -o wide
kubectl get pod static-web-$CP -o jsonpath='{.metadata.annotations.kubernetes\.io/config\.mirror}{"\n"}'

kubectl delete pod static-web-$CP
sleep 10
kubectl get pods
```

The pod `static-web-<node>` shown by the API is a **mirror pod**: a read-only copy the kubelet creates so that the pod is visible with `kubectl`. Deleting it with `kubectl` only deletes the mirror, the kubelet re-creates it at once. The container is still running.

The scheduler does not place static pods: the kubelet starts them itself, on its own node, even if the node has a `NoSchedule` taint.
{{% /expand%}}

## Exercise 3: delete the static pod

Delete the static pod for good.

{{%expand "Solution" %}}
```bash
docker exec $CP rm /etc/kubernetes/manifests/static-web.yaml
sleep 10
kubectl get pods
```

Only the file controls a static pod. This is why a backup copy of a control plane manifest must never stay in `/etc/kubernetes/manifests`: the kubelet would run it too.
{{% /expand%}}

## Questions

1. Why are the control plane components static pods?
2. An attacker is root on a node. What can they do with the static pods?

{{%expand "Answers" %}}
1. The API server cannot be started by a Deployment, since Deployments need the API server: the kubelet starts the control plane from local files, before the API server exists.
2. Write a manifest in `staticPodPath`: the kubelet runs any pod, in any namespace, with no admission control (Pod Security Admission, policies) and no RBAC check. Protect the nodes, the directory permissions (CIS benchmark checks them), and watch the changes of this directory (Falco, file integrity monitoring).
{{% /expand%}}

## Clean up

```bash
kind delete cluster --name $CLUSTER
```
