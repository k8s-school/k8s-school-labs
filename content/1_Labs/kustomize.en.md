---
title: 'Kustomize'
date: 2025-11-11T14:15:26+10:00
draft: false
weight: 150
tags: ["Kubernetes", "Kustomize"]
---

## Lab Overview

In this quick lab, you will learn the essentials of Kustomize by creating a base configuration and two environment overlays (dev and production).

**Duration**: 10-15 minutes

**Prerequisites**:
- kubectl installed (with Kustomize support)
- Basic understanding of Kubernetes resources

---

## Exercise 1: Setup Base Configuration

### Objective
Create a base configuration for a simple nginx application.

### Tasks

1. Create the directory structure and base files:

```bash
mkdir -p myapp/base myapp/overlays/{dev,production}
```

2. Create `base/deployment.yaml`:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp
spec:
  replicas: 2
  selector:
    matchLabels:
      app: webapp
  template:
    metadata:
      labels:
        app: webapp
    spec:
      containers:
      - name: nginx
        image: nginx:1.21
        ports:
        - containerPort: 80
```

3. Create `base/service.yaml`:
```yaml
apiVersion: v1
kind: Service
metadata:
  name: webapp
spec:
  selector:
    app: webapp
  ports:
  - port: 80
    targetPort: 80
```

4. Create `base/kustomization.yaml`:
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- deployment.yaml
- service.yaml
```

5. Test your base configuration:
```bash
kubectl kustomize myapp/base/
```

**Expected**: You should see both Deployment and Service manifests output.

---

## Exercise 2: Create Development Overlay

### Objective
Customize the base for a development environment with reduced resources.

### Tasks

1. Create `overlays/dev/kustomization.yaml`:
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namePrefix: dev-

labels:
- includeSelectors: true
  pairs:
    environment: dev

resources:
- ../../base

replicas:
- name: webapp
    count: 1
```

2. Build and observe the changes:
```bash
kubectl kustomize myapp/overlays/dev/
```

**Question**: What changed compared to the base?

{{%expand "Answer" %}}

Changes applied by the dev overlay:
- ✅ Resources are prefixed with `dev-` (dev-webapp)
- ✅ Replicas reduced from 2 to 1
- ✅ Label `environment=dev` added to all resources
- ✅ Service selector automatically updated to match new labels

{{% /expand%}}

---

## Exercise 3: Create Production Overlay

### Objective
Create a production overlay with increased replicas, updated image, and a ConfigMap.

### Tasks

1. Create `overlays/production/kustomization.yaml`:
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namePrefix: prod-

labels:
- includeSelectors: true
  pairs:
    environment: production

resources:
- ../../base

replicas:
- name: webapp
    count: 5

images:
- name: nginx
    newTag: "1.23"

configMapGenerator:
- name: webapp-config
    literals:
  - ENV=production
  - LOG_LEVEL=info
```

2. Create `overlays/production/resources-patch.yaml` to add resource limits:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp
spec:
  template:
    spec:
      containers:
      - name: nginx
        resources:
          limits:
            cpu: 200m
            memory: 256Mi
          requests:
            cpu: 100m
            memory: 128Mi
```

3. Update `overlays/production/kustomization.yaml` to include the patch:
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namePrefix: prod-

labels:
- includeSelectors: true
  pairs:
    environment: production

resources:
- ../../base

patches:
- path: resources-patch.yaml

replicas:
- name: webapp
    count: 5

images:
- name: nginx
    newTag: "1.23"

configMapGenerator:
- name: webapp-config
    literals:
  - ENV=production
  - LOG_LEVEL=info
```

4. Build the production overlay:
```bash
kubectl kustomize myapp/overlays/production/
```

**Question**: What are all the differences between dev and production?

{{%expand "Answer" %}}

**Development**:
- Prefix: `dev-`
- Replicas: 1
- Image: nginx:1.21 (from base)
- No resource limits
- No ConfigMap
- Label: environment=dev

**Production**:
- Prefix: `prod-`
- Replicas: 5
- Image: nginx:1.23 (upgraded)
- Resource limits and requests defined
- ConfigMap generated with hash suffix (e.g., `webapp-config-abc123`)
- Label: environment=production

The ConfigMap hash suffix ensures immutability - any change in content creates a new ConfigMap, triggering pod updates.

{{% /expand%}}

---

## Exercise 4: Compare and Deploy (Optional)

### Objective
Compare both environments and optionally deploy them.

### Tasks

1. Compare the two overlays side by side:
```bash
diff <(kubectl kustomize myapp/overlays/dev/) <(kubectl kustomize myapp/overlays/production/)
```

2. **Optional** - If you have a cluster, deploy both:
```bash
# Deploy dev
kubectl apply -k myapp/overlays/dev/

# Deploy production to a separate namespace
kubectl create namespace production
kubectl apply -k myapp/overlays/production/ -n production

# Verify
kubectl get all -l environment=dev
kubectl get all -n production -l environment=production

# Clean up
kubectl delete -k myapp/overlays/dev/
kubectl delete -k myapp/overlays/production/ -n production
kubectl delete namespace production
```

---

## Key Takeaways

**What you learned:**

✅ **Base + Overlays pattern**: Common config in base, environment-specific in overlays
✅ **Transformers**: namePrefix, commonLabels, replicas, images
✅ **Patches**: Strategic merge patches for targeted modifications
✅ **Generators**: ConfigMaps with automatic hash suffixes
✅ **No templates**: Pure YAML manipulation, easy to understand

**Kustomize workflow:**
```
1. Create base with common resources
2. Create overlays for each environment
3. Use transformers for simple changes
4. Use patches for complex modifications
5. Build with: kubectl kustomize <overlay-path>/
6. Apply with: kubectl apply -k <overlay-path>/
```

**When to use what:**

| Need | Use |
|------|-----|
| Add prefix/suffix | namePrefix/nameSuffix |
| Add labels to all | commonLabels |
| Change replicas | replicas field |
| Update image tag | images field |
| Generate ConfigMap | configMapGenerator |
| Modify specific fields | patches |

---

## Quick Reference

```bash
# Build kustomization
kubectl kustomize <directory>

# Apply kustomization
kubectl apply -k <directory>

# Delete kustomization
kubectl delete -k <directory>

# Validate (dry-run)
kubectl apply -k <directory> --dry-run=client

# See only specific resource
kubectl kustomize <directory> | grep -A 20 "kind: Deployment"
```

---

## Challenge (If Time Permits)

Try to add a staging overlay that:
- Uses prefix `staging-`
- Has 3 replicas
- Uses nginx:1.22
- Adds annotation: `description: "Staging environment"`

{{%expand "Answer" %}}

```bash
# Create overlays/staging/kustomization.yaml
cat <<EOF > myapp/overlays/staging/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namePrefix: staging-

labels:
- includeSelectors: true
  pairs:
    environment: staging

commonAnnotations:
  description: "Staging environment"

resources:
- ../../base

replicas:
- name: webapp
    count: 3

images:
- name: nginx
    newTag: "1.22"
EOF

# Build it
kubectl kustomize myapp/overlays/staging/
```

{{% /expand%}}

---

## Resources

- [Kustomize Documentation](https://kustomize.io/)
- [Kubectl Kustomize](https://kubectl.docs.kubernetes.io/references/kustomize/)
