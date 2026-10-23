---
title: 'Access to Labs'
date: 2024-05-22T14:15:26+10:00
draft: false
weight: 20
tags: ["kubernetes", "ktbx", "prerequisites"]
---

## SSH Access

The password will be provided by the trainer:
```bash
ssh student<ID>@<serverip>
```

## The kubeadm lab: your own two nodes

The [kubeadm lab]({{% ref "/1_Labs/kubeadm" %}}) builds a Kubernetes cluster
from scratch, so it needs real machines rather than the shared kind cluster.
Two are provisioned for you:

| Host | Role |
|---|---|
| `student<ID>-1` | master (control plane) |
| `student<ID>-2` | worker |

Reach them from the training server — no password, no key to install:

```bash
ssh student3-1     # logged in as student3; or simply: ssh "$USER-1"
```

## Kubernetes Access

Retrieve the kubeconfig for the shared kind cluster:

```bash
kind export kubeconfig

# Check Kubernetes status
kubectl cluster-info

# Check node status
kubectl get nodes

# Create a namespace
kubectl create namespace <ID-first-name>

# Change the current context's active namespace
kubens <ID-first-name>

# Create a pod
# use "kubectl run --help" to retrieve the correct command
kubectl run <your-pod> ???

# Add a label to the pod
kubectl label pod <your-pod> tutorial=true
```

## Openshift Access

The trainer publishes the crc credentials once the cluster is up, from the `trainer` account:

```bash
crc console --credentials > /tmp/oc-creds.txt
chmod 644 /tmp/oc-creds.txt
```

```bash
# Retrieve password in /tmp/oc-creds.txt
cat /tmp/oc-creds.txt
# The API certificate is self-signed: answer 'y' to the insecure connection prompt
oc login -u kubeadmin https://api.crc.testing:6443

# Watch the cluster
kubectl get nodes

# Check you context
kubectx

# Create a namespace <ID-first-name>
oc new-project --help

# Check you context again
kubectx

# Switch to other context/cluster
# kubectx default/api-crc-testing:6443/kubeadmin
```


## Download the Labs

Run one of the commands below to download the labs:

```shell
# Lab for the "Kubernetes Fundamentals" training
git clone https://github.com/k8s-school/k8s-school

# Lab for the "Advanced Kubernetes" training
git clone https://github.com/k8s-school/k8s-advanced

# Lab for the "Advanced OpenShift" training
git clone https://github.com/k8s-school/openshift-advanced
```
