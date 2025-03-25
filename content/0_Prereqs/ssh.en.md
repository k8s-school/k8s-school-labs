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
ssh k8s<ID>@<serverip>
```

## Kubernetes Access

The `kubeconfig` file allows connection to the Kubernetes server.

```bash

# Retrieve the k8s cluster authentication file
mkdir -p ~/.kube
cp /tmp/config $HOME/.kube/config
chmod 600 $HOME/.kube/config

# Alternate solution, kind specific
kind export kubeconfig

# Launch k8s-toolbox interactively
ktbx desk

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

```bash
# inside the toolbox
# Retrieve password in /tmp/oc-creds.txt
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

Once in the toolbox, run one of the commands below to download the labs:

```shell
# Lab for the "Kubernetes Fundamentals" training
git clone https://github.com/k8s-school/k8s-school

# Lab for the "Advanced Kubernetes" training
git clone https://github.com/k8s-school/k8s-advanced

# Lab for the "Advanced OpenShift" training
git clone https://github.com/k8s-school/openshift-advanced
```
