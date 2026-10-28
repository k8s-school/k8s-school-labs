---
title: 'RBAC monitoring'
date: 2024-06-06T14:15:26+10:00
draft: false
weight: 70
tags: ["Kubernetes", "RBAC", "Authorization", "Monitoring", "Security", "CKA", "CKS"]
---

**Author:** Fabrice JAMMES ([LinkedIn](https://www.linkedin.com/in/fabrice-jammes-5b29b042/)).

## Objective

Somewhere in the cluster, a `ServiceAccount` has been granted far more power than it needs. Find it, explain the risk, and propose a least-privilege fix.

The CKS curriculum lists "Use Role Based Access Controls to minimize exposure" and "Exercise caution in using service accounts" in the *Cluster hardening* domain.

## Setup

The lab works on the shared cluster: the trainer injects the security issue once, for all the trainees.

{{% notice info %}}
Trainer only, once per cluster, before the lab ([sec-issue.sh](https://github.com/k8s-school/k8s-advanced/blob/master/labs/2_authorization/sec-issue.sh) does the same):

```bash
kubectl create namespace monitor --dry-run=client -o yaml | kubectl apply -f -
kubectl create clusterrolebinding cluster-monitoring --clusterrole=cluster-admin \
  --serviceaccount=monitor:default --dry-run=client -o yaml | kubectl apply -f -
```
{{% /notice %}}

```bash
# The shared kind cluster (on the CKS training server: kind export kubeconfig, then kubectx kind-kind)
kubectx kind-kind
```

## Exercise 1: find the over-privileged service account

Find the bindings which grant the `ClusterRole` `cluster-admin`. Which one does not belong to the cluster administrators or to the system components?

{{% notice tip %}}
In the exam, only `kubectl` is available: `kubectl get clusterrolebindings -o wide` shows the role and the subjects of each binding. On the training server, these tools help too: `rbac-tool who-can create pods`, `kubectl access-matrix` ([rakkess](https://github.com/corneliusweig/rakkess)), `kubescape scan control C-0035 -v`.
{{% /notice %}}

{{%expand "Solution" %}}
```bash
kubectl get clusterrolebindings -o wide | grep -E "NAME|cluster-admin"
# NAME                    ROLE                        ...   USERS   GROUPS           SERVICEACCOUNTS
# cluster-admin           ClusterRole/cluster-admin   ...           system:masters
# cluster-monitoring      ClusterRole/cluster-admin   ...                            monitor/default
# kubeadm:cluster-admins  ClusterRole/cluster-admin   ...           kubeadm:cluster-admins
```

`cluster-monitoring` grants `cluster-admin` to the service account `default` of the namespace `monitor`. Check its rights:

```bash
SA=system:serviceaccount:monitor:default
kubectl auth can-i '*' '*' --all-namespaces --as=$SA
# yes
kubectl auth can-i get secrets -n kube-system --as=$SA
# yes
```
{{% /expand%}}

## Exercise 2: the risk

What can an attacker do with a pod running in the namespace `monitor`?

{{%expand "Answer" %}}
Every pod of `monitor` which does not set `serviceAccountName` uses the service account `default`, and gets its token mounted in `/var/run/secrets/kubernetes.io/serviceaccount/`. Anybody who can run or exec in a pod of `monitor` gets the token, and is administrator of the cluster: read all the Secrets, create privileged pods on any node, and so get root on the nodes.

Two mistakes add up: a binding to `cluster-admin`, and on the `default` service account, which all the pods of the namespace use without asking for it.
{{% /expand%}}

## Exercise 3: propose a fix

The monitoring application only needs to read the pods and the nodes of the cluster. Write the least-privilege fix:

- a dedicated service account `monitoring` in `monitor`
- a `ClusterRole` `monitoring-reader`, with `get`, `list` and `watch` on `pods` and `nodes`
- a `ClusterRoleBinding` which grants it to `monitor:monitoring`
- the deletion of `cluster-monitoring`

The cluster is shared: test the fix with `--dry-run=server`, the trainer applies it at the end of the lab.

{{%expand "Solution" %}}
```bash
kubectl create serviceaccount monitoring -n monitor --dry-run=server
kubectl create clusterrole monitoring-reader --verb=get,list,watch --resource=pods,nodes --dry-run=server
kubectl create clusterrolebinding monitoring-reader --clusterrole=monitoring-reader \
  --serviceaccount=monitor:monitoring --dry-run=server
kubectl delete clusterrolebinding cluster-monitoring --dry-run=server
```

Then the application uses `serviceAccountName: monitoring`, and the `default` service account gets no token: `automountServiceAccountToken: false` in the service account `default` of `monitor`.
{{% /expand%}}

## Questions

1. How do you find this kind of issue regularly, without searching by hand?
2. Which other RBAC rights are as dangerous as `cluster-admin`?

{{%expand "Answers" %}}
1. Scan the RBAC in the CI or in the cluster: `kubescape`, `rbac-tool analysis`, or the CIS benchmark (`kube-bench` checks `5.1.1`: "Ensure that the cluster-admin role is only used where required"). Watch the creation of bindings to `cluster-admin` in the [audit log]({{% ref "/1_Labs/audit-logs" %}}).
2. `create pods` (a pod can mount any Secret of its namespace, or be privileged), `get secrets`, `escalate` and `bind` on roles, `impersonate`, `create` on `pods/exec`, `nodes/proxy`, and `*` on anything.
{{% /expand%}}

{{% notice info %}}
Trainer only, at the end of the lab:

```bash
kubectl delete clusterrolebinding cluster-monitoring
kubectl delete namespace monitor
```
{{% /notice %}}
