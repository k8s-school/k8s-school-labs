---
title: 'Sandboxed containers with gVisor and RuntimeClass'
date: 2026-10-28T09:00:00+01:00
draft: false
weight: 83
tags: ["kubernetes", "gVisor", "RuntimeClass", "sandbox", "containerd", "CKS"]
---

**Author:** Fabrice JAMMES ([LinkedIn](https://www.linkedin.com/in/fabrice-jammes-5b29b042/)).

## Objective

- Download a binary and verify it with its checksum
- Install the [gVisor](https://gvisor.dev/) runtime (`runsc`) on the nodes, and declare it to containerd
- Run a pod in a sandbox with a `RuntimeClass`, and see the difference with a normal pod

A normal container shares the kernel of the node: a kernel exploit from a container gives the node. gVisor runs the container on top of a kernel written in Go (the *Sentry*), which runs in user space and handles the system calls of the container: the kernel of the node only sees a few, filtered system calls of the Sentry.

The CKS curriculum lists "Understand and implement isolation techniques (multi-tenancy, sandboxed containers, etc.)" in the *Minimize microservice vulnerabilities* domain, and "Verify platform binaries before deploying" in the *Cluster setup* domain.

## Prerequisites

The lab installs a runtime on the nodes: use a kind cluster of your own, never a shared one.

```bash
# On the CKS training server, use your own cluster ($CLUSTER_NAME),
# elsewhere create a cluster for the lab
CLUSTER=${CLUSTER_NAME:-gvisor-$(whoami)}
kind get clusters | grep -qx $CLUSTER || kind create cluster --name $CLUSTER
kubectx kind-$CLUSTER
mkdir -p $HOME/gvisor && cd $HOME/gvisor
```

## Exercise 1: download and verify gVisor

Download the gVisor release `20261005` for `x86_64`, and its checksum, from `https://storage.googleapis.com/gvisor/releases/release/20261005/x86_64/`: the files are `gvisor.tar.bz2` and `gvisor.tar.bz2.sha512`. Verify the archive, then extract it.

{{%expand "Solution" %}}
```bash
URL=https://storage.googleapis.com/gvisor/releases/release/20261005/x86_64
curl -fsSLO $URL/gvisor.tar.bz2
curl -fsSLO $URL/gvisor.tar.bz2.sha512
cat gvisor.tar.bz2.sha512
sha512sum -c gvisor.tar.bz2.sha512
# gvisor.tar.bz2: OK
tar xjf gvisor.tar.bz2
ls
# containerd-shim-runsc-v1  gvisor-bin  gvisor.tar.bz2  gvisor.tar.bz2.sha512  runsc
```

What does a modified archive give?

```bash
cp gvisor.tar.bz2 /tmp/gvisor-$(whoami).tar.bz2
echo "malware" >> /tmp/gvisor-$(whoami).tar.bz2
echo "$(cut -d' ' -f1 gvisor.tar.bz2.sha512)  /tmp/gvisor-$(whoami).tar.bz2" | sha512sum -c || echo "EXPECTED ERROR"
# /tmp/gvisor-<user>.tar.bz2: FAILED
rm /tmp/gvisor-$(whoami).tar.bz2
```

In the exam, the same check applies to the Kubernetes binaries (`kubelet`, `kubectl`...): compare `sha512sum <binary>` with the `.sha512` file published next to the release. A checksum downloaded from the same server as the binary only detects a corrupted download: a signature (cosign, GPG) also proves who published it.
{{% /expand%}}

## Exercise 2: install runsc on the nodes

On each node of your cluster:

1. copy `runsc`, `containerd-shim-runsc-v1` and the directory `gvisor-bin` in `/usr/local/bin`
2. declare the runtime `runsc` in `/etc/containerd/config.toml`, with `runtime_type = "io.containerd.runsc.v1"`
3. restart containerd

{{% notice tip %}}
`kind get nodes --name $CLUSTER` lists the nodes: they are docker containers, use `docker cp` and `docker exec`. Look at the section of the `runc` runtime in `/etc/containerd/config.toml` to find the right syntax.
{{% /notice %}}

{{%expand "Solution" %}}
```bash
docker exec $CLUSTER-control-plane grep -A2 "runtimes.runc\]" /etc/containerd/config.toml
for node in $(kind get nodes --name $CLUSTER); do
  docker cp runsc $node:/usr/local/bin/runsc
  docker cp containerd-shim-runsc-v1 $node:/usr/local/bin/containerd-shim-runsc-v1
  docker cp gvisor-bin $node:/usr/local/bin/
  docker exec $node grep -q "runtimes.runsc\]" /etc/containerd/config.toml || \
    printf '%s\n' '[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runsc]' \
      '  runtime_type = "io.containerd.runsc.v1"' | docker exec -i $node tee -a /etc/containerd/config.toml
  docker exec $node systemctl restart containerd
done
kubectl wait --for=condition=Ready node --all --timeout=120s
```

containerd finds the shim from the runtime type: `io.containerd.runsc.v1` means the binary `containerd-shim-runsc-v1` in the `PATH`. `runsc` needs the binaries of `gvisor-bin` next to it: without them, the pods fail with `sidecar "gvisor_sentry" not usable`.

Restarting containerd does not stop the running containers.
{{% /expand%}}

## Exercise 3: a RuntimeClass and a sandboxed pod

Create a `RuntimeClass` named `gvisor`, whose handler is `runsc`. Then run two nginx pods: `sandboxed`, which uses the `gvisor` RuntimeClass, and `normal`, which does not. Compare the output of `dmesg` and `uname -r` in both pods.

{{%expand "Solution" %}}
```bash
cat <<EOF | kubectl apply -f -
apiVersion: node.k8s.io/v1
kind: RuntimeClass
metadata:
  name: gvisor
handler: runsc
---
apiVersion: v1
kind: Pod
metadata:
  name: sandboxed
spec:
  runtimeClassName: gvisor
  containers:
  - name: nginx
    image: nginx:1.27
EOF
kubectl run normal --image=nginx:1.27
kubectl wait --for=condition=Ready pod/sandboxed pod/normal --timeout=120s

kubectl exec sandboxed -- dmesg | head -3
# [    0.000000] Starting gVisor...
kubectl exec normal -- dmesg || echo "EXPECTED ERROR"
# dmesg: read kernel buffer failed: Operation not permitted
kubectl exec sandboxed -- uname -r
# 4.19.0-gvisor
kubectl exec normal -- uname -r
# the kernel version of the node
```

The `handler` of the RuntimeClass is the name of the runtime in the containerd configuration. The `normal` pod sees the kernel of the node; the `sandboxed` pod sees the Sentry, the kernel of gVisor.
{{% /expand%}}

## Exercise 4: from the node

On the node of the pods, list the processes named `nginx`. Then delete the `normal` pod and list them again. Which processes run the `sandboxed` pod?

{{%expand "Solution" %}}
```bash
NODE=$(kubectl get pod sandboxed -o jsonpath='{.spec.nodeName}')
docker exec $NODE sh -c 'ps -eo comm | grep -x nginx | wc -l'
kubectl delete pod normal
sleep 5
docker exec $NODE sh -c 'ps -eo comm | grep -x nginx | wc -l'
# 0
docker exec $NODE sh -c 'ps -eo comm | grep -E "runsc|gvisor" | sort | uniq -c'
```

The processes of a sandboxed container are not processes of the node: they run inside the Sentry (`gvisor_sentry`). A tool on the node which watches the system calls of the containers, like [Falco]({{% ref "/1_Labs/falco" %}}) with its default kernel driver, no longer sees them: Falco needs its gVisor integration for these pods.
{{% /expand%}}

## Questions

1. What happens if a pod with `runtimeClassName: gvisor` is scheduled on a node without `runsc`? How do you avoid it?
2. What does gVisor cost?
3. Which other sandbox runtimes do you know?

{{%expand "Answers" %}}
1. The pod stays in `ContainerCreating`, with the event `FailedCreatePodSandBox ... no runtime for "runsc" is configured`. Label the nodes which have the runtime, and set `scheduling.nodeSelector` in the RuntimeClass: the pods of this class are only scheduled on these nodes.
2. Performance (the system calls, the file system and the network go through the Sentry) and compatibility: some system calls and some `/proc` or `/sys` files are not implemented. Use it for the untrusted workloads (code of the users, multi-tenancy), not for everything.
3. [Kata Containers](https://katacontainers.io/) runs each pod in a small virtual machine, with its own Linux kernel: stronger isolation, but it needs hardware virtualization on the nodes. On the exam, the RuntimeClass and the handler name are given in the task.
{{% /expand%}}

## Clean up

```bash
kubectl delete pod sandboxed normal --ignore-not-found
kubectl delete runtimeclass gvisor
cd $HOME && rm -rf $HOME/gvisor
# Delete the cluster only if it was created for the lab
[ -z "$CLUSTER_NAME" ] && kind delete cluster --name $CLUSTER
```

On the CKS training server, `runsc` stays installed in the nodes of your cluster: it is harmless for the next labs.
