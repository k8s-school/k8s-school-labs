---
title: 'Security context'
date: 2026-10-27T09:00:00+01:00
draft: false
weight: 80
tags: ["kubernetes", "security context", "capabilities", "CKS", "OpenShift"]
---

**Author:** Fabrice JAMMES ([LinkedIn](https://www.linkedin.com/in/fabrice-jammes-5b29b042/)).

## Objective

Use the `securityContext` of a pod and of its containers to control the user, the Linux capabilities and the filesystem access of the processes, and understand the risks of the host namespaces.

The lab works on a cluster shared by the trainees: each one works in a namespace of their own. On OpenShift, the SCCs reject or modify most of these pods: compare with the [SCC lab]({{% ref "/1_Labs/openshift-scc" %}}).

## Prerequisites

```bash
# The shared kind cluster (on the CKS training server: kind export kubeconfig, then kubectx kind-kind)
kubectx kind-kind
NS=security-context-$(whoami)
kubectl create namespace $NS
kubectl config set-context --current --namespace=$NS
```

All the pods of the lab run `sleep` in an `alpine:3.19` container.

## Exercise 1: the default user

Run a pod `pod-with-defaults` without any security context. Which user runs the process?

{{%expand "Solution" %}}
```bash
kubectl run pod-with-defaults --image=alpine:3.19 --restart=Never -- sleep 999999
kubectl wait --for=condition=Ready pod/pod-with-defaults
kubectl exec pod-with-defaults -- id
# uid=0(root) gid=0(root) groups=0(root),1(bin),2(daemon),...
```

Without a security context, the container runs with the user of the image, here `root`. It is the root user of the node, only restricted by the container isolation: a container escape gives root on the node.
{{% /expand%}}

## Exercise 2: run as a given user

Run a pod `pod-as-user-guest` whose container runs as the user `guest` of the alpine image (uid `405`). Then run a pod `pod-run-as-non-root` with `runAsNonRoot: true` and no user. What happens?

{{%expand "Solution" %}}
```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: pod-as-user-guest
spec:
  containers:
  - name: main
    image: alpine:3.19
    command: ["/bin/sleep", "999999"]
    securityContext:
      runAsUser: 405
---
apiVersion: v1
kind: Pod
metadata:
  name: pod-run-as-non-root
spec:
  containers:
  - name: main
    image: alpine:3.19
    command: ["/bin/sleep", "999999"]
    securityContext:
      runAsNonRoot: true
EOF
kubectl wait --for=condition=Ready pod/pod-as-user-guest
kubectl exec pod-as-user-guest -- id
# uid=405(guest) gid=100(users) groups=100(users)
sleep 10
kubectl get pod pod-run-as-non-root
# STATUS: CreateContainerConfigError
kubectl describe pod pod-run-as-non-root | grep -i "non-root"
# Error: container has runAsNonRoot and image will run as root
```

`runAsNonRoot` does not choose a user: the kubelet refuses to start the container if its user is root. Set `runAsUser` too, or use an image whose `USER` is not root.
{{% /expand%}}

## Exercise 3: privileged container

Run a pod `pod-privileged` with `privileged: true`. Compare the devices visible in `/dev` with `pod-with-defaults`.

{{%expand "Solution" %}}
```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: pod-privileged
spec:
  containers:
  - name: main
    image: alpine:3.19
    command: ["/bin/sleep", "999999"]
    securityContext:
      privileged: true
EOF
kubectl wait --for=condition=Ready pod/pod-privileged
kubectl exec pod-with-defaults -- ls /dev | wc -l
kubectl exec pod-privileged -- ls /dev | wc -l
```

A privileged container sees all the devices of the node (disks, ...) and has all the capabilities: it can mount the disk of the node and read or change any file. Only some system pods need it (CNI, CSI drivers).
{{% /expand%}}

## Exercise 4: Linux capabilities

1. In `pod-with-defaults`, change the owner of `/tmp` to `guest`. Is it allowed?
2. Run a pod `pod-drop-chown-capability` which drops the `CHOWN` capability, and try again.

{{%expand "Solution" %}}
```bash
kubectl exec pod-with-defaults -- chown guest /tmp
kubectl exec pod-with-defaults -- ls -ld /tmp
# drwxrwxrwt ... guest root ... /tmp

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: pod-drop-chown-capability
spec:
  containers:
  - name: main
    image: alpine:3.19
    command: ["/bin/sleep", "999999"]
    securityContext:
      capabilities:
        drop:
        - CHOWN
EOF
kubectl wait --for=condition=Ready pod/pod-drop-chown-capability
kubectl exec pod-drop-chown-capability -- chown guest /tmp || echo "EXPECTED ERROR"
# chown: /tmp: Operation not permitted
```

Even as root, a process can only do what its capabilities allow. The container runtime gives a default set (`CHOWN`, `NET_BIND_SERVICE`, `KILL`, ...): the good practice is `drop: ["ALL"]`, then `add` only what the application needs.

`capabilities.add: ["SYS_TIME"]` would allow the container to change the clock... of the node, shared by all its pods: do not try it on a shared cluster.
{{% /expand%}}

## Exercise 5: read-only root filesystem

Run a pod `pod-with-readonly-filesystem` whose root filesystem is read-only, with an `emptyDir` volume mounted on `/volume`. Where can the container write?

{{%expand "Solution" %}}
```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: pod-with-readonly-filesystem
spec:
  containers:
  - name: main
    image: alpine:3.19
    command: ["/bin/sleep", "999999"]
    securityContext:
      readOnlyRootFilesystem: true
    volumeMounts:
    - name: my-volume
      mountPath: /volume
  volumes:
  - name: my-volume
    emptyDir: {}
EOF
kubectl wait --for=condition=Ready pod/pod-with-readonly-filesystem
kubectl exec pod-with-readonly-filesystem -- touch /new-file || echo "EXPECTED ERROR"
# touch: /new-file: Read-only file system
kubectl exec pod-with-readonly-filesystem -- touch /volume/newfile
kubectl exec pod-with-readonly-filesystem -- ls -l /volume/newfile
```

An attacker cannot install tools or change the binaries of the image: the container is **immutable** at runtime (CKS domain "Monitoring, logging and runtime security"). The application writes only in the volumes.
{{% /expand%}}

## Exercise 6: share a volume between users

Run a pod `pod-with-shared-volume-fsgroup` with two containers, `first` (uid `1111`) and `second` (uid `2222`), sharing an `emptyDir` volume, with `fsGroup: 555` at the pod level. Which group owns the files that `first` writes in the volume, and in `/tmp`?

{{%expand "Solution" %}}
```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: pod-with-shared-volume-fsgroup
spec:
  securityContext:
    fsGroup: 555
    supplementalGroups: [666, 777]
  containers:
  - name: first
    image: alpine:3.19
    command: ["/bin/sleep", "999999"]
    securityContext:
      runAsUser: 1111
    volumeMounts:
    - name: shared-volume
      mountPath: /volume
  - name: second
    image: alpine:3.19
    command: ["/bin/sleep", "999999"]
    securityContext:
      runAsUser: 2222
    volumeMounts:
    - name: shared-volume
      mountPath: /volume
  volumes:
  - name: shared-volume
    emptyDir: {}
EOF
kubectl wait --for=condition=Ready pod/pod-with-shared-volume-fsgroup
kubectl exec pod-with-shared-volume-fsgroup -c first -- sh -c 'id; echo foo > /volume/foo; echo foo > /tmp/foo; ls -l /volume /tmp/foo'
# uid=1111 gid=0(root) groups=0(root),555,666,777
# -rw-r--r-- 1 1111 root ... /tmp/foo
# /volume:
# -rw-r--r-- 1 1111 555  ... foo
```

The volume belongs to the group `fsGroup` (`555`), and so do the files created in it: both containers can share them. Outside of the volume, the files belong to the primary group of the user (`0`, or `runAsGroup` if set).
{{% /expand%}}

## Exercise 7: host namespaces

Look at these two pods, **without running them**. What can their containers see?

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: pod-with-host-network
spec:
  hostNetwork: true
  containers:
  - name: main
    image: alpine:3.19
    command: ["/bin/sleep", "999999"]
---
apiVersion: v1
kind: Pod
metadata:
  name: pod-with-host-pid-and-ipc
spec:
  hostPID: true
  hostIPC: true
  containers:
  - name: main
    image: alpine:3.19
    command: ["/bin/sleep", "999999"]
```

{{%expand "Answer" %}}
- `hostNetwork`: the container uses the network interfaces of the node (`ifconfig` lists them all), it can listen on any port of the node and bypasses the NetworkPolicies.
- `hostPID` and `hostIPC`: the container sees all the processes of the node (`ps aux` lists the kubelet, the other containers...), with their command lines, which may contain secrets.

These fields are forbidden by the `baseline` level of the [Pod Security Standards]({{% ref "/1_Labs/pod-security-admission" %}}): only some infrastructure pods (CNI, monitoring agents) need them.
{{% /expand%}}

## Clean up

```bash
kubectl delete namespace $NS
kubectl config set-context --current --namespace=default
```

The solution of this lab is validated by [ex1-securitycontext.sh](https://github.com/k8s-school/k8s-advanced/blob/master/labs/3_policies/ex1-securitycontext.sh).
