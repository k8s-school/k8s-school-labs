---
title: 'etcd administration'
date: 2024-06-30T14:15:26+10:00
draft: false
weight: 5
tags: ["kubernetes", "etcd", "control-plane", "openshift", "weave"]
---

**Auteur:** Fabrice JAMMES ([LinkedIn](https://www.linkedin.com/in/fabrice-jammes-5b29b042/)).
**Date:** Jan 27, 2020 · 10 min read


## Exercice 1: display Kubernetes and Openshift resources

- Retrieve `etcd` pod name

{{%expand "Answer" %}}
```bash
# Wait for etcd pod to be u
kubectl  wait --timeout=240s --for=condition=Ready -n "openshift-etcd" pods -l "app=etcd,etcd=true,k8s-app=etcd"

etcd_pod=$(kubectl get pods -n "openshift-etcd" -l "app=etcd,etcd=true,k8s-app=etcd" -o jsonpath='{.items[0].metadata.name}')
```
{{% /expand%}}

- Launch `etcdctl --help` inside `etcd` pod

{{%expand "Answer" %}}
```bash
# Display Kubernetes keys
kubectl exec -t -n "openshift-etcd" "$etcd_pod" -- etcdctl --help
```
{{% /expand%}}

- Use `etcdctl get ...`  to display Kubernetes and Openshift keys

{{%expand "Answer" %}}
```bash
# Display Kubernetes keys
kubectl exec -t -n "openshift-etcd" "$etcd_pod" -- etcdctl get /kubernetes.io --keys-only --prefix

# Display OpenShift keys (CustomResources)
kubectl exec -t -n "$ns" "$etcd_pod" --  \
    sh -c "echo \$ETCDCTL_CERT \$ETCDCTL_KEY \$ETCDCTL_CACERT && etcdctl get /openshift.io --keys-only --prefix"
```
{{% /expand%}}


# Exercice 2: perform an etcd backup and check its status

- Perform etcd snapshot with `etcdctl`

{{%expand "Answer" %}}
```bash
kubectl exec -t -n "openshift-etcd" "$etcd_pod" --  \
    sh -c "ETCDCTL_API=3 etcdctl \
    snapshot save /var/lib/etcd/etcd-snapshot.db"
```
{{% /expand%}}

- Check the status of the snapshot with `etcdctl` (deprecated)

{{%expand "Answer" %}}
```bash
kubectl exec -t -n "openshift-etcd" "$etcd_pod" --  \
    sh -c "ETCDCTL_API=3 etcdctl \
    -w fields snapshot status /var/lib/etcd/etcd-snapshot.db"
```
{{% /expand%}}

- Check the status of the snapshot with etcdutl
{{%expand "Answer" %}}
```bash
kubectl exec -t -n "openshift-etcd" "$etcd_pod" --  \
    sh -c "etcdutl \
    -w fields snapshot status /var/lib/etcd/etcd-snapshot.db"
```
{{% /expand%}}