---
title: 'Seccomp Security Profiles'
date: 2024-06-06T19:00:00+10:00
draft: false
weight: 90
tags: ["CKS", "Seccomp", "Security", "Linux", "Syscalls"]
---

**Author:** Fabrice JAMMES ([LinkedIn](https://www.linkedin.com/in/fabrice-jammes-5b29b042/)).

## Objective

Restrict the system calls of a container with [seccomp](https://kubernetes.io/docs/tutorials/security/seccomp/) (secure computing mode): a filter in the Linux kernel which allows, denies or logs each system call of a process.

| Profile type | Where is the profile? | Use |
|---|---|---|
| `Unconfined` | None: no filter | The default of the kubelet, unless `--seccomp-default` is set |
| `RuntimeDefault` | Built in the container runtime (containerd, CRI-O) | A good default: denies about 50 dangerous system calls |
| `Localhost` | A JSON file on the node, under `/var/lib/kubelet/seccomp/` | A profile for one application |

The CKS curriculum lists "Use kernel hardening tools such as AppArmor, seccomp" in the *System hardening* domain.

## Prerequisites

The lab writes files on the nodes: use a kind cluster of your own, never a shared one.

```bash
# On the CKS training server, use your own cluster ($CLUSTER_NAME),
# elsewhere create a cluster for the lab
CLUSTER=${CLUSTER_NAME:-seccomp-$(whoami)}
kind get clusters | grep -qx $CLUSTER || kind create cluster --name $CLUSTER
kubectx kind-$CLUSTER
kubectl create namespace seccomp
kubectl config set-context --current --namespace=seccomp
```

<!-- ci-exec
# A new cluster: wait for the service account of the namespace
until kubectl get serviceaccount default >/dev/null 2>&1; do sleep 2; done
-->

## Exercise 1: the default profile

Run two pods with the image `busybox:1.36` and the command `sleep infinity`: `default`, without any security context, and `runtime-default`, with the `RuntimeDefault` seccomp profile. In each pod, read the `Seccomp` field of `/proc/1/status`, then run `unshare -U true`, which creates a user namespace.

{{%expand "Solution" %}}
```bash
kubectl run default --image=busybox:1.36 -- sleep infinity
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: runtime-default
spec:
  securityContext:
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: main
    image: busybox:1.36
    command: ["sleep", "infinity"]
EOF
kubectl wait --for=condition=Ready pod/default pod/runtime-default --timeout=120s

kubectl exec default -- grep Seccomp: /proc/1/status
# Seccomp:	0
kubectl exec runtime-default -- grep Seccomp: /proc/1/status
# Seccomp:	2
kubectl exec default -- unshare -U true && echo "allowed"
# allowed
kubectl exec runtime-default -- unshare -U true || echo "EXPECTED ERROR"
# unshare: unshare(0x10000000): Operation not permitted
```

`Seccomp: 0` means no filter, `2` means a filter is active. Without a security context, the container runs `Unconfined`: it can call `unshare`, used by many container escapes. The `RuntimeDefault` profile denies it.

Set the profile at the pod level (`spec.securityContext`), it applies to all its containers; a container can override it in its own `securityContext`. The `restricted` level of the [Pod Security Standards]({{% ref "/1_Labs/pod-security-admission" %}}) requires `RuntimeDefault` or `Localhost`.
{{% /expand%}}

## Exercise 2: a custom profile

Write the profile `no-mkdir.json`, which allows all the system calls except `mkdir` and `mkdirat`, which return an error. Copy it on **all** the nodes, in `/var/lib/kubelet/seccomp/profiles/`. Then run a pod `no-mkdir` which uses it, and try to create a directory, then a file, in `/tmp`.

{{% notice tip %}}
A profile is a JSON document with a `defaultAction` and a list of `syscalls` with their `action`: `SCMP_ACT_ALLOW`, `SCMP_ACT_ERRNO`, `SCMP_ACT_LOG`... The path in the pod is relative to `/var/lib/kubelet/seccomp/`.
{{% /notice %}}

{{%expand "Solution" %}}
```bash
for node in $(kind get nodes --name $CLUSTER); do
  docker exec $node mkdir -p /var/lib/kubelet/seccomp/profiles
  cat <<EOF | docker exec -i $node tee /var/lib/kubelet/seccomp/profiles/no-mkdir.json
{
  "defaultAction": "SCMP_ACT_ALLOW",
  "syscalls": [
    {
      "names": ["mkdir", "mkdirat"],
      "action": "SCMP_ACT_ERRNO"
    }
  ]
}
EOF
done

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: no-mkdir
spec:
  securityContext:
    seccompProfile:
      type: Localhost
      localhostProfile: profiles/no-mkdir.json
  containers:
  - name: main
    image: busybox:1.36
    command: ["sleep", "infinity"]
EOF
kubectl wait --for=condition=Ready pod/no-mkdir --timeout=120s
kubectl exec no-mkdir -- mkdir /tmp/new-dir || echo "EXPECTED ERROR"
# mkdir: can't create directory '/tmp/new-dir': Operation not permitted
kubectl exec no-mkdir -- touch /tmp/new-file && echo "allowed"
# allowed
```

The kubelet reads the profile on the node where the pod runs: a missing file on one node makes the pods of this node fail, hence the copy on all the nodes. In the exam, the task often gives a profile to copy in `/var/lib/kubelet/seccomp/` of a node, with `scp` or `ssh`.

A real profile does the opposite: `defaultAction: SCMP_ACT_ERRNO` and the list of the system calls the application needs. Writing it by hand is long: the [Security Profiles Operator](https://github.com/kubernetes-sigs/security-profiles-operator) records the system calls of an application and generates the profile.
{{% /expand%}}

## Exercise 3: a missing profile

Run a pod `missing-profile` whose `Localhost` profile is `profiles/missing.json`, a file which does not exist. What is the status of the pod? Where is the error?

{{%expand "Solution" %}}
```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: missing-profile
spec:
  securityContext:
    seccompProfile:
      type: Localhost
      localhostProfile: profiles/missing.json
  containers:
  - name: main
    image: busybox:1.36
    command: ["sleep", "infinity"]
EOF
sleep 15
kubectl get pod missing-profile
# NAME              READY   STATUS                 RESTARTS   AGE
# missing-profile   0/1     CreateContainerError   0          15s
kubectl get events --field-selector involvedObject.name=missing-profile,reason=Failed -o custom-columns=MESSAGE:.message
# Error: failed to create containerd container: cannot load seccomp profile
#   "/var/lib/kubelet/seccomp/profiles/missing.json": open ...: no such file or directory
```

The API server accepts the pod: the profile is only read by the container runtime, on the node. The error is in the events of the pod.
{{% /expand%}}

## Questions

1. How do you apply `RuntimeDefault` to all the pods of a cluster, without changing their manifests?
2. What is the difference with AppArmor?

{{%expand "Answers" %}}
1. Start the kubelets with `--seccomp-default` (or `seccompDefault: true` in their configuration file): the pods without a profile get `RuntimeDefault` instead of `Unconfined`. Test the applications first: a few need a system call that `RuntimeDefault` denies.
2. Seccomp filters **system calls**, whatever their arguments: "this process cannot call `mkdir`". [AppArmor]({{% ref "/1_Labs/apparmor" %}}) filters **access to resources**, by path: "this process cannot write in `/etc`". Both are often used together.
{{% /expand%}}

## Clean up

```bash
kubectl delete namespace seccomp
kubectl config set-context --current --namespace=default
for node in $(kind get nodes --name $CLUSTER); do
  docker exec $node rm -f /var/lib/kubelet/seccomp/profiles/no-mkdir.json
done
# Delete the cluster only if it was created for the lab
if [ -z "${CLUSTER_NAME:-}" ]; then kind delete cluster --name $CLUSTER; fi
```

The [seccomp.sh](https://github.com/k8s-school/k8s-advanced/blob/master/labs/6_security_hardening/seccomp.sh) script of the k8s-advanced repository runs more profiles, on a cluster it creates.
