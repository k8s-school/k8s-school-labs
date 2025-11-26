---
title: 'Helm chart'
date: 2025-11-11T14:15:26+10:00
draft: false
weight: 11
tags: ["CI", "Helm"]
---

## Objective
Create and deploy a Helm chart with a nginx application, including deployment, service, and optional resource configurations. Learn how to customize values using `--set` and values files.

## Prerequisites
- Kubernetes cluster running (minikube, kind, or cloud cluster)
- helm v3+ installed
- kubectl configured to access the cluster

## Part 1: Create the Helm Chart

### Step 1: Generate the base chart
```bash
helm create demo-app
```

This command creates a basic Helm chart structure with:
- `Chart.yaml`: Chart metadata
- `values.yaml`: Default configuration values
- `templates/`: Kubernetes manifests templates

### Step 2: Examine the chart structure
```bash
ls -Rtl demo-app/
```

Expected output:
```
demo-app/
├── Chart.yaml
├── charts/
├── templates/
│   ├── NOTES.txt
│   ├── _helpers.tpl
│   ├── deployment.yaml
│   ├── hpa.yaml
│   ├── ingress.yaml
│   ├── service.yaml
│   ├── serviceaccount.yaml
│   └── tests/
│       └── test-connection.yaml
└── values.yaml
```

### Step 2: Examine the generated yaml

```bash
helm template demo-app
```

## Part 2: Configure the Application

### Step 3: Update the nginx image

Configure the chart to use the image: `nginxinc/nginx-unprivileged:1.28.0-alpine3.21-perl`
This is a security-enhanced nginx image that runs as non-root

### Step 4: Configure optional resources
The chart includes optional resource limits that can be enabled through values.

## Part 3: Deploy the Application

### Step 5: Install the chart with default values
```bash
# Deploy with default configuration
helm install my-demo-app ./demo-app

# Verify deployment
kubectl get pods,svc
```

### Step 6: Check the application

```bash
# Port forward to access the application
kubectl port-forward service/my-demo-app 8080:80

# In another terminal, test the application
curl http://localhost:8080
```

You should see the default nginx welcome page.

## Part 4: Customization with --set

### Step 7: Override values using --set
```bash
# Change replica count
helm upgrade my-demo-app ./demo-app --set replicaCount=3

# Enable resource limits
helm upgrade my-demo-app ./demo-app \
  --set 'resources.limits.cpu=100m' \
  --set 'resources.limits.memory=128Mi' \
  --set 'resources.requests.cpu=50m' \
  --set 'resources.requests.memory=64Mi'

# Change image tag
helm upgrade my-demo-app ./demo-app --set image.tag=1.27.0-alpine3.21-perl

# Multiple values at once
helm upgrade my-demo-app ./demo-app \
  --set replicaCount=2 \
  --set image.tag=1.28.0-alpine3.21-perl \
  --set service.type=NodePort
```

### Step 8: View current values
```bash
# Show all computed values
helm get values my-demo-app

# Show all values including defaults
helm get values my-demo-app --all
```

## Part 5: Customization with Values Files

### Step 9: Create custom values files

Create `values-dev.yaml`:
```yaml
replicaCount: 2

image:
  tag: "1.28.0-alpine3.21-perl"

service:
  type: NodePort
  port: 8080

# Optional: Enable basic resource limits for development
resources:
  limits:
    cpu: 200m
    memory: 256Mi
  requests:
    cpu: 100m
    memory: 128Mi
```

Create `values-prod.yaml`:
```yaml
replicaCount: 5

image:
  tag: "1.28.0-alpine3.21-perl"

service:
  type: ClusterIP
  port: 80

# Production resource limits
resources:
  limits:
    cpu: 100m
    memory: 128Mi
  requests:
    cpu: 50m
    memory: 64Mi

# Enable horizontal pod autoscaler
autoscaling:
  enabled: true
  minReplicas: 3
  maxReplicas: 10
  targetCPUUtilizationPercentage: 80
```

### Step 10: Deploy using custom values files
```bash
# Deploy development environment
helm upgrade my-demo-app ./demo-app -f values-dev.yaml

# Deploy production environment (new release)
helm install my-demo-app-prod ./demo-app -f values-prod.yaml

# Combine values file with --set (--set takes precedence)
helm upgrade my-demo-app ./demo-app -f values-dev.yaml --set replicaCount=4
```

## Part 6: Validation and Testing

### Step 11: Validate deployments
```bash
# List all releases
helm list

# Check deployment status
kubectl get deployments
kubectl get pods

# Describe the deployment to see applied configuration
kubectl describe deployment my-demo-app

# Check resource limits applied
kubectl describe pod -l app.kubernetes.io/name=demo-app
```

### Step 12: Test different configurations
```bash
# Test dev environment
kubectl port-forward service/my-demo-app 8080:8080
curl http://localhost:8080

# Test prod environment
kubectl port-forward service/my-demo-app-prod 8081:80
curl http://localhost:8081
```

## Part 7: Understanding Conditional Templates

### Step 13: Examine conditional resource rendering
```bash
# Check the default deployment template
helm template my-demo-app ./demo-app

# Notice that resources are only rendered if defined in values
helm template my-demo-app ./demo-app --set 'resources.limits.cpu=100m'
```

The Helm templates use conditional statements like:
```yaml
{{- if .Values.resources }}
resources:
  {{- toYaml .Values.resources | nindent 12 }}
{{- end }}
```

This means:
- Resources are only added to the manifest if `.Values.resources` is defined
- Autoscaling (HPA) is only created if `.Values.autoscaling.enabled` is true
- Service account is optional based on `.Values.serviceAccount.create`

## Part 8: Advanced Operations

### Step 14: Helm template and dry-run
```bash
# Generate manifests without installing
helm template my-demo-app ./demo-app -f values-dev.yaml

# Perform dry-run to validate
helm install my-demo-app-test ./demo-app --dry-run --debug -f values-prod.yaml
```

### Step 15: History and rollback
```bash
# View release history
helm history my-demo-app

# Rollback to previous version
helm rollback my-demo-app 1

# Rollback to specific revision
helm rollback my-demo-app 2
```

### Step 16: Cleanup
```bash
# Uninstall releases
helm uninstall my-demo-app
helm uninstall my-demo-app-prod

# Verify cleanup
kubectl get all
helm list --all
```

## Summary

In this TP, you learned:

1. **Chart Creation**: How to create a basic Helm chart structure
2. **Configuration**: Customizing charts with values.yaml and optional resources
3. **Deployment**: Installing charts with default and custom values
4. **CLI Customization**: Using `--set` flags for quick overrides
5. **Values Files**: Using external files for environment-specific configurations
6. **Resource Management**: Configuring resource limits and autoscaling
7. **Validation**: Testing and validating deployments
8. **Management**: History, rollback, and cleanup operations

## Key Helm Commands Reference

```bash
# Chart management
helm create <chart-name>
helm template <release> <chart>
helm lint <chart>

# Installation and upgrades
helm install <release> <chart>
helm upgrade <release> <chart>
helm uninstall <release>

# Values and configuration
helm install <release> <chart> --set key=value
helm install <release> <chart> -f values.yaml
helm get values <release>

# History and rollback
helm history <release>
helm rollback <release> <revision>

# Information
helm list
helm status <release>
helm show values <chart>
```

## Next Steps

- Explore Helm hooks for advanced deployment workflows
- Learn about chart dependencies and sub-charts
- Implement Helm tests for automated validation
- Study chart packaging and repository management