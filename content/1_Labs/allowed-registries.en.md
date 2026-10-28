---
title: 'Allowed registries with a ValidatingAdmissionPolicy'
date: 2026-10-28T09:00:00+01:00
draft: false
weight: 82
tags: ["kubernetes", "admission", "ValidatingAdmissionPolicy", "CEL", "supply chain", "CKS"]
---

**Author:** Fabrice JAMMES ([LinkedIn](https://www.linkedin.com/in/fabrice-jammes-5b29b042/)).

## Objective

Only accept the pods whose images come from an allowed registry, with a [ValidatingAdmissionPolicy](https://kubernetes.io/docs/reference/access-authn-authz/validating-admission-policy/): an admission rule written in [CEL](https://kubernetes.io/docs/reference/using-api/cel/), run by the API server itself, without any webhook.

The CKS curriculum lists "Allowlist registries" in the *Supply chain security* domain. A `ValidatingAdmissionPolicy` (GA since Kubernetes 1.30) has two parts:

| Object | Role |
|---|---|
| `ValidatingAdmissionPolicy` | **What** is checked: the resources and the CEL expressions |
| `ValidatingAdmissionPolicyBinding` | **Where** and **how**: the namespaces, and the action (`Deny`, `Warn`, `Audit`) |

The lab works on a cluster shared by the trainees: the policy and its binding are cluster-wide objects, so their names end with your account, and the binding only applies to your namespace.

## Prerequisites

```bash
# The shared kind cluster (on the CKS training server: kind export kubeconfig, then kubectx kind-kind)
kubectx kind-kind
NS=registries-$(whoami)
kubectl create namespace $NS
kubectl config set-context --current --namespace=$NS
```

## Exercise 1: the policy, in warning mode

Write a `ValidatingAdmissionPolicy` named `allowed-registries-$(whoami)` which checks that the images of all the containers and init containers of a pod start with `registry.k8s.io/`. Bind it to your namespace only, with the `Warn` action.

Then run a pod `nginx` with the image `nginx:1.27`. What happens?

{{% notice tip %}}
In CEL, `object` is the pod sent to the API server. `list.all(x, condition)` is true if the condition is true for each element, and `has(object.spec.initContainers)` tests if a field is set. The namespace of an object is selected with its label `kubernetes.io/metadata.name`.
{{% /notice %}}

{{%expand "Solution" %}}
```bash
cat <<EOF | kubectl apply -f -
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicy
metadata:
  name: allowed-registries-$(whoami)
spec:
  failurePolicy: Fail
  matchConstraints:
    resourceRules:
    - apiGroups: [""]
      apiVersions: ["v1"]
      operations: ["CREATE", "UPDATE"]
      resources: ["pods"]
  validations:
  - expression: object.spec.containers.all(c, c.image.startsWith("registry.k8s.io/"))
    messageExpression: '"container images must come from registry.k8s.io/, got: " + object.spec.containers.map(c, c.image).join(", ")'
  - expression: |
      !has(object.spec.initContainers) ||
      object.spec.initContainers.all(c, c.image.startsWith("registry.k8s.io/"))
    messageExpression: '"init container images must come from registry.k8s.io/, got: " + object.spec.initContainers.map(c, c.image).join(", ")'
---
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicyBinding
metadata:
  name: allowed-registries-$(whoami)
spec:
  policyName: allowed-registries-$(whoami)
  validationActions: ["Warn"]
  matchResources:
    namespaceSelector:
      matchLabels:
        kubernetes.io/metadata.name: $NS
EOF
sleep 3
kubectl run nginx --image=nginx:1.27
# Warning: Validation failed for ValidatingAdmissionPolicy 'allowed-registries-<user>' with binding 'allowed-registries-<user>':
#   container images must come from registry.k8s.io/, got: nginx:1.27
# pod/nginx created
```

The pod is created, with a warning: as with the [Pod Security Admission]({{% ref "/1_Labs/pod-security-admission" %}}) `warn` mode, `Warn` shows which workloads would be rejected before enforcing a rule.
{{% /expand%}}

## Exercise 2: deny

Change the action of the binding to `Deny`. Then try these images: `nginx:1.27`, `docker.io/library/nginx:1.27` and `registry.k8s.io/pause:3.10`.

{{% notice warning %}}
The cluster is shared: a binding without `namespaceSelector` applies to **all** the namespaces. With `Deny`, it would reject the pods of the other trainees, and the system pods (Traefik, the CNI...) as soon as they restart, since their images come from Docker Hub. Before switching to `Deny`, check that the binding only selects your namespace:

```bash
kubectl get validatingadmissionpolicybinding allowed-registries-$(whoami) -o jsonpath='{.spec.matchResources.namespaceSelector}{"\n"}'
# {"matchLabels":{"kubernetes.io/metadata.name":"registries-<user>"}}
```

The trainer finds a binding without selector, and deletes it, with:

```bash
kubectl get validatingadmissionpolicybinding -o custom-columns=NAME:.metadata.name,ACTIONS:.spec.validationActions,SELECTOR:.spec.matchResources.namespaceSelector
```
{{% /notice %}}

{{%expand "Solution" %}}
```bash
kubectl patch validatingadmissionpolicybinding allowed-registries-$(whoami) --type=merge \
  -p '{"spec":{"validationActions":["Deny"]}}'
sleep 3
kubectl run nginx2 --image=nginx:1.27 || echo "EXPECTED ERROR"
# The pods "nginx2" is invalid: : ValidatingAdmissionPolicy 'allowed-registries-<user>' with binding 'allowed-registries-<user>'
#   denied request: container images must come from registry.k8s.io/, got: nginx:1.27
kubectl run nginx3 --image=docker.io/library/nginx:1.27 || echo "EXPECTED ERROR"
kubectl run pause --image=registry.k8s.io/pause:3.10
# pod/pause created
```

`nginx:1.27` is a short name for `docker.io/library/nginx:1.27`: the policy sees the image as written in the pod, not the registry the runtime pulls from. Write the full name of the images in the policies and in the manifests.

The pod `nginx` created in exercise 1 is still running: like any admission rule, the policy only checks the new requests.
{{% /expand%}}

## Exercise 3: a Deployment

Create a Deployment `web` with the image `nginx:1.27`. Is it created? Does it run? Where is the error?

{{%expand "Solution" %}}
```bash
kubectl create deployment web --image=nginx:1.27
# deployment.apps/web created
sleep 5
kubectl get deployment web
# NAME   READY   UP-TO-DATE   AVAILABLE   AGE
# web    0/1     0            0           5s
kubectl get events --field-selector reason=FailedCreate -o custom-columns=MESSAGE:.message | tail -1
# Error creating: pods "web-..." is forbidden: ValidatingAdmissionPolicy 'allowed-registries-<user>' ... denied request: ...
```

The policy only matches the pods: the Deployment and its ReplicaSet are accepted, and the ReplicaSet controller gets the error when it creates the pods. The user does not see it with `kubectl create`. Add `deployments`, `statefulsets`, `daemonsets`... to the policy to reject them at once, with expressions on their `spec.template.spec`.
{{% /expand%}}

## Exercise 4: init containers and other namespaces

1. Create a pod whose container uses `registry.k8s.io/pause:3.10` and whose init container uses `busybox:1.36`.
2. Run `nginx:1.27` in the `default` namespace, with `--dry-run=server`.

{{%expand "Solution" %}}
```bash
cat <<EOF | kubectl apply -f - || echo "EXPECTED ERROR"
apiVersion: v1
kind: Pod
metadata:
  name: init-test
spec:
  initContainers:
  - name: init
    image: busybox:1.36
    command: ["true"]
  containers:
  - name: main
    image: registry.k8s.io/pause:3.10
EOF
# ... denied request: init container images must come from registry.k8s.io/, got: busybox:1.36

kubectl run nginx4 -n default --image=nginx:1.27 --dry-run=server
# pod/nginx4 created (server dry run)
```

The init containers run code too: a policy which only checks `containers` is bypassed by an init container. The `default` namespace is not selected by the binding: the same policy can be bound to other namespaces, with other actions, by other bindings.
{{% /expand%}}

## Questions

1. Why `registry.k8s.io/` with the trailing `/`, and not `registry.k8s.io`?
2. Who can bypass this policy?
3. What are the other ways to allow only some registries?

{{%expand "Answers" %}}
1. `startsWith("registry.k8s.io")` also accepts `registry.k8s.io.attacker.com/image`, a registry owned by anybody who buys the domain.
2. Anybody who can change or delete the policy or its binding: they are cluster-wide objects, protect them with RBAC. The label `kubernetes.io/metadata.name` is set by the API server and cannot be changed: a namespace cannot escape the binding, as it could with a label of your own. The policy also does not check the ephemeral containers added by `kubectl debug` (subresource `pods/ephemeralcontainers`).
3. - The `ImagePolicyWebhook` admission plugin: enabled on the API server (`--enable-admission-plugins`, `--admission-control-config-file`), it sends each image to an external webhook. It is the method of the older CKS exam tasks.
   - A policy engine: [Kyverno](https://kyverno.io/policies/best-practices/restrict-image-registries/restrict-image-registries/) or OPA Gatekeeper.
   - A mirror registry: the nodes only reach an internal registry, which mirrors the allowed images (containerd configuration, network rules).
   - Image signatures: only accept the images signed by your CI, see the [cosign lab]({{% ref "/1_Labs/cosign" %}}).
{{% /expand%}}

## Clean up

```bash
kubectl delete validatingadmissionpolicybinding,validatingadmissionpolicy allowed-registries-$(whoami)
kubectl delete namespace $NS
kubectl config set-context --current --namespace=default
```
