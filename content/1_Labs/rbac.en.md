---
title: 'RBAC'
date: 2025-02-26T14:15:26+10:00
draft: false
weight: 65
tags: ["kubernetes", "kubectl", "api server", "curl", "CKS"]
---

**Author:** Fabrice JAMMES ([LinkedIn](https://www.linkedin.com/in/fabrice-jammes-5b29b042/)).

## Objective

Give a pod the right to read the Services of its namespace, and nothing else, with a `Role` and a `RoleBinding`, then check the rights with `kubectl auth can-i`.

The lab works on a cluster shared by the trainees: the namespaces end with your account.

## Setup

```bash
# The shared kind cluster (on the CKS training server: kind export kubeconfig, then kubectx kind-kind)
kubectx kind-kind
ID=$(whoami)
mkdir -p $HOME/rbac && cd $HOME/rbac
```

## Exercise 1: namespaces and Services

Create two namespaces, `foo-$ID` and `bar-$ID`, and a ClusterIP Service in each one: `foo-service` and `bar-service`, on port `80`.

{{%expand "Solution" %}}
```bash
kubectl create namespace foo-$ID
kubectl create namespace bar-$ID
kubectl create service clusterip foo-service --tcp=80:80 -n foo-$ID
kubectl create service clusterip bar-service --tcp=80:80 -n bar-$ID
```
{{% /expand%}}

## Exercise 2: a pod which calls the API server

Create the pod `curl-custom-sa` of [kubectl-proxy.yaml](https://raw.githubusercontent.com/k8s-school/k8s-advanced/master/labs/2_authorization/kubectl-proxy.yaml) in `foo-$ID`. Which service account does it use? Its `ambassador` container runs `kubectl proxy` with the token of this service account, on `localhost:8001`.

From its `main` container, list the Services of `foo-$ID` with `curl`. What happens?

{{%expand "Solution" %}}
```bash
curl -s -o kubectl-proxy.yaml https://raw.githubusercontent.com/k8s-school/k8s-advanced/master/labs/2_authorization/kubectl-proxy.yaml
grep serviceAccountName kubectl-proxy.yaml
#   serviceAccountName: default
kubectl apply -f kubectl-proxy.yaml -n foo-$ID
kubectl wait --for=condition=Ready pod/curl-custom-sa -n foo-$ID --timeout=120s

kubectl exec -n foo-$ID curl-custom-sa -c main -- curl -s http://localhost:8001/api/v1/namespaces/foo-$ID/services
# "message": "services is forbidden: User \"system:serviceaccount:foo-<user>:default\" cannot list resource \"services\"
#   in API group \"\" in the namespace \"foo-<user>\"",
# "code": 403
```

The pod uses the `default` service account of its namespace, which has no right on the API: the API server authenticates the request (the user is `system:serviceaccount:foo-<user>:default`), then RBAC denies it.

`kubectl exec ... -- curl ...` runs the command in the container: no need to open a shell in the pod.
{{% /expand%}}

## Exercise 3: Role and RoleBinding

In `foo-$ID`, create:

- a `Role` `service-reader`, which allows `get` and `list` on `services`
- a `RoleBinding` `service-reader-binding`, which grants this Role to the service account `default` of `foo-$ID`

Then check the rights of the service account with `kubectl auth can-i`, without calling the API from the pod.

{{%expand "Solution" %}}
In the exam, the imperative commands are the fastest:

```bash
kubectl create role service-reader --verb=get,list --resource=services -n foo-$ID
kubectl create rolebinding service-reader-binding --role=service-reader \
  --serviceaccount=foo-$ID:default -n foo-$ID
kubectl get role service-reader -n foo-$ID -o yaml
```

The same objects in YAML:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: service-reader
  namespace: foo-<user>
rules:
- apiGroups: [""]
  resources: ["services"]
  verbs: ["get", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: service-reader-binding
  namespace: foo-<user>
subjects:
- kind: ServiceAccount
  name: default
  namespace: foo-<user>
roleRef:
  kind: Role
  name: service-reader
  apiGroup: rbac.authorization.k8s.io
```

```bash
SA=system:serviceaccount:foo-$ID:default
kubectl auth can-i list services -n foo-$ID --as=$SA
# yes
kubectl auth can-i list services -n bar-$ID --as=$SA || echo "EXPECTED: no"
# no
kubectl auth can-i delete services -n foo-$ID --as=$SA || echo "EXPECTED: no"
# no
kubectl auth can-i --list -n foo-$ID --as=$SA
```

`--as` impersonates a user: the API server answers with the rights of this user. It is the fastest way to check RBAC, in the exam and in production.
{{% /expand%}}

## Exercise 4: test from the pod

From the pod, list the Services of `foo-$ID`, then of `bar-$ID`.

{{%expand "Solution" %}}
```bash
kubectl exec -n foo-$ID curl-custom-sa -c main -- curl -s http://localhost:8001/api/v1/namespaces/foo-$ID/services \
  | grep '"name": "foo-service"'
#         "name": "foo-service",
kubectl exec -n foo-$ID curl-custom-sa -c main -- curl -s http://localhost:8001/api/v1/namespaces/bar-$ID/services \
  | grep '"code"'
#   "code": 403
```

A `Role` and its `RoleBinding` only give rights in their namespace. To read the Services of `bar-$ID`, create a RoleBinding in `bar-$ID` too: it can reference a `ClusterRole`, which defines the rules once for all the namespaces.
{{% /expand%}}

## Questions

1. Which service account does a pod use if `serviceAccountName` is not set? Does it need a token if it does not call the API?
2. How do you find all the subjects which can read the Secrets of a namespace?

{{%expand "Answers" %}}
1. The `default` service account of its namespace. A pod which does not call the API should not get a token: set `automountServiceAccountToken: false` in the pod, or in the service account. See the [Service Account Token lab]({{% ref "/1_Labs/service-account" %}}).
2. `kubectl auth can-i` answers for one subject. To search, list the bindings: `kubectl get rolebindings,clusterrolebindings -A -o wide`, or use a tool like `rbac-tool who-can get secrets`, see the [RBAC monitoring lab]({{% ref "/1_Labs/rbac-secissue" %}}).
{{% /expand%}}

## Clean up

```bash
kubectl delete namespace foo-$ID bar-$ID
cd $HOME && rm -rf $HOME/rbac
```

The [2_0_RBAC_simple.sh](https://github.com/k8s-school/k8s-advanced/blob/master/labs/2_authorization/2_0_RBAC_simple.sh) script of the k8s-advanced repository runs the same scenario.
