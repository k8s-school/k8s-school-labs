---
title: 'Kubelet and static pods'
date: 2024-06-30T14:15:26+10:00
draft: false
weight: 210
tags: ["kubernetes", "openshift", "kubelet", "static pod", "control plane"]
---


## Exercice 1: retrieve static pod specifications in Kubernetes (kind-based)

Switch to Kubernetes cluster using `kubectx kind-kind` and then access the control plane Node using `docker exec -t -- <my-master-node> sh` and then access Kubelet configuration.

{{%expand "Answer" %}}
```bash
MASTER_NODE=$(kubectl get nodes '--selector=node-role.kubernetes.io/control-plane' -o jsonpath='{.items[0].metadata.name}')

# Exit the ktbx-toolbox to run docker
docker exec -t -- kind-control-plane sh -c 'ps -ef | grep "/usr/bin/kubelet"'
docker exec -t -- kind-control-plane sh -c 'cat /var/lib/kubelet/config.yaml | grep -i staticPodPath'
docker exec -t -- kind-control-plane sh -c 'ls /etc/kubernetes/manifests'
```
{{% /expand%}}

## Exercice 1: retrieve static pod specifications in Openshift

Switch to Kubernetes cluster using `kubectx <my-openshift-context>` and then access the control plane Node using `oc debug node/<my-master-node>` and then access Kubelet configuration.

{{%expand "Answer" %}}
```bash
MASTER_NODE=$(kubectl get nodes '--selector=node-role.kubernetes.io/master' -o jsonpath='{.items[0].metadata.name}')
oc debug node/"$MASTER_NODE"
chroot /host
ps -ef | grep "kubelet "
cat /etc/kubernetes/kubelet.conf
cat /etc/kubernetes/manifests/kube-apiserver-pod.yaml | jq
```
{{% /expand%}}
