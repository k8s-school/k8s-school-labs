---
title: 'AppArmor Security Profiles'
date: 2024-06-06T16:00:00+10:00
draft: false
weight: 120
tags: ["CKS", "AppArmor", "Security", "Profiles"]
---

**Author:** Fabrice JAMMES ([LinkedIn](https://www.linkedin.com/in/fabrice-jammes-5b29b042/)).

## Objective

Confine a container with an [AppArmor](https://kubernetes.io/docs/tutorials/security/apparmor/) profile: a Linux security module which allows or denies the access of a process to files, capabilities and network, by path.

| Profile mode | Effect |
|---|---|
| `enforce` | The forbidden accesses are denied and logged |
| `complain` | The forbidden accesses are allowed and logged: to write a profile |

A profile is loaded in the kernel of **each node** with `apparmor_parser`, then a pod uses it with the `appArmorProfile` field of its `securityContext` (GA since Kubernetes 1.30, it replaces the `container.apparmor.security.beta.kubernetes.io` annotations).

The CKS curriculum lists "Use kernel hardening tools such as AppArmor, seccomp" in the *System hardening* domain.

## Prerequisites

The lab loads profiles in the kernel of the nodes: use a kind cluster of your own, never a shared one. The kernel must support AppArmor (Ubuntu, Debian):

```bash
cat /sys/module/apparmor/parameters/enabled
# Y

# On the CKS training server, use your own cluster ($CLUSTER_NAME),
# elsewhere create a cluster for the lab
CLUSTER=${CLUSTER_NAME:-apparmor-$(whoami)}
kind get clusters | grep -qx $CLUSTER || kind create cluster --name $CLUSTER
kind export kubeconfig --name $CLUSTER
kubectl create namespace apparmor
kubectl config set-context --current --namespace=apparmor
mkdir -p $HOME/apparmor && cd $HOME/apparmor
```

<!-- ci-exec
# A new cluster: wait for the service account of the namespace
until kubectl get serviceaccount default >/dev/null 2>&1; do sleep 2; done
-->

### Prepare the kind nodes

A real node (Ubuntu, Debian) already has the AppArmor tools, and so do the nodes of the exam. The kind nodes are containers: install `apparmor_parser` in them, mount the AppArmor file system, and restart containerd and the kubelet, which check AppArmor at startup.

```bash
for node in $(kind get nodes --name $CLUSTER); do
  docker exec $node sh -c 'apt-get update -qq && DEBIAN_FRONTEND=noninteractive apt-get install -y -qq apparmor >/dev/null'
  docker exec $node sh -c 'mountpoint -q /sys/kernel/security || mount -t securityfs securityfs /sys/kernel/security'
  docker exec $node systemctl restart containerd kubelet
done
kubectl wait --for=condition=Ready node --all --timeout=120s
```

## Exercise 1: write and load a profile

Write the profile `k8s-deny-write-$(whoami)`, which allows all the file accesses except the writes, and load it in enforce mode on **all** the nodes. Check that the kernel knows it.

{{% notice tip %}}
A profile starts with `profile <name> flags=(attach_disconnected) {`, and its rules look like `file,` (allow all the files) or `deny /** w,` (deny writes everywhere). `apparmor_parser -r <file>` loads or replaces a profile; the loaded profiles are listed in `/sys/kernel/security/apparmor/profiles`.
{{% /notice %}}

{{%expand "Solution" %}}
```bash
PROFILE=k8s-deny-write-$(whoami)
cat <<EOF > $PROFILE
#include <tunables/global>

profile $PROFILE flags=(attach_disconnected) {
  #include <abstractions/base>

  file,

  # Deny all file writes
  deny /** w,
}
EOF
for node in $(kind get nodes --name $CLUSTER); do
  docker cp $PROFILE $node:/etc/apparmor.d/$PROFILE
  docker exec $node apparmor_parser -r /etc/apparmor.d/$PROFILE
done
docker exec $CLUSTER-control-plane grep $PROFILE /sys/kernel/security/apparmor/profiles
# k8s-deny-write-<user> (enforce)
```

On a real cluster, connect to each node (`ssh`) and run `apparmor_parser` there. The profile is in the kernel, not in Kubernetes: a node rebooted or added later does not have it, unless the profile is in `/etc/apparmor.d/` (loaded at boot) or installed by a DaemonSet.

The kind nodes share the kernel of the server: that is why the profile name ends with your account.
{{% /expand%}}

## Exercise 2: a confined pod

Run a pod `deny-write` (image `busybox:1.36`, command `sleep infinity`) confined by your profile. Which profile does its process run under? Try to write a file in `/tmp`, then to read `/etc/hostname`.

{{%expand "Solution" %}}
```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: deny-write
spec:
  securityContext:
    appArmorProfile:
      type: Localhost
      localhostProfile: $PROFILE
  containers:
  - name: main
    image: busybox:1.36
    command: ["sleep", "infinity"]
EOF
kubectl wait --for=condition=Ready pod/deny-write --timeout=120s
kubectl exec deny-write -- cat /proc/1/attr/current
# k8s-deny-write-<user> (enforce)
kubectl exec deny-write -- touch /tmp/new-file || echo "EXPECTED ERROR"
# touch: /tmp/new-file: Permission denied
kubectl exec deny-write -- cat /etc/hostname
# deny-write
```

`localhostProfile` is the **name** of the profile in the kernel, not a file path (unlike seccomp). The field can also be set for one container, in its own `securityContext`.

Older clusters, and older exam tasks, use an annotation per container instead of the field:

```yaml
metadata:
  annotations:
    container.apparmor.security.beta.kubernetes.io/main: localhost/k8s-deny-write-<user>
```
{{% /expand%}}

## Exercise 3: a profile which is not loaded

Run a pod `not-loaded` like `deny-write`, with the profile `k8s-not-loaded`, which does not exist. What is its status? Where is the error?

{{%expand "Solution" %}}
```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: not-loaded
spec:
  securityContext:
    appArmorProfile:
      type: Localhost
      localhostProfile: k8s-not-loaded
  containers:
  - name: main
    image: busybox:1.36
    command: ["sleep", "infinity"]
EOF
sleep 15
kubectl get pod not-loaded
# NAME         READY   STATUS                 RESTARTS   AGE
# not-loaded   0/1     CreateContainerError   0          15s
kubectl get events --field-selector involvedObject.name=not-loaded,reason=Failed -o custom-columns=MESSAGE:.message
# Error: failed to get container spec opts: failed to generate apparmor spec opts: apparmor profile not found k8s-not-loaded
```

As for seccomp, the API server accepts the pod: the container runtime of the node checks the profile. Load the profile on all the nodes, or schedule the pods only on the nodes which have it (`nodeSelector`).
{{% /expand%}}

## Questions

1. Which AppArmor profile does a container get without `appArmorProfile`?
2. How do you write the profile of an application?

{{%expand "Answers" %}}
1. `RuntimeDefault`: the default profile of the container runtime (`cri-containerd.apparmor.d` for containerd), if AppArmor is enabled on the node. It denies some sensitive accesses (writes in `/proc`, `/sys`, mount...). `Unconfined` disables AppArmor: the `baseline` level of the Pod Security Standards forbids it.
2. Load a first profile in `complain` mode (`apparmor_parser -C`), run the application, and read the logged accesses (`journalctl -k | grep apparmor`, or `aa-logprof`, which proposes the rules). Then load it in `enforce` mode. The [Security Profiles Operator](https://github.com/kubernetes-sigs/security-profiles-operator) automates this on Kubernetes.
{{% /expand%}}

## Clean up

```bash
kubectl delete namespace apparmor
kubectl config set-context --current --namespace=default
for node in $(kind get nodes --name $CLUSTER); do
  # The kind nodes share one kernel: the profile is already unloaded after the first node
  docker exec $node apparmor_parser -R /etc/apparmor.d/$PROFILE 2>/dev/null || true
  docker exec $node rm /etc/apparmor.d/$PROFILE
done
cd $HOME && rm -rf $HOME/apparmor
# Delete the cluster only if it was created for the lab
if [ -z "${CLUSTER_NAME:-}" ]; then kind delete cluster --name $CLUSTER; fi
```
