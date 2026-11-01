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
kind export kubeconfig --name $CLUSTER
CP=$CLUSTER-control-plane
```

<!-- ci-exec
# A new cluster: wait for the service account controller
until kubectl get serviceaccount default -n default >/dev/null 2>&1; do sleep 2; done
-->

`$CP` is the control plane node: kind runs it as a docker container, and `etcd` runs in it as a static pod.

## Exercise 1: read a Secret in etcd

Create a Secret `s1` in the `default` namespace, with the key `password` and the value `my-secret-password`.
Then read it with `etcdctl` in the `etcd` pod. The key of a Secret in etcd is `/registry/secrets/<namespace>/<name>`.

{{% notice tip %}}
`etcdctl` needs the client certificates of etcd: they are in `/etc/kubernetes/pki/etcd/` on the control plane node, look at the `etcd` static pod manifest to find them.
{{% /notice %}}

{{%expand "Documentation" %}}
- [Encrypting Confidential Data at Rest: verifying that data is encrypted (etcdctl get with the certificates)](https://kubernetes.io/docs/tasks/administer-cluster/encrypt-data/#verifying-that-data-is-encrypted)
- [Operating etcd clusters for Kubernetes: securing communication](https://kubernetes.io/docs/tasks/administer-cluster/configure-upgrade-etcd/#securing-communication)
{{% /expand%}}

{{%expand "Solution" %}}
```bash
kubectl create secret generic s1 --from-literal=password=my-secret-password

# The etcd pod command line gives the certificates
# In the exam, read them with: kubectl describe pod -n kube-system etcd-$CP
kubectl get pod -n kube-system etcd-$CP -o jsonpath='{.spec.containers[0].command}' | tr ',' '\n' | grep -E '\.(crt|key)'

etcdctl() {
  kubectl exec -n kube-system etcd-$CP -- etcdctl \
    --cacert=/etc/kubernetes/pki/etcd/ca.crt \
    --cert=/etc/kubernetes/pki/etcd/server.crt \
    --key=/etc/kubernetes/pki/etcd/server.key "$@"
}
# --print-value-only: the value without the key; strings: only the readable parts of the binary value
etcdctl get /registry/secrets/default/s1 --print-value-only | strings
# Secret
# s1
# default"
# ...
# password
# my-secret-password
# Opaque
```

The value is readable in clear: `my-secret-password`. A `Secret` is only base64-encoded in the API, and stored as is in etcd: anybody who reads etcd, or one of its backups, reads all the Secrets of the cluster.
{{% /expand%}}

## Exercise 2: configure encryption at rest

### Write the encryption configuration

On the control plane node, create the file `/etc/kubernetes/enc/enc.yaml`: an `EncryptionConfiguration` which encrypts the `secrets` resource with the `aescbc` provider and a random 32-byte key, and still reads the unencrypted data (`identity` provider).

{{%expand "Documentation" %}}
- [Encrypting Confidential Data at Rest: generate the encryption key](https://kubernetes.io/docs/tasks/administer-cluster/encrypt-data/#generate-key-no-kms)
- [Write an encryption configuration file](https://kubernetes.io/docs/tasks/administer-cluster/encrypt-data/#write-an-encryption-configuration-file)
- [Providers: which one encrypts, which ones read](https://kubernetes.io/docs/tasks/administer-cluster/encrypt-data/#providers)
{{% /expand%}}

{{%expand "Solution" %}}
```bash
# aescbc needs a 32-byte key (AES-256): 32 random bytes from the kernel,
# base64-encoded because the configuration file only holds text
KEY=$(head -c 32 /dev/urandom | base64)
# In the exam: ssh to the control plane node, then run the command without docker exec
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

`identity` is the "no encryption" provider: it stores the data as is, in clear text. It is the default when the API server has no encryption configuration, which is why the secret `s1` is readable in etcd.

The order of the providers matters:

- **Write**: the API server encrypts every new or updated secret with the **first** provider of the list only.
- **Read**: it tries the providers in order until one can decode the data. Here `aescbc` reads the new secrets, `identity` reads the secrets written before the change, like `s1`. Without `identity` in the list, the API server could no longer read them.

