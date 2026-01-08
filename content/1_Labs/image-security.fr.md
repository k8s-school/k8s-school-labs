---
title: 'Image Security & Kyverno'
date: 2024-06-06T17:00:00+10:00
draft: false
weight: 50
tags: ["CKS", "Trivy", "Kyverno"]
---

## 1. Scanner une image (Trivy)
Scanner une image pour trouver des vulnérabilités critiques.

{{%expand "Solution" %}}
```bash
trivy image --severity CRITICAL nginx:1.18

```

{{% /expand%}}

## 2. Admission Controller (Kyverno)

Créer une règle pour interdire le tag `latest`.

{{%expand "Solution" %}}

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: block-latest-tag
spec:
  validationFailureAction: enforce
  rules:
  - name: require-tag
    match:
      any:
      - resources:
          kinds:
          - Pod
    validate:
      message: "Le tag 'latest' est interdit pour la production."
      pattern:
        spec:
          containers:
          - image: "!*:latest"

```

{{% /expand%}}
