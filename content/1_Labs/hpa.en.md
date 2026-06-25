---
title: "Horizontal Pod Autoscaling (HPA)"
description: "Right-size cost by scaling the number of replicas automatically based on CPU load with the Horizontal Pod Autoscaler"
weight: 230
tags: ["FinOps", "Cost Management", "HPA", "Autoscaling"]
---

## Objectives

Use the **Horizontal Pod Autoscaler (HPA)** to automatically scale the number of pod replicas based on CPU usage, so the workload matches demand instead of paying for idle capacity.

## Prerequisites

### Understanding HPA

The Horizontal Pod Autoscaler scales a workload **out** (more replicas) or **in** (fewer replicas) by watching a metric such as CPU utilization. It is one of the core FinOps levers on Kubernetes: capacity follows demand.

### Q1: What does the HPA need to work?

{{%expand "Answer" %}}

- A **metrics source** (`metrics-server`) to read pod CPU/memory usage.
- **Resource `requests`** defined on the container — utilization is computed as `usage / request`.
- A scalable target (Deployment, ReplicaSet, StatefulSet).

The HPA controller periodically computes:

```
desiredReplicas = ceil(currentReplicas × currentMetricValue / targetMetricValue)
```

{{% /expand%}}

### Q2: When should you use HPA vs VPA?

{{%expand "Answer" %}}

- **HPA** is best for **stateless** services with variable traffic: more load → more replicas.
- **VPA** is best for **right-sizing requests** of workloads with a stable replica count.
- Avoid running both on the **same** CPU/memory metric — they fight each other.

{{% /expand%}}

## Setup

Install the lab environment (kind cluster + `metrics-server`) with the dedicated script:

```bash
./install.sh
```

Verify metrics are available:

```bash
kubectl top nodes
kubectl top pods -A
```

## Deploy a CPU-bound workload

We use the classic `php-apache` image, which burns CPU on every HTTP request.

> **Shared cluster:** run the lab in a namespace suffixed by your user name so several students can work on the same cluster without collisions.

```bash
export NS="hpa-demo-$USER"
kubectl create namespace "$NS"
kubectl config set-context --current --namespace="$NS"

kubectl apply -f https://k8s.io/examples/application/php-apache.yaml
kubectl rollout status deployment/php-apache
```

> **Note:** The Deployment defines `cpu: 200m` as a **request** and `cpu: 500m` as a **limit**. The request is what the HPA uses as the 100% reference for utilization.

## Create the HorizontalPodAutoscaler

### Q3: Create an HPA targeting 50% average CPU, between 1 and 10 replicas.

{{%expand "Solution" %}}

```bash
kubectl autoscale deployment php-apache --cpu-percent=50 --min=1 --max=10

# Inspect it
kubectl get hpa php-apache
```

The first reading may show `<unknown>` for a few seconds until `metrics-server` reports usage:

```bash
# Wait until TARGETS shows a percentage instead of <unknown>
kubectl get hpa php-apache -w
```

{{% /expand%}}

## Generate load and watch it scale OUT

Open **two terminals** (or use `byobu`).

**Terminal 1** — watch the autoscaler and the deployment:

```bash
kubectl get hpa php-apache -w
```

**Terminal 2** — generate load:

```bash
kubectl run load-generator --image=busybox:1.36 --restart=Never -- \
  /bin/sh -c "while true; do wget -q -O- http://php-apache; done"
```

After 1–2 minutes the CPU target is exceeded and the HPA increases the replica count:

```bash
kubectl get deployment php-apache
kubectl get pods -l run=php-apache
```

**Expected:** `TARGETS` climbs well above 50% and `REPLICAS` grows toward the maximum.

## Stop the load and watch it scale IN

```bash
kubectl delete pod load-generator
```

After the stabilization window (default ~5 minutes for scale-down) the replica count drops back to `1`:

```bash
kubectl get hpa php-apache -w
```

> **FinOps takeaway:** the scale-down stabilization window prevents flapping, but it also means you keep paying for extra replicas a few minutes after the spike ends. Tune `behavior.scaleDown.stabilizationWindowSeconds` to balance cost vs responsiveness.

## Automated run

The whole exercise is automated in:

```bash
./ex1-hpa.sh
```

## Cleanup

```bash
kubectl delete namespace "$NS"
kubectl config set-context --current --namespace=default
```

## Troubleshooting

```bash
# TARGETS stuck at <unknown> ?  metrics-server is not serving metrics:
kubectl top pods -n "$NS"
kubectl logs -n kube-system deployment/metrics-server

# On kind, metrics-server must run with --kubelet-insecure-tls (handled by install.sh)
kubectl get deployment metrics-server -n kube-system -o yaml | grep -A5 args
```
