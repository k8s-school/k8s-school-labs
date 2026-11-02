---
title: 'etcd backup and restore'
date: 2026-11-02T10:00:00+01:00
draft: false
weight: 217
tags: ["kubernetes", "etcd", "backup", "control plane", "CKA", "CKS"]
---

**Author:** Fabrice JAMMES ([LinkedIn](https://www.linkedin.com/in/fabrice-jammes-5b29b042/)).

## Objective

- Read the keys of the Kubernetes objects in etcd, with `etcdctl` and the client certificates of etcd
- Back up etcd with a snapshot, and check the snapshot
- Restore the snapshot, and get back a deleted object

etcd holds the whole state of the cluster: all the objects, including the Secrets. A backup of etcd is the backup of the cluster, and a sensitive file. The OpenShift version of this lab is [etcd administration]({{% ref "/1_Labs/openshift-etcd" %}}).

Official documentation, available in the exam: [Operating etcd clusters for Kubernetes](https://kubernetes.io/docs/tasks/administer-cluster/configure-upgrade-etcd/).

## Prerequisites

The lab restores etcd, so the API server restarts: use a kind cluster of your own, never a shared one.

```bash
# On the CKS training server, use your own cluster ($CLUSTER_NAME),
# elsewhere create a cluster for the lab
CLUSTER=${CLUSTER_NAME:-etcd-backup-$(whoami)}
kind get clusters | grep -qx $CLUSTER || kind create cluster --name $CLUSTER
kind export kubeconfig --name $CLUSTER
CP=$CLUSTER-control-plane
```

<!-- ci-exec
# A new cluster: wait for the service account controller
until kubectl get serviceaccount default -n default >/dev/null 2>&1; do sleep 2; done
-->

`$CP` is the control plane node: kind runs it as a docker container, and `etcd` runs in it as a static pod. The image of the `etcd` pod has no shell: work on the node, as in the exam, where `etcdctl` and `etcdutl` are installed on the control plane node.

Install them on the kind node, in the version of the etcd of the cluster:

```bash
ETCD_VER=$(kubectl get pod -n kube-system etcd-$CP -o jsonpath='{.spec.containers[0].image}' | sed 's/.*://; s/-.*//')
echo $ETCD_VER
# 3.6.6
docker exec $CP sh -c "curl -fsSL https://github.com/etcd-io/etcd/releases/download/v$ETCD_VER/etcd-v$ETCD_VER-linux-amd64.tar.gz \
  | tar xz -C /usr/local/bin --strip-components=1 etcd-v$ETCD_VER-linux-amd64/etcdctl etcd-v$ETCD_VER-linux-amd64/etcdutl"
docker exec $CP etcdctl version
```

## Exercise 1: the keys of the Kubernetes objects

1. Which address does etcd listen on? Which certificates does a client need?
2. List the keys of the `default` namespace in etcd. Under which prefix does Kubernetes store its objects?

{{% notice tip %}}
Read the command line of the `etcd` static pod: `--listen-client-urls`, `--trusted-ca-file`, `--cert-file`, `--key-file`.
{{% /notice %}}

{{%expand "Solution" %}}
```bash
# In the exam: kubectl describe pod -n kube-system etcd-<node>, or read /etc/kubernetes/manifests/etcd.yaml
kubectl get pod -n kube-system etcd-$CP -o jsonpath='{.spec.containers[0].command}' | tr ',' '\n' | grep -E 'client-urls|trusted-ca|cert-file|key-file'
# "--advertise-client-urls=https://172.18.0.3:2379"
# "--cert-file=/etc/kubernetes/pki/etcd/server.crt"
# "--key-file=/etc/kubernetes/pki/etcd/server.key"
# "--listen-client-urls=https://127.0.0.1:2379,https://172.18.0.3:2379"
# "--trusted-ca-file=/etc/kubernetes/pki/etcd/ca.crt"
```

etcd only accepts the clients which present a certificate signed by its CA (`--client-cert-auth=true`). The API server uses `/etc/kubernetes/pki/apiserver-etcd-client.crt`; on the node, `etcdctl` can use the `server` certificate of etcd.

```bash
# In the exam: ssh to the control plane node, then run the commands without docker exec
etcdctl() {
  docker exec $CP etcdctl --endpoints=https://127.0.0.1:2379 \
    --cacert=/etc/kubernetes/pki/etcd/ca.crt \
    --cert=/etc/kubernetes/pki/etcd/server.crt \
    --key=/etc/kubernetes/pki/etcd/server.key "$@"
}
etcdctl endpoint health
# https://127.0.0.1:2379 is healthy: successfully committed proposal: took = ...

etcdctl get /registry --prefix --keys-only | grep /default/ | head
# /registry/configmaps/default/kube-root-ca.crt
# /registry/serviceaccounts/default/default
# /registry/services/endpoints/default/kubernetes
# /registry/services/specs/default/kubernetes
etcdctl get /registry --prefix --keys-only | grep -c .
```

Kubernetes stores each object under `/registry/<resource>/<namespace>/<name>`, or `/registry/<resource>/<name>` for the cluster-wide ones. OpenShift adds its own resources under `/openshift.io`.

The values are in protobuf, not in JSON: `etcdctl get` shows them with binary parts. The Secrets are readable in clear, unless they are encrypted at rest, see the [etcd encryption lab]({{% ref "/1_Labs/etcd-encryption" %}}).
{{% /expand%}}

## Exercise 2: back up etcd

1. Create a ConfigMap `before-backup` in the `default` namespace.
2. Save a snapshot of etcd in `/var/lib/etcd-backup/snapshot.db` on the control plane node, with `etcdctl`.
3. Check the snapshot with `etcdutl`: its hash, its revision, its number of keys.
4. Copy the snapshot out of the node.

{{%expand "Solution" %}}
```bash
kubectl create configmap before-backup --from-literal=state=saved

# In the exam: ssh to the control plane node, then run the commands without docker exec
docker exec $CP mkdir -p /var/lib/etcd-backup
etcdctl snapshot save /var/lib/etcd-backup/snapshot.db
# Snapshot saved at /var/lib/etcd-backup/snapshot.db

docker exec $CP etcdutl --write-out=table snapshot status /var/lib/etcd-backup/snapshot.db
# +----------+----------+------------+------------+---------+
# |   HASH   | REVISION | TOTAL KEYS | TOTAL SIZE | VERSION |
# +----------+----------+------------+------------+---------+
# | 8c8c9a7e |     1503 |       1080 |     4.1 MB |   3.6.0 |
# +----------+----------+------------+------------+---------+

# In the exam: scp from the control plane node
docker cp $CP:/var/lib/etcd-backup/snapshot.db ./etcd-snapshot.db
ls -l etcd-snapshot.db
```

`etcdctl snapshot save` asks a running etcd for a consistent copy of its database, through the network. `etcdutl` works on the files, offline: `etcdctl snapshot status` and `etcdctl snapshot restore` were removed in etcd 3.6, use `etcdutl`.

The snapshot holds all the Secrets of the cluster: store it outside the node, encrypted, with restricted access. A backup left on the control plane node disappears with the node.
{{% /expand%}}

## Exercise 3: restore the snapshot

1. Delete the ConfigMap `before-backup`, and create a ConfigMap `after-backup`.
2. Stop the API server.
3. Restore the snapshot in a new data directory, `/var/lib/etcd-restore`, with `etcdutl`, and make the `etcd` static pod use this directory.
4. Check in etcd which ConfigMaps exist, then start the API server again.

{{% notice warning %}}
**Very important for the CKS exam**: save a copy of the manifests **outside** `/etc/kubernetes/manifests`, e.g. in `/root`. The kubelet runs every file of this directory as a static pod: a backup copy there would start a second etcd.
{{% /notice %}}

{{%expand "Solution" %}}
```bash
kubectl delete configmap before-backup
kubectl create configmap after-backup --from-literal=state=lost
```

Stop the API server first: it keeps the objects in a cache, and would keep serving `after-backup`, a state newer than the restored etcd. The kubelet stops a static pod when its manifest leaves the directory:

```bash
# In the exam: ssh to the control plane node, then run the commands without docker exec
docker exec $CP mv /etc/kubernetes/manifests/kube-apiserver.yaml /root/kube-apiserver.yaml
until ! kubectl get --raw /readyz >/dev/null 2>&1; do sleep 2; done
```

Restore the snapshot in a new directory:

```bash
# In the exam: ssh to the control plane node, then run the commands without docker exec
docker exec $CP etcdutl snapshot restore /var/lib/etcd-backup/snapshot.db --data-dir /var/lib/etcd-restore
docker exec $CP ls /var/lib/etcd-restore
# member
```

The data directory of etcd is the `hostPath` volume `etcd-data` of its manifest. Point it to the restored directory: in the exam, edit the file with `vi`, here `sed` does the change.

```bash
# In the exam: ssh to the control plane node, then run the commands without docker exec
docker exec $CP cp /etc/kubernetes/manifests/etcd.yaml /root/etcd.yaml.orig
docker exec $CP sed -i 's|path: /var/lib/etcd$|path: /var/lib/etcd-restore|' /etc/kubernetes/manifests/etcd.yaml
# diff exits with code 1 when the files differ, which is the expected case here
docker exec $CP diff -u /root/etcd.yaml.orig /etc/kubernetes/manifests/etcd.yaml || true
```

```diff
   - hostPath:
-      path: /var/lib/etcd
+      path: /var/lib/etcd-restore
       type: DirectoryOrCreate
     name: etcd-data
```

Only the `hostPath` changes: in the container, the data directory is still `/var/lib/etcd` (`--data-dir`). The kubelet re-creates the `etcd` pod. Wait until it serves the restored data, then check the ConfigMaps in etcd:

```bash
until etcdctl get /registry/configmaps/default/before-backup --keys-only 2>/dev/null | grep -q before-backup; do sleep 5; done
etcdctl get /registry/configmaps/default --prefix --keys-only
# /registry/configmaps/default/before-backup
# /registry/configmaps/default/kube-root-ca.crt
```

Start the API server again, and check with `kubectl`:

```bash
# In the exam: ssh to the control plane node, then run the command without docker exec
docker exec $CP mv /root/kube-apiserver.yaml /etc/kubernetes/manifests/kube-apiserver.yaml
sleep 10
until kubectl get --raw /readyz >/dev/null 2>&1; do sleep 5; done
kubectl get configmaps
# NAME               DATA   AGE
# before-backup      1      5m
# kube-root-ca.crt   1      10m
```

The cluster is back to the state of the snapshot: `before-backup` exists again, `after-backup` is lost. Everything created after the snapshot is lost too: pods, Deployments, Secrets... With several control plane nodes, stop all the API servers, and restart the controller manager and the scheduler after the restore, so that no component keeps a state newer than etcd.

If etcd or the API server does not come back, read their logs on the node, and restore the copies of the manifests if needed:

<!-- ci-skip -->
```bash
# In the exam: ssh to the control plane node, then run the commands without docker exec
docker exec $CP sh -c 'crictl ps -a | grep etcd'
docker exec $CP crictl logs <container-id>
docker exec $CP cp /root/etcd.yaml.orig /etc/kubernetes/manifests/etcd.yaml
docker exec $CP mv /root/kube-apiserver.yaml /etc/kubernetes/manifests/kube-apiserver.yaml
```
{{% /expand%}}

## Questions

1. Why restore in a new directory, rather than in `/var/lib/etcd`?
2. Who can read the snapshot of etcd? What does it contain?
3. How does the restore work on a cluster with three control plane nodes?

{{%expand "Answers" %}}
1. `etcdutl snapshot restore` refuses a directory which is not empty, and keeping the old directory allows going back if the restore fails.
2. Anybody who can read the file: it contains all the objects of the cluster, so all the Secrets, in clear unless they are encrypted at rest. Protect it like the keys of the cluster.
3. Restore the same snapshot on each member, with its own `--name`, `--initial-cluster` and `--initial-advertise-peer-urls`: the restore creates a new etcd cluster from the snapshot. See [Restoring an etcd cluster](https://kubernetes.io/docs/tasks/administer-cluster/configure-upgrade-etcd/#restoring-an-etcd-cluster).
{{% /expand%}}

## Clean up

```bash
kubectl delete configmap before-backup --ignore-not-found
rm -f etcd-snapshot.db
# Delete the cluster only if it was created for the lab
if [ -z "${CLUSTER_NAME:-}" ]; then kind delete cluster --name $CLUSTER; fi
```

On the CKS training server, your cluster keeps the restored etcd, in `/var/lib/etcd-restore`: it is harmless for the next labs.
