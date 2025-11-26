# TP Helm Chart - Demo Application

## Objective
Create and deploy a Helm chart with a nginx application, including deployment, service, and configmap configurations. Learn how to customize values using `--set` and values files.

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
tree demo-app/
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

## Part 2: Configure the Application

### Step 3: Update the nginx image
The chart was configured to use:
- Image: `nginxinc/nginx-unprivileged:1.28.0-alpine3.21-perl`
- This is a security-enhanced nginx image that runs as non-root

### Step 4: Add ConfigMap for custom content
A ConfigMap has been added to provide custom HTML content for nginx.

## Part 3: Deploy the Application

### Step 5: Install the chart with default values
```bash
# Deploy with default configuration
helm install my-demo-app ./demo-app

# Verify deployment
kubectl get pods,svc,configmap
```

### Step 6: Check the application
```bash
# Port forward to access the application
kubectl port-forward service/my-demo-app 8080:80

# In another terminal, test the application
curl http://localhost:8080
```

You should see the custom HTML content from the ConfigMap.

## Part 4: Customization with --set

### Step 7: Override values using --set
```bash
# Change replica count
helm upgrade my-demo-app ./demo-app --set replicaCount=3

# Change the custom HTML content
helm upgrade my-demo-app ./demo-app \
  --set 'configmap.data.index\.html=<h1>Updated via --set</h1><p>This content was changed using --set flag</p>'

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

configmap:
  data:
    index.html: |
      <!DOCTYPE html>
      <html>
      <head>
          <title>Development Environment</title>
          <style>
              body { font-family: Arial, sans-serif; background-color: #e8f4f8; }
              .container { max-width: 800px; margin: 0 auto; padding: 20px; }
              h1 { color: #2c5aa0; }
          </style>
      </head>
      <body>
          <div class="container">
              <h1>Development Environment</h1>
              <p>This is the development version of our demo app.</p>
              <p>Deployed with custom values file.</p>
          </div>
      </body>
      </html>
```

Create `values-prod.yaml`:
```yaml
replicaCount: 5

image:
  tag: "1.28.0-alpine3.21-perl"

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

configmap:
  data:
    index.html: |
      <!DOCTYPE html>
      <html>
      <head>
          <title>Production Application</title>
          <style>
              body { font-family: Arial, sans-serif; background-color: #f0f8ff; }
              .container { max-width: 1200px; margin: 0 auto; padding: 20px; }
              h1 { color: #d2691e; }
              .warning { background-color: #fff3cd; padding: 10px; border-radius: 5px; }
          </style>
      </head>
      <body>
          <div class="container">
              <h1>Production Application</h1>
              <div class="warning">
                  <strong>Notice:</strong> This is a production environment.
              </div>
              <p>High availability deployment with 5 replicas.</p>
          </div>
      </body>
      </html>
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

# Check ConfigMap content
kubectl get configmap my-demo-app-config -o yaml
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

## Part 7: Advanced Operations

### Step 13: Helm template and dry-run
```bash
# Generate manifests without installing
helm template my-demo-app ./demo-app -f values-dev.yaml

# Perform dry-run to validate
helm install my-demo-app-test ./demo-app --dry-run --debug -f values-prod.yaml
```

### Step 14: History and rollback
```bash
# View release history
helm history my-demo-app

# Rollback to previous version
helm rollback my-demo-app 1

# Rollback to specific revision
helm rollback my-demo-app 2
```

### Step 15: Cleanup
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
2. **Configuration**: Customizing charts with values.yaml
3. **Deployment**: Installing charts with default and custom values
4. **CLI Customization**: Using `--set` flags for quick overrides
5. **Values Files**: Using external files for environment-specific configurations
6. **Validation**: Testing and validating deployments
7. **Management**: History, rollback, and cleanup operations

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