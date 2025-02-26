---
title: 'RBAC'
date: 2025-02-26T14:15:26+10:00
draft: false
weight: 20
tags: ["kubernetes", "kubectl", "api server", "curl"]
---

**Author:** Fabrice JAMMES ([LinkedIn](https://www.linkedin.com/in/fabrice-jammes-5b29b042/)).

## 1. Create Namespaces
Create two namespaces:
- `foo-<ID>`
- `bar-<ID>`

{{%expand "Answer" %}}
```sh
kubectl create namespace foo-<ID>
kubectl create namespace bar-<ID>
```
{{% /expand%}}

### 2. Deploy `kubectl-proxy` Pod

Create a `kubectl-proxy` pod inside the `foo-<ID>` namespace, using the service account `foo-<ID>:default` (the default service account of `foo-<ID>`).

Use the following example YAML file:
[Proxy Pod YAML Example](https://raw.githubusercontent.com/k8s-school/k8s-advanced/master/labs/2_authorization/kubectl-proxy.yaml)

{{%expand "Answer" %}}
```sh
# Download the file and replace service account 'default' with 'foo'
kubectl apply -f https://raw.githubusercontent.com/k8s-school/k8s-advanced/master/labs/2_authorization/kubectl-proxy.yaml -n foo-<ID>
```
{{% /expand%}}

### 3. Create Services in Both Namespaces
Create a service inside both namespaces (`foo-<ID>` and `bar-<ID>`).

{{%expand "Answer" %}}
```sh
kubectl create service clusterip foo-service --tcp=80:80 -n foo-<ID>
kubectl create service clusterip bar-service --tcp=80:80 -n bar-<ID>
```
{{% /expand%}}

### 4. Test Access via `kubectl-proxy`

Run `curl` inside the `kubectl-proxy` container to query the API server for services in `foo-<ID>` and `bar-<ID>`.

{{%expand "Answer" %}}
```sh

curl http://localhost:8001/api/v1/namespaces/foo-<ID>/services
curl http://localhost:8001/api/v1/namespaces/bar-<ID>/services
```
{{% /expand%}}

### 5. Create Role and RoleBinding

Inside `foo-<ID>`, create:
- A **Role** named `service-reader` that grants read access to services.
- A **RoleBinding** to bind `foo-<ID>:default` service account to the `service-reader` role.

{{%expand "Answer" %}}
#### Role Definition (`service-reader.yaml`):
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: service-reader
  namespace: foo-<ID>
rules:
- apiGroups: [""]
  resources: ["services"]
  verbs: ["get", "list"]
```

#### RoleBinding Definition (`rolebinding.yaml`):
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: service-reader-binding
  namespace: foo-<ID>
subjects:
- kind: ServiceAccount
  name: default
  namespace: foo-<ID>
roleRef:
  kind: Role
  name: service-reader
  apiGroup: rbac.authorization.k8s.io
```

Apply the Role and RoleBinding:

```sh
kubectl apply -f service-reader.yaml
kubectl apply -f rolebinding.yaml
```
{{% /expand%}}

### 6. Test Role Access via  `curl-custom-sa` pod

{{%expand "Answer" %}}
Run `curl` inside the `curl-custom-sa` pod to check access:

```sh
kubectl exec -it curl-custom-sa -c main bash
curl http://localhost:8001/api/v1/namespaces/foo-<ID>/services  # Should work
curl http://localhost:8001/api/v1/namespaces/bar-<ID>/services  # Should be forbidden
```
{{% /expand%}}

### Expected Outcome:
- `curl` to `foo-<ID>` should succeed.
- `curl` to `bar-<ID>` should be **forbidden**, since the role only grants access to services in `foo-<ID>`.
