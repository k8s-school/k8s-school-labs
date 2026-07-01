---
title: 'Helm chart - Quick Lab'
date: 2025-11-11T14:15:26+10:00
draft: false
weight: 150
tags: ["CI", "Helm"]
---

## Objective
Create and deploy a Helm chart with nginx application using secure nginxinc image and resource configurations. Complete this lab in 10-15 minutes.

## Prerequisites
- Kubernetes cluster running (minikube, kind, or cloud cluster)
- helm v3+ installed
- kubectl configured to access the cluster

## Setup: Create your namespace

On a shared cluster, work in your own namespace to avoid colliding with other
users. We name it after your numeric user id:

```bash
# A namespace unique to your user, e.g. 1000-helm
export NS="$(id -u)-helm"

# Create it if it does not exist yet (idempotent)
kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f -
```

> Keep this `NS` variable exported for the rest of the lab: every `helm` and
> `kubectl` command below targets it with `-n "$NS"`.

## Setup: Install metrics-server

Later steps (e.g. `kubectl top`) rely on the Kubernetes Metrics Server. Install it
only if it is not already present on the cluster:

```bash
# Check whether metrics-server is already installed
if kubectl get deployment metrics-server -n kube-system &>/dev/null; then
  echo "metrics-server is already installed, skipping"
else
  helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
  helm repo update
  helm upgrade --install metrics-server metrics-server/metrics-server \
    -n kube-system \
    --set "args={--kubelet-insecure-tls}"
  kubectl rollout status deployment/metrics-server -n kube-system --timeout=120s
fi
```

> Note: `--kubelet-insecure-tls` is required on local clusters (kind, minikube)
> whose kubelet serving certificates are self-signed.

## Step 1: Create and examine the Helm chart
```bash
# Generate the base chart
helm create demo-app

# Examine structure
ls demo-app/

# Check default templates
helm template demo-app | head -20
```

To understand the role of Helm, open one of the generated templates, for example
`demo-app/templates/service.yaml`:

```bash
cat demo-app/templates/service.yaml
```

Notice the `{{ ... }}` placeholders: a Helm template is **not** plain Kubernetes
YAML. Helm renders these templates by injecting the values defined in
`values.yaml` (and any `-f` override file or `--set` flag), then sends the
resulting manifests to the cluster. This separation between *templates* (the
structure) and *values* (the configuration) is the core idea behind Helm.

## Step 2: Configure the unprivileged nginxinc image

We will deploy the `nginxinc/nginx-unprivileged` image instead of the standard
`nginx` image. The official `nginx` image runs as **root** and binds to port 80,
which is rejected by a hardened cluster (restricted Pod Security Standards,
read-only root, non-root user). The `nginxinc/nginx-unprivileged` variant runs
as a **non-root** user and listens on port 8080, so it works without elevated
privileges — a security best practice.

Rather than overwriting the chart's default `demo-app/values.yaml`, we create a
small override file `demo-app/values-nginxinc.yaml`. An override file only lists
the values we actually change and inherits everything else from the chart
defaults. Keeping it minimal makes the demo much easier to maintain across Helm
chart version bumps (you diff only your own overrides, not a full copy of
`values.yaml`):

```bash
# Create a minimal override file with the unprivileged nginxinc image
cat > demo-app/values-nginxinc.yaml << 'EOF'
# Only the values we override; everything else comes from the chart defaults.
replicaCount: 1

image:
  repository: nginxinc/nginx-unprivileged
  pullPolicy: IfNotPresent
  tag: "1.28.0-alpine3.21-perl"

service:
  type: ClusterIP
  port: 8080

livenessProbe:
  httpGet:
    path: /
    port: 8080
readinessProbe:
  httpGet:
    path: /
    port: 8080
EOF
```

## Step 3: Deploy with configured values

```bash
# Install the chart with configured nginxinc image and resources
helm install my-nginx ./demo-app -f demo-app/values-nginxinc.yaml -n "$NS"

# List your Helm releases in the namespace
helm list -n "$NS"

# Verify deployment
kubectl get pods,svc -n "$NS"
kubectl describe pod -l app.kubernetes.io/name=demo-app -n "$NS" | grep -A5 "Limits\|Requests"
```

## Step 4: Test the application

```bash
# Port forward to test
kubectl port-forward service/my-nginx-demo-app 8080:8080 -n "$NS" &

# Test the nginx welcome page
curl http://localhost:8080

# Stop port forwarding
pkill -f "kubectl port-forward"
```

## Step 5: Scale and update resources using --set

```bash
# Scale to 3 replicas with higher resources
helm upgrade my-nginx ./demo-app -f demo-app/values-nginxinc.yaml -n "$NS" \
  --set replicaCount=3 \
  --set resources.limits.cpu=200m \
  --set resources.limits.memory=256Mi

# Verify scaling
kubectl get pods -n "$NS"
kubectl describe pod -l app.kubernetes.io/name=demo-app -n "$NS" | grep -A5 "Limits\|Requests"
```

## Step 6: Create values file for production

Create `values-prod.yaml`:
```bash
cat > values-prod.yaml << 'EOF'
replicaCount: 2

image:
  repository: nginxinc/nginx-unprivileged
  tag: "1.28.0-alpine3.21-perl"

service:
  type: NodePort

resources:
  limits:
    cpu: 150m
    memory: 200Mi
  requests:
    cpu: 75m
    memory: 100Mi
EOF
```

```bash
# Deploy production configuration (layer prod values on top of the nginxinc base)
helm upgrade my-nginx ./demo-app -f demo-app/values-nginxinc.yaml -f values-prod.yaml -n "$NS"

# Verify configuration
kubectl get pods -n "$NS"
kubectl describe pod -l app.kubernetes.io/name=demo-app -n "$NS" | grep -A5 "Limits\|Requests"
```

## Step 7: Validate and inspect

```bash
# Check current values
helm get values my-nginx -n "$NS"

# List releases
helm list -n "$NS"

# View generated manifests
helm template my-nginx ./demo-app -f demo-app/values-nginxinc.yaml -f values-prod.yaml | grep -A10 "kind: Deployment"

# Check resource usage
kubectl top pods -n "$NS" || echo "Metrics server not available"
```

## Step 8: Cleanup

```bash
# Remove the release
helm uninstall my-nginx -n "$NS"

# Verify cleanup
kubectl get all -n "$NS"
helm list -n "$NS"

# Remove your namespace
kubectl delete namespace "$NS"
```

## Key Takeaways

In this 10-15 minute lab, you learned:

1. **Templates vs Values**: Inspected `templates/service.yaml` to see how Helm renders templates using values
2. **Secure Image**: Used the non-root `nginxinc/nginx-unprivileged` instead of standard nginx for better security
3. **Resource Management**: Configured CPU and memory limits/requests for efficient resource usage
4. **Override Files**: Kept the chart defaults untouched and layered `values-nginxinc.yaml` / `values-prod.yaml` for maintainable, upgrade-friendly configuration
5. **Helm CLI**: Used `--set` flags for quick configuration changes
6. **Validation**: Inspected generated manifests and applied resources

## Essential Commands Reference

```bash
# Quick deployment
helm install <release> <chart> --set key=value
helm upgrade <release> <chart> -f values.yaml

# Inspection
helm get values <release>
helm template <release> <chart>

# Management
helm list
helm uninstall <release>
```

This streamlined lab demonstrates practical Helm usage with security best practices and resource management in a time-efficient manner.