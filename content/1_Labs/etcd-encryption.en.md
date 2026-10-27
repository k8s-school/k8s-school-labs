---
title: 'Encrypt Secrets at rest in etcd'
date: 2026-10-27T10:00:00+01:00
draft: false
weight: 216
tags: ["kubernetes", "etcd", "secret", "encryption", "kube-apiserver", "static pod", "CKS"]
---

**Author:** Fabrice JAMMES ([LinkedIn](https://www.linkedin.com/in/fabrice-jammes-5b29b042/)).

## Objective

- Read a `Secret` directly in etcd, and see that it is only base64-encoded, not encrypted
- Configure the API server to encrypt the Secrets before writing them in etcd
- Encrypt the existing Secrets

See [Encrypting Confidential Data at Rest](https://kubernetes.io/docs/tasks/administer-cluster/encrypt-data/).

## Prerequisites

The API server restarts during the lab: use a kind cluster of your own, never a shared one.

```bash
# On the CKS training server, use your own cluster ($CLUSTER_NAME),
# elsewhere create a cluster for the lab
CLUSTER=${CLUSTER_NAME:-etcd-$(whoami)}
kind get clusters | grep -qx $CLUSTER || kind create cluster --name $CLUSTER
kubectx kind-$CLUSTER
CP=$CLUSTER-control-plane
```

`$CP` is the control plane node: kind runs it as a docker container, and `etcd` runs in it as a static pod.

## Exercise 1: read a Secret in etcd

Create a Secret `s1` in the `default` namespace, with the key `password` and the value `my-secret-password`.
Then read it with `etcdctl` in the `etcd` pod. The key of a Secret in etcd is `/registry/secrets/<namespace>/<name>`.

{{% notice tip %}}
`etcdctl` needs the client certificates of etcd: they are in `/etc/kubernetes/pki/etcd/` on the control plane node, look at the `etcd` static pod manifest to find them.
{{% /notice %}}

{{%expand "Solution" %}}
```bash
kubectl create secret generic s1 --from-literal=password=my-secret-password

# The etcd static pod manifest gives the certificates
docker exec $CP grep -E "cert|key" /etc/kubernetes/manifests/etcd.yaml

etcdctl() {
  kubectl exec -n kube-system etcd-$CP -- etcdctl \
    --cacert=/etc/kubernetes/pki/etcd/ca.crt \
    --cert=/etc/kubernetes/pki/etcd/server.crt \
    --key=/etc/kubernetes/pki/etcd/server.key "$@"
}
etcdctl get /registry/secrets/default/s1 | hexdump -C
```

The value is readable in clear: `my-secret-password`. A `Secret` is only base64-encoded in the API, and stored as is in etcd: anybody who reads etcd, or one of its backups, reads all the Secrets of the cluster.
{{% /expand%}}

## Exercise 2: configure encryption at rest

### Write the encryption configuration

On the control plane node, create the file `/etc/kubernetes/enc/enc.yaml`: an `EncryptionConfiguration` which encrypts the `secrets` resource with the `aescbc` provider and a random 32-byte key, and still reads the unencrypted data (`identity` provider).

{{%expand "Solution" %}}
```bash
KEY=$(head -c 32 /dev/urandom | base64)
docker exec $CP mkdir -p /etc/kubernetes/enc
cat <<EOF | docker exec -i $CP tee /etc/kubernetes/enc/enc.yaml
apiVersion: apiserver.config.k8s.io/v1
kind: EncryptionConfiguration
resources:
  - resources:
      - secrets
    providers:
      - aescbc:
          keys:
            - name: key1
              secret: $KEY
      - identity: {}
EOF
```

The order of the providers matters: the **first** one encrypts the new data, all of them are tried to read the existing data. With `identity` first, nothing would be encrypted.
{{% /expand%}}

### Configure the API server

The API server is a static pod: edit its manifest `/etc/kubernetes/manifests/kube-apiserver.yaml` on the control plane node, to:

- add the flag `--encryption-provider-config=/etc/kubernetes/enc/enc.yaml`
- mount the directory `/etc/kubernetes/enc` of the node in the pod (`hostPath` volume)

{{% notice warning %}}
Save a copy of the manifest **outside** `/etc/kubernetes/manifests`: the kubelet runs every file of this directory as a static pod, a backup copy there would start a second API server.
{{% /notice %}}

{{%expand "Solution" %}}
In the exam, edit the file with `vi`. Here, `sed` does the three changes:

```bash
docker exec $CP cp /etc/kubernetes/manifests/kube-apiserver.yaml /root/kube-apiserver.yaml.orig
docker exec $CP sed -i \
  -e 's|^    - kube-apiserver$|&\n    - --encryption-provider-config=/etc/kubernetes/enc/enc.yaml|' \
  -e 's|^    volumeMounts:$|&\n    - mountPath: /etc/kubernetes/enc\n      name: enc\n      readOnly: true|' \
  -e 's|^  volumes:$|&\n  - hostPath:\n      path: /etc/kubernetes/enc\n      type: DirectoryOrCreate\n    name: enc|' \
  /etc/kubernetes/manifests/kube-apiserver.yaml
docker exec $CP grep -n -A3 "encryption-provider-config\|name: enc" /etc/kubernetes/manifests/kube-apiserver.yaml
```

The kubelet sees the change and re-creates the API server pod. Wait until the API server answers again:

```bash
sleep 10
until kubectl get --raw /readyz >/dev/null 2>&1; do sleep 5; done
kubectl get pods -n kube-system -l component=kube-apiserver
kubectl get pod -n kube-system kube-apiserver-$CP -o yaml | grep encryption-provider-config
```

If the API server does not come back, read its logs on the node: `docker exec $CP sh -c 'crictl ps -a | grep kube-apiserver'`, then `crictl logs <container-id>`.
{{% /expand%}}

## Exercise 3: check the encryption

Create a Secret `s2`, then read `s1` and `s2` in etcd. Which one is encrypted? How do you encrypt the other one?

{{%expand "Solution" %}}
```bash
kubectl create secret generic s2 --from-literal=password=my-secret-password
etcdctl get /registry/secrets/default/s2 | hexdump -C | head
# The value starts with k8s:enc:aescbc:v1:key1: and the password is not readable
etcdctl get /registry/secrets/default/s1 | hexdump -C | grep -c my-secret
# 1: s1 is still in clear
```

The encryption is done when the API server **writes** an object: the Secrets created before the change stay in clear until they are written again. Rewrite all the Secrets:

```bash
kubectl get secrets -A -o json | kubectl replace -f -
etcdctl get /registry/secrets/default/s1 | hexdump -C | head
```

The API server still reads the Secrets transparently:

```bash
kubectl get secret s1 -o jsonpath='{.data.password}' | base64 -d; echo
```
{{% /expand%}}

## Questions

1. Where is the encryption key? Who can read it?
2. Is an etcd backup of this cluster still a sensitive file?
3. How do you rotate the key?

{{%expand "Answers" %}}
1. In clear, in `/etc/kubernetes/enc/enc.yaml` on each control plane node: root on these nodes reads all the Secrets. A KMS provider (`kms` v2) keeps the key in an external key manager (Vault, cloud KMS), and only a data encryption key encrypted by the KMS is stored on the node.
2. Yes, for the other resources (ConfigMaps, ...), which are not encrypted. The Secrets are not readable without the key: back up the key separately from the etcd snapshots.
3. Add `key2` **after** `key1` and restart all the API servers (they can read both keys), then move `key2` first and restart them (they encrypt with `key2`), rewrite all the Secrets with `kubectl replace`, and finally remove `key1`.
{{% /expand%}}

## Clean up

```bash
# Delete the cluster only if it was created for the lab
[ -z "$CLUSTER_NAME" ] && kind delete cluster --name $CLUSTER
```

On the CKS training server, your cluster keeps the encryption at rest: it is harmless for the next labs.