With `identity` first, every write would use `identity`: the secrets would still be stored in clear text, although the configuration mentions `aescbc`. Put `identity` last, only to read the old data, until all the secrets are rewritten (exercise 3).

The [providers table](https://kubernetes.io/docs/tasks/administer-cluster/encrypt-data/#providers) rates `aescbc` as weak (CBC is vulnerable to padding oracle attacks), `secretbox` as strong, and `kms` v2 as the strongest. The exam asks for the provider named in the task: the configuration is the same for `aesgcm` and `secretbox`, only the provider name changes.
{{% /expand%}}

### Configure the API server

The API server is a static pod: edit its manifest `/etc/kubernetes/manifests/kube-apiserver.yaml` on the control plane node, to:

- add the flag `--encryption-provider-config=/etc/kubernetes/enc/enc.yaml`
- mount the directory `/etc/kubernetes/enc` of the node in the pod (`hostPath` volume)

{{% notice warning %}}
**Very important for the CKS exam**: save a copy of the manifest **outside** `/etc/kubernetes/manifests`, e.g. in `/root`. The kubelet runs every file of this directory as a static pod: a backup copy there would start a second API server.
{{% /notice %}}

{{%expand "Documentation" %}}
- [Encrypting Confidential Data at Rest: use the new encryption configuration file (flag, volume and volumeMount)](https://kubernetes.io/docs/tasks/administer-cluster/encrypt-data/#use-the-new-encryption-configuration-file)
- [Static Pods: the kubelet watches the manifests directory](https://kubernetes.io/docs/tasks/configure-pod-container/static-pod/#static-pod-creation)
{{% /expand%}}

{{%expand "Solution" %}}
In the exam, edit the file with `vi`. Here, `sed` does the three changes:

```bash
# In the exam: ssh to the control plane node, then run the command without docker exec
docker exec $CP cp /etc/kubernetes/manifests/kube-apiserver.yaml /root/kube-apiserver.yaml.orig
docker exec $CP sed -i \
  -e 's|^    - kube-apiserver$|&\n    - --encryption-provider-config=/etc/kubernetes/enc/enc.yaml|' \
  -e 's|^    volumeMounts:$|&\n    - mountPath: /etc/kubernetes/enc\n      name: enc\n      readOnly: true|' \
  -e 's|^  volumes:$|&\n  - hostPath:\n      path: /etc/kubernetes/enc\n      type: DirectoryOrCreate\n    name: enc|' \
  /etc/kubernetes/manifests/kube-apiserver.yaml
# Check the changes against the backup
# diff exits with code 1 when the files differ, which is the expected case here:
# "|| true" prevents a script running with "set -e" (like the CI of this page) from stopping
docker exec $CP diff -u /root/kube-apiserver.yaml.orig /etc/kubernetes/manifests/kube-apiserver.yaml || true
```

The diff shows the three additions: the flag, the `volumeMount` and the `hostPath` volume:

```diff
@@ -12,6 +12,7 @@
   containers:
   - command:
     - kube-apiserver
+    - --encryption-provider-config=/etc/kubernetes/enc/enc.yaml
     - --advertise-address=172.18.0.5
@@ -80,6 +81,9 @@
     volumeMounts:
+    - mountPath: /etc/kubernetes/enc
+      name: enc
+      readOnly: true
     - mountPath: /etc/ssl/certs
@@ -103,6 +107,10 @@
   volumes:
   - hostPath:
+      path: /etc/kubernetes/enc
+      type: DirectoryOrCreate
+    name: enc
+  - hostPath:
       path: /etc/ssl/certs
```

The kubelet sees the change and re-creates the API server pod. Wait until the API server answers again:

```bash
sleep 10
until kubectl get --raw /readyz >/dev/null 2>&1; do sleep 5; done
kubectl get pods -n kube-system -l component=kube-apiserver
kubectl get pod -n kube-system kube-apiserver-$CP -o yaml | grep encryption-provider-config
```

If the API server does not come back, read its logs on the node, and restore the copy if needed:

<!-- ci-skip -->
```bash
# In the exam: ssh to the control plane node, then run the commands without docker exec
docker exec $CP sh -c 'crictl ps -a | grep kube-apiserver'
docker exec $CP crictl logs <container-id>
docker exec $CP cp /root/kube-apiserver.yaml.orig /etc/kubernetes/manifests/kube-apiserver.yaml
```
{{% /expand%}}

## Exercise 3: check the encryption

Create a Secret `s2`, then read `s1` and `s2` in etcd. Which one is encrypted? How do you encrypt the other one?

{{%expand "Documentation" %}}
- [Encrypting Confidential Data at Rest: verifying that data is encrypted](https://kubernetes.io/docs/tasks/administer-cluster/encrypt-data/#verifying-that-data-is-encrypted)
- [Ensure all Secrets are encrypted](https://kubernetes.io/docs/tasks/administer-cluster/encrypt-data/#ensure-all-secrets-are-encrypted)
{{% /expand%}}

{{%expand "Solution" %}}
```bash
kubectl create secret generic s2 --from-literal=password=my-secret-password

# s2, written after the change: an encryption header (provider and key name), then binary data
etcdctl get /registry/secrets/default/s2 --print-value-only | grep -a -o 'k8s:enc:[a-z]*:v1:[a-z0-9]*'
# k8s:enc:aescbc:v1:key1
etcdctl get /registry/secrets/default/s2 --print-value-only | strings | grep my-secret-password || echo "password not found"
# password not found

# s1, written before the change: still in clear
etcdctl get /registry/secrets/default/s1 --print-value-only | strings | grep my-secret-password
# my-secret-password
```

The encryption is done when the API server **writes** an object: the Secrets created before the change stay in clear until they are written again. Rewrite all the Secrets:

```bash
kubectl get secrets -A -o json | kubectl replace -f -
etcdctl get /registry/secrets/default/s1 --print-value-only | grep -a -o 'k8s:enc:[a-z]*:v1:[a-z0-9]*'
# k8s:enc:aescbc:v1:key1
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

{{%expand "Documentation" %}}
- [Encrypting Confidential Data at Rest: key storage and protection](https://kubernetes.io/docs/tasks/administer-cluster/encrypt-data/#key-storage)
- [Rotating a decryption key](https://kubernetes.io/docs/tasks/administer-cluster/encrypt-data/#rotating-a-decryption-key)
- [Using a KMS provider for data encryption](https://kubernetes.io/docs/tasks/administer-cluster/kms-provider/)
{{% /expand%}}

{{%expand "Answers" %}}
1. In clear, in `/etc/kubernetes/enc/enc.yaml` on each control plane node: root on these nodes reads all the Secrets. A [KMS provider](https://kubernetes.io/docs/tasks/administer-cluster/kms-provider/#kms-v2) (`kms` v2, stable since Kubernetes 1.29) avoids this: the key encryption key stays in an external key manager (HashiCorp Vault, AWS KMS, Azure Key Vault, Google Cloud KMS). The API server encrypts the Secrets with a data encryption key (DEK), and only stores this DEK encrypted by the KMS: reading the node is no longer enough to decrypt the Secrets. This is called envelope encryption.
2. Yes, for the other resources (ConfigMaps, ...), which are not encrypted. The Secrets are not readable without the key: back up the key separately from the etcd snapshots.
3. Add `key2` **after** `key1` and restart all the API servers (they can read both keys), then move `key2` first and restart them (they encrypt with `key2`), rewrite all the Secrets with `kubectl replace`, and finally remove `key1`.
{{% /expand%}}

## Clean up

```bash
# Delete the cluster only if it was created for the lab
if [ -z "${CLUSTER_NAME:-}" ]; then kind delete cluster --name $CLUSTER; fi
```

On the CKS training server, your cluster keeps the encryption at rest: it is harmless for the next labs.
