---
title: 'Pod Security Admission'
date: 2026-10-27T09:00:00+01:00
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
NS=verify-pod-security-$(whoami)
kubectl create namespace $NS
kubectl config set-context --current --namespace=$NS
```

Write this privileged pod in `$HOME/tmp/ubuntu-privileged.yaml`:

```bash
mkdir -p $HOME/tmp
cat <<EOF > $HOME/tmp/ubuntu-privileged.yaml
apiVersion: v1
kind: Pod
metadata:
  name: ubuntu-privileged
  labels:
    app: ubuntu
spec:
  containers:
  - name: ubuntu
    image: ubuntu:22.04
    command: ["sleep", "infinity"]
    securityContext:
      privileged: true
EOF
```

## Exercise 1 (optional): is Pod Security Admission enabled?

Check that the `PodSecurity` admission plugin is enabled, with `kube-apiserver -h`.

{{%expand "Solution" %}}
```bash
APISERVER_POD=$(kubectl -n kube-system get pods -l component=kube-apiserver -o jsonpath='{.items[0].metadata.name}')
kubectl -n kube-system exec $APISERVER_POD -- kube-apiserver -h | grep "default enabled plugins" | grep -o PodSecurity
```

`PodSecurity` is enabled by default since Kubernetes 1.23 (GA in 1.25), it replaced the PodSecurityPolicies.
{{% /expand%}}

## Exercise 2: enforce the restricted level

Enforce the `restricted` level on your namespace, and audit on `restricted`. Then try to deploy the privileged pod.

{{%expand "Solution" %}}
```bash
kubectl label --overwrite namespace $NS \
  pod-security.kubernetes.io/enforce=restricted \
  pod-security.kubernetes.io/audit=restricted
kubectl apply -f $HOME/tmp/ubuntu-privileged.yaml || echo "EXPECTED ERROR"
# Error from server (Forbidden): error when creating ".../ubuntu-privileged.yaml": pods "ubuntu-privileged" is forbidden:
# violates PodSecurity "restricted:latest": privileged (container "ubuntu" must not set securityContext.privileged=true),
# allowPrivilegeEscalation != false (...), unrestricted capabilities (...), runAsNonRoot != true (...), seccompProfile (...)
```

The error lists all the fields to change. `kubectl apply --dry-run=server` runs the admission controllers without creating the pod: a good way to test a manifest against a namespace.
{{% /expand%}}

## Exercise 3: privileged level, with warnings

Enforce the `privileged` level, with warnings and audit on the `baseline` level. Deploy the privileged pod again.

{{%expand "Solution" %}}
```bash
kubectl label --overwrite namespace $NS \
  pod-security.kubernetes.io/enforce=privileged \
  pod-security.kubernetes.io/warn=baseline \
  pod-security.kubernetes.io/audit=baseline
kubectl apply -f $HOME/tmp/ubuntu-privileged.yaml
# Warning: would violate PodSecurity "baseline:latest": privileged (container "ubuntu" must not set securityContext.privileged=true)
# pod/ubuntu-privileged created
```

The pod is created, but `kubectl` displays a warning. The `audit` mode adds the same information as an annotation to the event of the audit log: it is only visible if the API server has an audit policy, see the [audit logs lab]({{% ref "/1_Labs/audit-logs" %}}).

`warn` and `audit` are the way to roll out a level: first see which workloads would be rejected, then enforce.
{{% /expand%}}

## Exercise 4: before tightening the namespace

The privileged pod is running. Check which running pods would violate the `restricted` level, without changing the namespace.

{{%expand "Solution" %}}
```bash
kubectl label --dry-run=server --overwrite namespace $NS pod-security.kubernetes.io/enforce=restricted
# Warning: existing pods in namespace "verify-pod-security-..." violate the new PodSecurity enforce level "restricted:latest"
# Warning: ubuntu-privileged: privileged, allowPrivilegeEscalation != false, unrestricted capabilities, runAsNonRoot != true, seccompProfile
```

The running pods are never evicted by a new label: only the new pods are checked. A Deployment whose pods violate the level keeps running, but cannot re-create its pods any more.
{{% /expand%}}

## Exercise 5: a restricted ubuntu pod

Enforce the `restricted` level, with warnings and audit on `restricted`. Then update the ubuntu pod specification so that it runs in the namespace, with the `NET_BIND_SERVICE` capability enabled. Use the [Pod Security Standards](https://kubernetes.io/docs/concepts/security/pod-security-standards/#restricted) page.

{{% notice tip %}}
The `ubuntu` image runs as root: choose a non-root uid, for example `65534` (the `nobody` user of the image).
{{% /notice %}}

{{%expand "Solution" %}}
```bash
kubectl delete pod ubuntu-privileged
kubectl label --overwrite namespace $NS \
  pod-security.kubernetes.io/enforce=restricted \
  pod-security.kubernetes.io/warn=restricted \
  pod-security.kubernetes.io/audit=restricted

cat <<EOF > $HOME/tmp/ubuntu-restricted.yaml
apiVersion: v1
kind: Pod
metadata:
  name: ubuntu-restricted
  labels:
    app: ubuntu
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 65534
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: ubuntu
    image: ubuntu:22.04
    command: ["sleep", "infinity"]
    securityContext:
      allowPrivilegeEscalation: false
      capabilities:
        drop: ["ALL"]
        add: ["NET_BIND_SERVICE"]
EOF
kubectl apply -f $HOME/tmp/ubuntu-restricted.yaml
kubectl wait --for=condition=Ready pod/ubuntu-restricted
kubectl exec ubuntu-restricted -- id
# uid=65534(nobody) gid=65534(nogroup) groups=65534(nogroup)
```

`restricted` requires: no privileged container, `allowPrivilegeEscalation: false`, a non-root user, a `RuntimeDefault` or `Localhost` seccomp profile, and `drop: ["ALL"]`. `NET_BIND_SERVICE` is the only capability it allows to add back.
{{% /expand%}}

## Exercise 6: play with the warn label

Enforce `baseline` and warn on `restricted`. Then create a copy of the restricted pod, named `ubuntu-chown`, which also adds the `CHOWN` capability. Is it created? What does the warning say? And with `enforce=restricted`?

{{%expand "Solution" %}}
```bash
kubectl label --overwrite namespace $NS \
  pod-security.kubernetes.io/enforce=baseline \
  pod-security.kubernetes.io/warn=restricted
sed -e 's/ubuntu-restricted/ubuntu-chown/' -e 's/add: \["NET_BIND_SERVICE"\]/add: ["NET_BIND_SERVICE", "CHOWN"]/' \
  $HOME/tmp/ubuntu-restricted.yaml > $HOME/tmp/ubuntu-chown.yaml
kubectl apply -f $HOME/tmp/ubuntu-chown.yaml
# Warning: would violate PodSecurity "restricted:latest": unrestricted capabilities (container "ubuntu" must not include "CHOWN" in securityContext.capabilities.add)
# pod/ubuntu-chown created

kubectl delete pod ubuntu-chown
kubectl label --overwrite namespace $NS pod-security.kubernetes.io/enforce=restricted
kubectl apply -f $HOME/tmp/ubuntu-chown.yaml || echo "EXPECTED ERROR"
# Error from server (Forbidden): ... violates PodSecurity "restricted:latest": unrestricted capabilities ...
```

`CHOWN` is in the default capabilities of the container runtimes: `baseline` accepts it, `restricted` does not. The same message is a warning with `warn`, an error with `enforce`.
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
