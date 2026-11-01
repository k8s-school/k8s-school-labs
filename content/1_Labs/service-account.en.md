---
title: 'Kubernetes Service Account Token Lab'
date: 2025-11-18T14:15:26+10:00
draft: false
weight: 60
tags: ["kubernetes", "service account", "JWT token"]
---

**Author:** Fabrice JAMMES ([LinkedIn](https://www.linkedin.com/in/fabrice-jammes-5b29b042/)).

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
# The shared kind cluster (on the CKS training server: kind export kubeconfig, then kubectx kind-kind)
kubectx kind-kind
NS=sa-$(whoami)
kubectl create namespace $NS

# View the default service account
kubectl get serviceaccount -n $NS
kubectl describe serviceaccount default -n $NS

# No Secret is associated: since Kubernetes 1.24, the tokens are not stored in Secrets any more
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
kubectl exec default-sa-pod -n $NS -- ls -la /var/run/secrets/kubernetes.io/serviceaccount/
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
# JWT format: header.payload.signature, each part in base64url without padding
echo $TOKEN | jq -R 'split(".")[1] | gsub("-";"+") | gsub("_";"/") | @base64d | fromjson'

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
```

Compare the identity carried by the token of each pod: the `sub` claim of the payload. The first characters of the tokens do not tell them apart: they encode the header of the JWT (algorithm and key id), the same for all the tokens of the cluster.

```bash
# The sub claim of a pod's token
sub() {
  kubectl exec $1 -n $NS -- cat /var/run/secrets/kubernetes.io/serviceaccount/token \
    | jq -rR 'split(".")[1] | gsub("-";"+") | gsub("_";"/") | @base64d | fromjson | .sub'
}
sub default-sa-pod
# system:serviceaccount:sa-<user>:default
sub app-pod
# system:serviceaccount:sa-<user>:app-sa
```

**Notice:** each pod gets a token of its own, which carries its service account.

---

## Part 6: Use Token from Outside the Pod

Call the API server with the token of `app-pod`, from your terminal.

{{% notice warning %}}
`kubectl --token` alone is not enough: kubectl still sends the client certificate of your kubeconfig, and the API server authenticates you as the administrator. `--kubeconfig=/dev/null` leaves out all the credentials of your kubeconfig.
{{% /notice %}}

```bash
# Get the token, and the CA certificate which signed the certificate of the API server
APP_TOKEN=$(kubectl exec app-pod -n $NS -- cat /var/run/secrets/kubernetes.io/serviceaccount/token)
kubectl exec app-pod -n $NS -- cat /var/run/secrets/kubernetes.io/serviceaccount/ca.crt > /tmp/ca-$NS.crt

# Get the API server URL
APISERVER=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')

# Only the token: which identity does the API server see?
kubectl --kubeconfig=/dev/null --server="$APISERVER" --certificate-authority=/tmp/ca-$NS.crt \
  --token="$APP_TOKEN" auth whoami
# Username   system:serviceaccount:sa-<user>:app-sa

# Try to list pods using the token
kubectl --kubeconfig=/dev/null --server="$APISERVER" --certificate-authority=/tmp/ca-$NS.crt \
  --token="$APP_TOKEN" get pods -n $NS || echo "EXPECTED ERROR"
# Error from server (Forbidden): pods is forbidden: User "system:serviceaccount:sa-<user>:app-sa" cannot list resource "pods" ...
rm /tmp/ca-$NS.crt
```

The token authenticates the request, but the service account has no permission by default: RBAC denies it.

---

## Part 7: Inspect Token Details

Inspect JWT token

{{%expand "Answer" %}}


```bash
# Get full token details
APP_TOKEN=$(kubectl exec app-pod -n $NS -- cat /var/run/secrets/kubernetes.io/serviceaccount/token)

# Decode header
echo "=== JWT Header ==="
echo $APP_TOKEN | jq -R 'split(".")[0] | gsub("-";"+") | gsub("_";"/") | @base64d | fromjson'

# Decode payload
echo "=== JWT Payload ==="
echo $APP_TOKEN | jq -R 'split(".")[1] | gsub("-";"+") | gsub("_";"/") | @base64d | fromjson'

# Key fields in the payload:
# - iss: issuer, the API server (https://kubernetes.default.svc.cluster.local on kind)
# - aud: audience, the API server
# - sub: system:serviceaccount:<namespace>:<service account>
# - kubernetes.io: namespace, service account, pod and node: the token is bound to the pod
# - iat, exp: issue and expiration times
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
    image: busybox:1.37
    command: ["sleep", "3600"]
EOF

# Wait for ready
kubectl wait --for=condition=ready pod/multi-container-pod -n $NS --timeout=60s
```

Check tokens in both containers

{{%expand "Answer" %}}

```bash
SA_DIR=/var/run/secrets/kubernetes.io/serviceaccount
T1=$(kubectl exec multi-container-pod -n $NS -c container1 -- cat $SA_DIR/token)
T2=$(kubectl exec multi-container-pod -n $NS -c container2 -- cat $SA_DIR/token)
[ "$T1" = "$T2" ] && echo "Same token in both containers"
# Same token in both containers
```

{{% /expand%}}

**They're identical!** The token is a volume of the pod, mounted in each container.

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
5. **Each pod gets its own token**, bound to the pod and to its service account
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
