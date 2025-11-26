---
title: 'Helm chart - Quick Lab'
date: 2025-11-11T14:15:26+10:00
draft: false
weight: 11
tags: ["CI", "Helm"]
---

## Objective
Create and deploy a Helm chart with nginx application using secure nginxinc image and resource configurations. Complete this lab in 10-15 minutes.

## Prerequisites
- Kubernetes cluster running (minikube, kind, or cloud cluster)
- helm v3+ installed
- kubectl configured to access the cluster

## Step 1: Create and examine the Helm chart
```bash
# Generate the base chart
helm create demo-app

# Examine structure
ls demo-app/

# Check default templates
helm template demo-app | head -20
```

## Step 2: Configure nginxinc image and resources

Edit the `demo-app/values.yaml` file to use the secure nginx image:

```bash
# Update values.yaml with nginxinc image
cat > demo-app/values.yaml << 'EOF'
replicaCount: 1

image:
  repository: nginxinc/nginx-unprivileged
  pullPolicy: IfNotPresent
  tag: "1.28.0-alpine3.21-perl"

nameOverride: ""
fullnameOverride: ""

serviceAccount:
  create: true
  automount: true
  annotations: {}
  name: ""

podAnnotations: {}
podLabels: {}

podSecurityContext: {}
securityContext: {}

service:
  type: ClusterIP
  port: 80

resources:
  limits:
    cpu: 100m
    memory: 128Mi
  requests:
    cpu: 50m
    memory: 64Mi

livenessProbe:
  httpGet:
    path: /
    port: http
readinessProbe:
  httpGet:
    path: /
    port: http

autoscaling:
  enabled: false

volumes: []
volumeMounts: []
nodeSelector: {}
tolerations: []
affinity: {}
EOF
```

## Step 3: Deploy with configured values

```bash
# Install the chart with configured nginxinc image and resources
helm install my-nginx ./demo-app

# Verify deployment
kubectl get pods,svc
kubectl describe pod -l app.kubernetes.io/name=demo-app | grep -A5 "Limits\|Requests"
```

## Step 4: Test the application

```bash
# Port forward to test
kubectl port-forward service/my-nginx 8080:80 &

# Test the nginx welcome page
curl http://localhost:8080

# Stop port forwarding
pkill -f "kubectl port-forward"
```

## Step 5: Scale and update resources using --set

```bash
# Scale to 3 replicas with higher resources
helm upgrade my-nginx ./demo-app \
  --set replicaCount=3 \
  --set resources.limits.cpu=200m \
  --set resources.limits.memory=256Mi

# Verify scaling
kubectl get pods
kubectl describe pod -l app.kubernetes.io/name=demo-app | grep -A5 "Limits\|Requests"
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
  port: 80

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
# Deploy production configuration
helm upgrade my-nginx ./demo-app -f values-prod.yaml

# Verify configuration
kubectl get pods
kubectl describe pod -l app.kubernetes.io/name=demo-app | grep -A5 "Limits\|Requests"
```

## Step 7: Validate and inspect

```bash
# Check current values
helm get values my-nginx

# List releases
helm list

# View generated manifests
helm template my-nginx ./demo-app -f values-prod.yaml | grep -A10 "kind: Deployment"

# Check resource usage
kubectl top pods || echo "Metrics server not available"
```

## Step 8: Cleanup

```bash
# Remove the release
helm uninstall my-nginx

# Verify cleanup
kubectl get all
helm list
```

## Key Takeaways

In this 10-15 minute lab, you learned:

1. **Secure Image**: Used `nginxinc/nginx-unprivileged` instead of standard nginx for better security
2. **Resource Management**: Configured CPU and memory limits/requests for efficient resource usage
3. **Helm CLI**: Used `--set` flags for quick configuration changes
4. **Values Files**: Created production-ready configurations
5. **Validation**: Inspected generated manifests and applied resources

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