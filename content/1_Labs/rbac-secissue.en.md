---
title: 'RBAC monitoring'
date: 2024-06-06T14:15:26+10:00
draft: false
weight: 70
tags: ["Kubernetes", "RBAC", "Authorization", "Monitoring", "Security", "CKA", "CKS"]
---

## Exercice: find RBAC security issue

Connect to Kubernetes:

```bash
ktbx desk
kubectx kind-kind
```

Then use:
https://github.com/alcideio/rbac-tool
https://github.com/kubescape/kubescape
https://github.com/corneliusweig/rakkess

To find the RBAC security issue in the cluster.
