---
title: 'Pod Security Admission'
date: 2026-10-27T12:30:00+01:00
draft: false
weight: 81
tags: ["kubernetes", "Pod Security Standards", "admission", "CKS", "OpenShift"]
---

**Author:** Fabrice JAMMES ([LinkedIn](https://www.linkedin.com/in/fabrice-jammes-5b29b042/)).

## Objective

Apply the [Pod Security Standards](https://kubernetes.io/docs/concepts/security/pod-security-standards/) to a namespace with the Pod Security Admission controller:

| Level | Meaning |
|---|---|
| `privileged` | No restriction |
| `baseline` | Blocks the known privilege escalations: `privileged`, host namespaces, `hostPath`, extra capabilities... |
| `restricted` | Hardened pods: non-root user, `allowPrivilegeEscalation: false`, all capabilities dropped, seccomp profile |

Each level is applied in one or more modes, with a namespace label `pod-security.kubernetes.io/<mode>=<level>`:

| Mode | Effect on a pod which violates the level |
|---|---|
| `enforce` | Rejected |
| `audit` | Accepted, with an annotation in the audit log |
| `warn` | Accepted, with a warning for the user |

The lab works on a cluster shared by the trainees: the levels are set on a namespace of your own. Do the [security context lab]({{% ref "/1_Labs/security-context" %}}) first.

## Prerequisites

```bash
# The shared kind cluster (on the CKS training server: kubectx kind-$CLUSTER_NAME)
kubectx kind-kind
NS=psa-$(whoami)
kubectl create namespace $NS
kubectl config set-context --current --namespace=$NS
```

## Exercise 1: is Pod Security Admission enabled?

Check that the `PodSecurity` admission plugin is enabled in the API server.

{{%expand "Solution" %}}
```bash
APISERVER_POD=$(kubectl -n kube-system get pods -l component=kube-apiserver -o jsonpath='{.items[0].metadata.name}')
kubectl -n kube-system exec $APISERVER_POD -- kube-apiserver -h | grep "default enabled plugins" | grep -o PodSecurity
```

`PodSecurity` is enabled by default since Kubernetes 1.23 (GA in 1.25), it replaced the PodSecurityPolicies.
{{% /expand%}}

## Exercise 2: enforce the restricted level

Enforce the `restricted` level on your namespace. Then try to create a privileged pod, without really creating it (`--dry-run=server`).

{{%expand "Solution" %}}
```bash
kubectl label namespace $NS pod-security.kubernetes.io/enforce=restricted
kubectl run test --image=busybox:1.36 --privileged --dry-run=server || echo "EXPECTED ERROR"
# Error from server (Forbidden): pods "test" is forbidden: violates PodSecurity "restricted:latest":
# privileged (container "test" must not set securityContext.privileged=true), allowPrivilegeEscalation != false, ...
```

The error lists all the fields to change. `--dry-run=server` runs the admission controllers without creating the pod: a good way to test a manifest against a namespace.
{{% /expand%}}

## Exercise 3: baseline or restricted?

Enforce the `baseline` level, with warnings for the `restricted` level. Then create this pod. Is it accepted? Why the warnings?

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: busybox-baseline
spec:
  containers:
  - name: busybox
    image: busybox:1.36
    args: ["sleep", "1000000"]
    securityContext:
      allowPrivilegeEscalation: false
      capabilities:
        add: ["NET_BIND_SERVICE", "CHOWN"]
```

{{%expand "Solution" %}}
```bash
kubectl label --overwrite namespace $NS \
  pod-security.kubernetes.io/enforce=baseline \
  pod-security.kubernetes.io/warn=restricted \
  pod-security.kubernetes.io/audit=restricted

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: busybox-baseline
spec:
  containers:
  - name: busybox
    image: busybox:1.36
    args: ["sleep", "1000000"]
    securityContext:
      allowPrivilegeEscalation: false
      capabilities:
        add: ["NET_BIND_SERVICE", "CHOWN"]
EOF
# Warning: would violate PodSecurity "restricted:latest": unrestricted capabilities ..., runAsNonRoot != true ..., seccompProfile ...
# pod/busybox-baseline created
```

`NET_BIND_SERVICE` and `CHOWN` are in the default capabilities of the container runtimes, so `baseline` accepts them. `restricted` only accepts `NET_BIND_SERVICE`, after `drop: ["ALL"]`: the `warn` mode shows what to fix before moving the namespace to `restricted`.
{{% /expand%}}

## Exercise 4: before tightening a namespace

Before enforcing `restricted` on a namespace, check which running pods would violate it, without changing the namespace.

{{%expand "Solution" %}}
```bash
kubectl label --dry-run=server --overwrite namespace $NS pod-security.kubernetes.io/enforce=restricted
# Warning: existing pods in namespace "psa-..." violate the new PodSecurity enforce level "restricted:latest"
# Warning: busybox-baseline: unrestricted capabilities, runAsNonRoot != true, seccompProfile
```

The running pods are never evicted by a new label: only the new pods are checked. A Deployment whose pods violate the level keeps running, but cannot re-create its pods any more.
{{% /expand%}}

## Exercise 5: a restricted pod

Enforce the `restricted` level, then write a pod `busybox-restricted` which is accepted and keeps the `NET_BIND_SERVICE` capability.

{{%expand "Solution" %}}
```bash
kubectl delete pod busybox-baseline
kubectl label --overwrite namespace $NS pod-security.kubernetes.io/enforce=restricted

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: busybox-restricted
spec:
  securityContext:
    runAsUser: 65534
    runAsNonRoot: true
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: busybox
    image: busybox:1.36
    args: ["sleep", "1000000"]
    securityContext:
      allowPrivilegeEscalation: false
      capabilities:
        drop: ["ALL"]
        add: ["NET_BIND_SERVICE"]
EOF
kubectl wait --for=condition=Ready pod/busybox-restricted
kubectl exec busybox-restricted -- id
# uid=65534(nobody) gid=65534(nobody) groups=65534(nobody)
```
{{% /expand%}}

## Questions

1. Who can bypass the Pod Security Admission of a namespace?
2. How does OpenShift do the same?

{{%expand "Answers" %}}
1. Anybody allowed to change the labels of the namespace: protect the `update` and `patch` verbs on `namespaces` with RBAC. The API server can also exempt users, runtime classes or namespaces (`AdmissionConfiguration`), and set a cluster-wide default level.
2. OpenShift uses the Security Context Constraints (SCC): they validate the pods **and** mutate them (random uid of the namespace range, for example). OpenShift also syncs the Pod Security Admission labels of the namespaces from the SCCs of their service accounts. See the [SCC lab]({{% ref "/1_Labs/openshift-scc" %}}).
{{% /expand%}}

## Clean up

```bash
kubectl delete namespace $NS
kubectl config set-context --current --namespace=default
```

The solution of this lab is validated by [ex2-podsecurity.sh](https://github.com/k8s-school/k8s-advanced/blob/master/labs/3_policies/ex2-podsecurity.sh).
