---
title: 'Upgrade a cluster with kubeadm'
date: 2026-11-01T14:00:00+01:00
draft: false
weight: 51
tags: ["kubernetes", "kubeadm", "upgrade", "CKA", "CKS"]
---

**Author:** Fabrice JAMMES ([LinkedIn](https://www.linkedin.com/in/fabrice-jammes-5b29b042/)).

## Objective

- Upgrade a kubeadm cluster from Kubernetes 1.36 to 1.37: the control plane first, then the worker
- Empty a node with `kubectl drain` before upgrading its kubelet
- Understand the version skew policy, which imposes this order

The CKS curriculum lists "Upgrade Kubernetes to avoid vulnerabilities" in the *Cluster Hardening* domain: a security patch reaches a cluster only through an upgrade. The CKA curriculum lists the same task.

Official documentation, available in the exam:

- [Upgrading kubeadm clusters](https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-upgrade/)
- [Version Skew Policy](https://kubernetes.io/releases/version-skew-policy/)
- [Upgrading Linux nodes](https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/upgrading-linux-nodes/)

## Setup

The two-node cluster in Kubernetes 1.36 of the [kubeadm lab]({{% ref "/1_Labs/kubeadm" %}}): built by yourself, or already installed by the trainer.

On the training server, name your two nodes:

```bash
MASTER=$USER-1
WORKER=$USER-2
```

Then open one terminal on each node, with `ssh $MASTER` and `ssh $WORKER`. On the **master**, check the version of the nodes:

<!-- ci-host: master -->
```bash
kubectl get nodes
# NAME         STATUS   ROLES           AGE   VERSION
# student3-1   Ready    control-plane   1h    v1.36.x
# student3-2   Ready    <none>          1h    v1.36.x
```

Deploy an application, to watch what happens to it during the upgrade:

<!-- ci-host: master -->
```bash
kubectl create deployment hello --image=gcr.io/google-samples/hello-app:1.0 --replicas=2
kubectl wait --for=condition=available deployment hello --timeout=180s
```

## Exercise 1: the target version

Which versions of `kubeadm` 1.37 can you install on the master?

{{% notice tip %}}
The apt repository of the Kubernetes packages serves one minor version only: look at `/etc/apt/sources.list.d/kubernetes.list`.
{{% /notice %}}

{{%expand "Solution" %}}
<!-- ci-host: master -->
```bash
cat /etc/apt/sources.list.d/kubernetes.list
# deb [signed-by=...] https://pkgs.k8s.io/core:/stable:/v1.36/deb/ /
sudo sed -i 's|/v1.36/|/v1.37/|' /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update
apt-cache madison kubeadm
#    kubeadm | 1.37.2-1.1 | https://pkgs.k8s.io/core:/stable:/v1.37/deb  Packages
#    kubeadm | 1.37.1-1.1 | https://pkgs.k8s.io/core:/stable:/v1.37/deb  Packages
#    kubeadm | 1.37.0-1.1 | https://pkgs.k8s.io/core:/stable:/v1.37/deb  Packages
```

Take the latest patch version: it carries the latest security fixes.
{{% /expand%}}

## Exercise 2: upgrade the control plane

On the **master**: upgrade `kubeadm`, check the upgrade plan, apply it, then upgrade the `kubelet` and `kubectl` of the master. Empty the master with `kubectl drain` before restarting its kubelet.

{{% notice warning %}}
Run the upgrade of each node in `tmux`: if the ssh connection drops during `kubeadm upgrade apply`, kubeadm stops halfway. Reattach with `tmux attach`.
{{% /notice %}}

{{%expand "Solution" %}}
`kubeadm` first, which is held by `apt-mark hold`:

<!-- ci-host: master -->
```bash
sudo apt-mark unhold kubeadm
sudo apt-get install -y kubeadm='1.37.*'
sudo apt-mark hold kubeadm
kubeadm version -o short
# v1.37.2
```

Then the control plane:

<!-- ci-host: master -->
```bash
sudo kubeadm upgrade plan
sudo kubeadm upgrade apply -y $(kubeadm version -o short)
# [upgrade] SUCCESS! A control plane node of your cluster was upgraded to "v1.37.2".
```

`kubeadm upgrade apply` upgrades the static pods of the control plane (`kube-apiserver`, `kube-controller-manager`, `kube-scheduler`, `etcd`), CoreDNS and kube-proxy, and renews the certificates of the control plane. The previous manifests and an etcd backup are kept in `/etc/kubernetes/tmp`.

At last the `kubelet` and `kubectl` of the master, after emptying it:

<!-- ci-host: master -->
```bash
kubectl drain $(hostname) --ignore-daemonsets
sudo apt-mark unhold kubelet kubectl
sudo apt-get install -y kubelet='1.37.*' kubectl='1.37.*'
sudo apt-mark hold kubelet kubectl
sudo systemctl daemon-reload
sudo systemctl restart kubelet
# The API server answers Forbidden for a few seconds after the restart: wait for it
timeout 120 sh -c 'until kubectl get node "$(hostname)" >/dev/null 2>&1; do sleep 2; done'
kubectl uncordon $(hostname)
kubectl get nodes
# NAME         STATUS   ROLES           AGE   VERSION
# student3-1   Ready    control-plane   1h    v1.37.2
# student3-2   Ready    <none>          1h    v1.36.x
```

The `VERSION` column is the version of the kubelet of each node.
{{% /expand%}}

## Exercise 3: upgrade the worker

Empty the worker from the master, upgrade it, then put it back in service. Where are the pods of the `hello` application during the upgrade?

{{%expand "Solution" %}}
On the **master**, empty the worker. `--ignore-daemonsets`: the pods of the DaemonSets (Cilium, kube-proxy) stay, they run on every node.

<!-- ci-host: master -->
```bash
WORKER_NODE=$(kubectl get nodes -l '!node-role.kubernetes.io/control-plane' -o jsonpath='{.items[0].metadata.name}')
kubectl drain $WORKER_NODE --ignore-daemonsets
kubectl get pods -l app=hello -o wide
# NAME                     READY   STATUS    RESTARTS   AGE   IP       NODE
# hello-5d6c8b9f7d-8xkqz   0/1     Pending   0          10s   <none>   <none>
# hello-5d6c8b9f7d-mz2vt   0/1     Pending   0          10s   <none>   <none>
```

The master does not accept the application pods (taint `node-role.kubernetes.io/control-plane:NoSchedule`) and there is a single worker: the application is down until the end of the upgrade. With several workers, `kubectl drain` moves the pods to the other ones, and a [PodDisruptionBudget](https://kubernetes.io/docs/tasks/run-application/configure-pdb/) keeps enough of them running.

On the **worker**: the same apt repository, then `kubeadm upgrade node`, which upgrades the configuration of the kubelet:

<!-- ci-host: worker -->
```bash
sudo sed -i 's|/v1.36/|/v1.37/|' /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update
sudo apt-mark unhold kubeadm kubelet kubectl
sudo apt-get install -y kubeadm='1.37.*'
sudo kubeadm upgrade node
sudo apt-get install -y kubelet='1.37.*' kubectl='1.37.*'
sudo apt-mark hold kubeadm kubelet kubectl
sudo systemctl daemon-reload
sudo systemctl restart kubelet
```

On the **master**, put the worker back in service:

<!-- ci-host: master -->
```bash
WORKER_NODE=$(kubectl get nodes -l '!node-role.kubernetes.io/control-plane' -o jsonpath='{.items[0].metadata.name}')
kubectl uncordon $WORKER_NODE
kubectl wait --for=condition=Ready node --all --timeout=300s
kubectl wait --for=condition=available deployment hello --timeout=180s
kubectl get nodes
# NAME         STATUS   ROLES           AGE   VERSION
# student3-1   Ready    control-plane   1h    v1.37.2
# student3-2   Ready    <none>          1h    v1.37.2
```
{{% /expand%}}

## Questions

1. Why the control plane first, then the workers? Can you upgrade from 1.36 to 1.38 at once?
2. Why `apt-mark hold` on `kubeadm`, `kubelet` and `kubectl`?
3. A CVE is fixed in Kubernetes 1.36.5. Which upgrade do you plan?

{{%expand "Answers" %}}
1. The [version skew policy](https://kubernetes.io/releases/version-skew-policy/): the kubelet must not be newer than `kube-apiserver`, and may be up to three minor versions older. So the control plane goes first. `kubeadm upgrade` skips no minor version: from 1.36 to 1.38, upgrade to 1.37, then to 1.38.
2. So that `apt-get upgrade`, run for the security updates of the system, does not upgrade a component outside this procedure: a kubelet newer than the API server, for example.
3. A patch upgrade within 1.36, to 1.36.5 or later: the same procedure, without changing the apt repository. Each minor version gets patch releases for about 14 months, then stops receiving security fixes: a cluster must also follow the minor versions.
{{% /expand%}}

## Clean up

<!-- ci-host: master -->
```bash
kubectl delete deployment hello
```
