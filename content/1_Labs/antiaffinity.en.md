---
title: 'Pod Anti Affinity'
date: 2024-06-06T14:15:26+10:00
draft: false
weight: 100
tags: ["Kubernetes", "Scheduling", "Affinity"]
---

## Create a nginx deployment with 3 pods


{{%expand "Solution" %}}
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: gcr.io/google_containers/nginx-slim:0.9
        ports:
        - containerPort: 8080
```
{{% /expand%}}

## Add a 'podAntiAffinity' section to the deployment

The goal is to distribute all pod for this deployment across different nodes.

Use this example:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: with-pod-affinity
spec:
  affinity:
    podAntiAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
      - labelSelector:
          matchExpressions:
          - key: security
            operator: In
            values:
            - S1
        topologyKey: topology.kubernetes.io/zone
  containers:
  - name: with-pod-affinity
    image: registry.k8s.io/pause:2.0
```

{{%expand "Solution" %}}
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchExpressions:
              - key: app
                operator: In
                values:
                - nginx
            topologyKey: kubernetes.io/hostname
      containers:
      - name: nginx
        image: gcr.io/google_containers/nginx-slim:0.9
        ports:
        - containerPort: 8080
```
{{% /expand%}}
