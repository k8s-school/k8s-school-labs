---
title: 'RBAC'
date: 2024-06-06T14:15:26+10:00
draft: false
weight: 20
tags: ["Kubernetes", "RBAC", "Authorization", "CKA"]
---

## Steps

1. Create 2 namespaces, `foo-<ID>` and `bar-<ID>`

{{%expand "Solution" %}}
```bash
kubectl create namespace foo-<ID>
kubectl create namespace bar-<ID>
```
{{% /expand%}}

2. Create a `kubectl-proxy` pod inside `foo-<ID>`, which uses the service account `foo-<ID>:default` (the “default” service account of the namespace `foo-<ID>`)
    - YAML example: [kubectl-proxy.yaml](https://raw.githubusercontent.com/k8s-school/k8s-advanced/master/labs/2_authorization/kubectl-proxy.yaml)
3. Create a service inside namespaces `foo-<ID>` and `bar-<ID>`
    - Use `kubectl create service --help` for guidance
4. Run `curl` inside the container `kubectl-proxy/main` against the API server service URL for namespaces `foo-<ID>` and `bar-<ID>`
    - Example: `http://localhost:8001/api/v1/namespaces/default/services`
5. Inside namespace `foo-<ID>`, create a role `service-reader`, and a rolebinding for serviceaccount `foo-<ID>:default`
6. Run `curl` inside the container `kubectl-proxy/main` against the API server service URL for namespaces `foo-<ID>` and `bar-<ID>`

## Reference
For more details, check the [k8s-school authorization lab](https://github.com/k8s-school/k8s-advanced/tree/master/labs/2_authorization).
