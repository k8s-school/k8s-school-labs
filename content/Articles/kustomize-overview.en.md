---
title: ' Kustomize - Kubernetes Native Configuration Management'
date: 2025-09-21T14:15:26+10:00
draft: false
weight: 30
tags: ["kubernetes", "kustomize"]
---

## What is Kustomize?

- **Native Kubernetes tool** for customizing application configurations
- **Template-free**: Works with plain YAML manifests
- **Declarative approach**: Define variations as patches and overlays
- **Built into kubectl** since v1.14 (`kubectl apply -k`)

### Key Principles

- **Base + Overlays**: Keep common resources in base, environment-specific changes in overlays
- **No templating**: Pure YAML manipulation
- **DRY (Don't Repeat Yourself)**: Reuse base configurations across environments

---

## Core Concepts

### Directory Structure

```
├── base/
│   ├── kustomization.yaml
│   ├── deployment.yaml
│   └── service.yaml
└── overlays/
    ├── dev/
    │   └── kustomization.yaml
    ├── staging/
    │   └── kustomization.yaml
    └── production/
        ├── kustomization.yaml
        └── patches/
            └── resources-patch.yaml
```

### kustomization.yaml

The main configuration file that defines:
- **resources**: List of Kubernetes manifests to include
- **patches**: Modifications to apply (modern syntax)
- **labels**: Labels to add to all resources (replaces deprecated `commonLabels`)
- **namePrefix/nameSuffix**: Modify resource names
- **images**: Update container images
- **configMapGenerator**: Generate ConfigMaps
- **secretGenerator**: Generate Secrets

---

## Key Features

### 1. Resource Management

```yaml
# kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- deployment.yaml
- service.yaml
- configmap.yaml
```

### 2. Modern Patches Syntax

```yaml
# Strategic Merge Patch (modern syntax)
patches:
- path: patches/increase-replicas.yaml

# Inline Strategic Merge Patch
patches:
- patch: |-
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: myapp
    spec:
      replicas: 3

# JSON Patch
patches:
- target:
    kind: Deployment
    name: myapp
  patch: |-
    - op: replace
      path: /spec/replicas
      value: 3
```

### 3. Generators

```yaml
# ConfigMap Generator
configMapGenerator:
- name: app-config
  files:
  - config.properties
  literals:
  - ENV=production
  - LOG_LEVEL=info

# Secret Generator
secretGenerator:
- name: db-secret
  literals:
  - password=s3cr3t
  - username=admin
  type: Opaque
```

### 4. Modern Transformers

```yaml
# Modern labels syntax (replaces deprecated commonLabels)
labels:
- includeSelectors: true
  pairs:
    app: myapp
    team: platform
    environment: production

# Add prefix/suffix to resource names
namePrefix: prod-
nameSuffix: -v2

# Update images with digest support
images:
- name: myapp
  newName: registry.example.com/myapp
  newTag: "v2.0.0"
  # Or use digest for immutable deployments
  # digest: sha256:abc123...

# Replicas transformer
replicas:
- name: myapp
  count: 5
```

---

## Best Practices

### Directory Organization
```
myapp/
├── base/
│   ├── kustomization.yaml
│   ├── deployment.yaml
│   ├── service.yaml
│   └── configmap.yaml
├── components/          # Reusable configurations
│   └── monitoring/
│       ├── kustomization.yaml
│       └── servicemonitor.yaml
└── overlays/
    ├── dev/
    │   ├── kustomization.yaml
    │   └── patches/
    │       └── dev-patch.yaml
    ├── staging/
    │   ├── kustomization.yaml
    │   └── patches/
    └── production/
        ├── kustomization.yaml
        ├── patches/
        │   ├── replicas.yaml
        │   └── resources.yaml
        └── secrets/
            └── sealed-secret.yaml
```

### Configuration Example

```yaml
# overlays/production/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: production

# Use modern labels syntax
labels:
- includeSelectors: true
  pairs:
    environment: production
    tier: frontend

resources:
- ../../base

# Modern patches syntax
patches:
- path: patches/resources.yaml
- patch: |-
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: myapp
    spec:
      replicas: 5

# Image management
images:
- name: nginx
  newTag: "1.24-alpine"

# Config generation with behavior
configMapGenerator:
- name: app-config
  behavior: merge
  literals:
  - LOG_LEVEL=warn
  - ENVIRONMENT=production
```

---

## Advantages

✅ **No external dependencies**: Built into kubectl

✅ **Pure YAML**: No learning a templating language

✅ **Declarative**: Easy to understand and version control

✅ **Composable**: Layer configurations logically

✅ **Maintainable**: Clear separation between base and environment-specific configs

✅ **Modern syntax**: Actively maintained with new features

✅ **GitOps ready**: Perfect for ArgoCD, Flux workflows

## When to Use Kustomize

- **Multi-environment deployments** (dev, staging, prod)
- **Customizing third-party manifests** without modifying originals
- **GitOps workflows** (ArgoCD, Flux, etc.)
- **Progressive delivery** with environment-specific configurations
- **Compliance requirements** with immutable base configurations

## Kustomize vs Other Tools

| Feature | Kustomize | Helm | Jsonnet |
|---------|-----------|------|---------|
| Templating | No (YAML patches) | Yes (Go templates) | Yes (data templating) |
| Package Management | No | Yes | No |
| Built into kubectl | Yes | No | No |
| Learning Curve | Low | Medium | High |
| Type Safety | No | No | Yes |
| Flexibility | High | Very High | Very High |
| Community | Large | Very Large | Medium |

## Migration Notes

### Deprecated → Modern Syntax

```yaml
# OLD (deprecated)
bases:
- ../../base
commonLabels:
  app: myapp
patchesStrategicMerge:
- patch.yaml

# NEW (modern)
resources:
- ../../base
labels:
- includeSelectors: true
  pairs:
    app: myapp
patches:
- path: patch.yaml
```

---

## Quick Commands

```bash
# Generate manifests
kubectl kustomize ./overlays/production

# Apply directly
kubectl apply -k ./overlays/production

# Validate without applying
kubectl apply -k ./overlays/production --dry-run=client

# View diff
kubectl diff -k ./overlays/production

# Build to file
kubectl kustomize ./overlays/production > production.yaml
```

## Lab

[Kustomize Lab](https://k8s-school.fr/labs/en/1_labs/kustomize/index.html)

## Resources

- [Official Kustomize Documentation](https://kustomize.io/)
- [Kubectl Kustomize Reference](https://kubectl.docs.kubernetes.io/references/kustomize/)
- [Kustomize Examples Repository](https://github.com/kubernetes-sigs/kustomize/tree/master/examples)
- [Best Practices Guide](https://kubectl.docs.kubernetes.io/guides/config_management/)