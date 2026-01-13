---
title: 'Kubernetes Service Account Token Lab'
date: 2025-11-18T14:15:26+10:00
draft: false
weight: 60
tags: ["kubernetes", "service account", "JWT token"]
---

**Auteur:** Fabrice JAMMES ([LinkedIn](https://www.linkedin.com/in/fabrice-jammes-5b29b042/)).
**Date:** Nov 18, 2025 · 10 min read

A simple lab to explore Service Accounts and their tokens in Kubernetes.

## Prerequisites

- A Kubernetes cluster (kind, minikube, or any cluster)
- kubectl configured
- jq installed (for JSON parsing)

## Lab Overview

1. Understanding default Service Accounts
2. Creating custom Service Accounts
3. Exploring Service Account tokens (JWT)
4. Using tokens to authenticate
5. Token mounting behavior

---

## Part 1: Default Service Account

Every namespace automatically gets a `default` service account.

```bash
# Create a lab namespace
NS=<ID>-$NS
kubectl create namespace $NS

# View the default service account
kubectl get serviceaccount -n $NS
kubectl describe serviceaccount default -n $NS

# Check what secrets are associated (may vary by Kubernetes version)
kubectl get serviceaccount default -n $NS -o yaml
```

---

## Part 2: Create a Pod with Default Service Account

```bash
# Create a simple pod
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: default-sa-pod
  namespace: $NS
spec:
  containers:
  - name: nginx
    image: nginx:alpine
    command: ["sleep", "3600"]
EOF

# Wait for the pod to be ready
kubectl wait --for=condition=ready pod/default-sa-pod -n $NS --timeout=60s

# Check which service account the pod uses
kubectl get pod default-sa-pod -n $NS -o jsonpath='{.spec.serviceAccountName}'
echo

# View the mounted service account files
kubectl exec -it default-sa-pod -n $NS -- ls -la /var/run/secrets/kubernetes.io/serviceaccount/
```

**What you'll find:**
- `token` - JWT token for authentication
- `ca.crt` - Certificate authority for the cluster
- `namespace` - The namespace the pod is running in

---

## Part 3: Explore the Token

```bash
# Read the token
kubectl exec default-sa-pod -n $NS -- cat /var/run/secrets/kubernetes.io/serviceaccount/token

# Save the token to a variable
TOKEN=$(kubectl exec default-sa-pod -n $NS -- cat /var/run/secrets/kubernetes.io/serviceaccount/token)

# View the token
echo $TOKEN

# Decode the JWT payload (it's base64 encoded)
# JWT format: header.payload.signature
echo $TOKEN | cut -d'.' -f2 | base64 -d 2>/dev/null | jq .

# Read the namespace file
kubectl exec default-sa-pod -n $NS -- cat /var/run/secrets/kubernetes.io/serviceaccount/namespace
```

---

## Part 4: Create Custom Service Accounts

```bash
# Create two custom service accounts
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: app-sa
  namespace: $NS
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: monitor-sa
  namespace: $NS
EOF

# List all service accounts
kubectl get serviceaccount -n $NS

# Describe a custom service account
kubectl describe serviceaccount app-sa -n $NS
```

---

## Part 5: Use Custom Service Account in a Pod

```bash
# Create a pod with the custom service account
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: app-pod
  namespace: $NS
spec:
  serviceAccountName: app-sa
  containers:
  - name: app
    image: nginx:alpine
    command: ["sleep", "3600"]
EOF

# Wait and verify
kubectl wait --for=condition=ready pod/app-pod -n $NS --timeout=60s
kubectl get pod app-pod -n $NS -o jsonpath='{.spec.serviceAccountName}'
echo

# Compare tokens between pods
echo "=== Default SA Token (first 50 chars) ==="
kubectl exec default-sa-pod -n $NS -- cat /var/run/secrets/kubernetes.io/serviceaccount/token | cut -c1-50

echo ""
echo "=== App SA Token (first 50 chars) ==="
kubectl exec app-pod -n $NS -- cat /var/run/secrets/kubernetes.io/serviceaccount/token | cut -c1-50
```

**Notice:** Different service accounts have different tokens!

---

## Part 6: Use Token from Outside the Pod

You can extract and use the token directly with kubectl.

```bash
# Get the token
APP_TOKEN=$(kubectl exec app-pod -n $NS -- cat /var/run/secrets/kubernetes.io/serviceaccount/token)

# Get the API server URL (adjust if needed)
APISERVER=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')

# Try to list pods using the token
kubectl --token="$APP_TOKEN" --server="$APISERVER" --insecure-skip-tls-verify get pods -n $NS

# This might fail with "Forbidden" because the service account has no permissions by default
```

---

## Part 7: Inspect Token Details

Inspect JWT toker

{{%expand "Answer" %}}


```bash
# Get full token details
APP_TOKEN=$(kubectl exec app-pod -n $NS -- cat /var/run/secrets/kubernetes.io/serviceaccount/token)

# Decode header
echo "=== JWT Header ==="
echo $APP_TOKEN | cut -d'.' -f1 | base64 -d 2>/dev/null | jq .

# Decode payload
echo "=== JWT Payload ==="
echo $APP_TOKEN | cut -d'.' -f2 | base64 -d 2>/dev/null | jq .

# Key fields in the payload:
# - iss: issuer (kubernetes/serviceaccount)
# - kubernetes.io/serviceaccount/namespace: namespace
# - kubernetes.io/serviceaccount/service-account.name: SA name
# - sub: subject identifier
# - exp: expiration time
```

{{% /expand%}}

---

## Part 8: Multiple Containers, Same Token

All containers in a pod share the same service account token.

```bash
# Create a pod with multiple containers
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: multi-container-pod
  namespace: $NS
spec:
  serviceAccountName: monitor-sa
  containers:
  - name: container1
    image: nginx:alpine
    command: ["sleep", "3600"]
  - name: container2
    image: busybox:latest
    command: ["sleep", "3600"]
EOF

# Wait for ready
kubectl wait --for=condition=ready pod/multi-container-pod -n $NS --timeout=60s
```

Check tokens in both containers

{{%expand "Answer" %}}

```bash
echo "=== Token from container1 (first 50 chars) ==="
kubectl exec multi-container-pod -n $NS -c container1 -- cat /var/run/secrets/kubernetes.io/serviceaccount/token | cut -c1-50

echo ""
echo "=== Token from container2 (first 50 chars) ==="
kubectl exec multi-container-pod -n $NS -c container2 -- cat /var/run/secrets/kubernetes.io/serviceaccount/token | cut -c1-50
```

{{% /expand%}}

**They're identical!**

---

## Cleanup

```bash
kubectl delete namespace $NS
```

---

## Key Takeaways

1. **Every pod uses a service account** - default if not specified
2. **Tokens are JWT** - they contain namespace, SA name, and other metadata
3. **Tokens are auto-mounted** at `/var/run/secrets/kubernetes.io/serviceaccount/`
4. **Three files are mounted**: `token`, `ca.crt`, `namespace`
5. **Each service account has a unique token**
6. **All containers in a pod share the same token**
7. **Tokens authenticate, RBAC authorizes** (permissions need separate Role/RoleBinding)

---

## Exercises

1. Create a service account named `my-app-sa` and use it in a pod
2. Extract the token and decode its payload to see all claims
3. Create two pods with different service accounts and compare their tokens

---

## Next Steps

To give service accounts actual permissions, you need to learn about:
- **Role** and **RoleBinding** (namespace-scoped permissions)
- **ClusterRole** and **ClusterRoleBinding** (cluster-wide permissions)
- **RBAC** (Role-Based Access Control)
