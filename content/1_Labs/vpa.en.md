---
title: "Vertical Pod Autoscaling (VPA)"
description: "Right-size CPU and memory requests automatically with the Vertical Pod Autoscaler to cut waste and avoid OOMKills"
weight: 235
tags: ["FinOps", "Cost Management", "VPA", "Autoscaling", "Right-sizing"]
---

## Objectives

Use the **Vertical Pod Autoscaler (VPA)** to right-size pod CPU/memory **requests** based on real usage. This is the FinOps answer to over-provisioning: you stop paying for resources you never use, while avoiding throttling and OOMKills.

## Prerequisites

### Understanding VPA

Unlike the HPA (which changes the *number* of pods), the VPA changes the *size* of each pod by adjusting its resource **requests**. It has three components:

- **Recommender**: observes historical usage and computes target requests.
- **Updater**: evicts pods whose requests are too far from the recommendation.
- **Admission Controller**: rewrites the requests when the pod is (re)created.

### Q1: What are the VPA update modes?

{{%expand "Answer" %}}

- **`Off`**: only produce recommendations (no pod is disrupted) — safest, great for analysis.
- **`Initial`**: apply recommendations only at pod creation.
- **`Recreate`**: evict running pods and recreate them with the recommended requests.
- **`InPlaceOrRecreate`**: resize in place when possible (k8s 1.33+), otherwise recreate.

> **⚠️ Note:** the legacy **`Auto`** mode is **deprecated since VPA 1.7.0** — use the explicit modes above (`Auto` currently behaves like `Recreate`).

For production, many teams keep VPA in `Off` mode and feed recommendations into their sizing/GitOps process.

{{% /expand%}}

### Q2: Why not combine VPA and HPA on CPU?

{{%expand "Answer" %}}

Both would react to the same CPU signal and fight each other: the HPA adds replicas while the VPA changes requests, leading to instability. Safe combinations:

- VPA on **memory**, HPA on **CPU**.
- VPA in **`Off`** mode (recommendations only) alongside an HPA.
- HPA on **custom/external** metrics, VPA on CPU/memory.

{{% /expand%}}

## Setup

Install the lab environment (kind cluster + `metrics-server` + the **official** VPA operator) with the dedicated script:

```bash
./install.sh
```

> The script installs VPA using the official method documented in the autoscaler repo:
> `git clone https://github.com/kubernetes/autoscaler.git` then `./hack/vpa-up.sh`.

Verify the VPA components are running:

```bash
kubectl get pods -n kube-system | grep vpa
# vpa-recommender, vpa-updater, vpa-admission-controller
```

## Deploy an under-sized workload

We deploy the `hamster` workload from the VPA examples, burning CPU with deliberately **low** requests (`cpu: 50m`).

> **Shared cluster:** run the lab in a namespace suffixed by your user name so several students can work on the same cluster without collisions.

```bash
export NS="vpa-demo-$USER"
kubectl create namespace "$NS"
kubectl config set-context --current --namespace="$NS"
```

```bash
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hamster
spec:
  replicas: 2
  selector:
    matchLabels:
      app: hamster
  template:
    metadata:
      labels:
        app: hamster
    spec:
      containers:
      - name: hamster
        image: registry.k8s.io/ubuntu-slim:0.14
        resources:
          requests:
            cpu: 50m
            memory: 50Mi
        command: ["/bin/sh"]
        args: ["-c", "while true; do timeout 0.5s yes >/dev/null; sleep 0.5s; done"]
EOF

kubectl rollout status deployment/hamster
```

## Create a VPA in recommendation-only mode

### Q3: Create a VPA targeting the `hamster` Deployment in `Off` mode.

{{%expand "Solution" %}}

```bash
cat <<EOF | kubectl apply -f -
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: hamster-vpa
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: hamster
  updatePolicy:
    updateMode: "Off"
EOF
```

{{% /expand%}}

## Read the recommendation

The recommender needs a few minutes of metrics before it emits advice.

```bash
# Watch until status.recommendation appears
kubectl get vpa hamster-vpa -o yaml | grep -A20 "recommendation:"

# Or, human readable:
kubectl describe vpa hamster-vpa
```

You should see something like:

```
Container Recommendations:
  Container Name:  hamster
  Lower Bound:
    Cpu:     <…>
    Memory:  <…>
  Target:
    Cpu:     <≈ 500m, much higher than the 50m we requested>
    Memory:  <…>
  Upper Bound:
    Cpu:     <…>
```

- **Target**: the requests the VPA recommends (use these for right-sizing).
- **Lower/Upper bound**: the confidence interval.

> **FinOps takeaway:** the gap between the `50m` we requested and the `Target` is exactly the kind of mis-sizing that wastes money (too low → throttling) or money on idle nodes (too high). The VPA quantifies the right value from real data.

## Apply the recommendation automatically

Switch the VPA to `Recreate` mode and watch pods get recreated with the new requests:

```bash
kubectl patch vpa hamster-vpa --type merge \
  -p '{"spec":{"updatePolicy":{"updateMode":"Recreate"}}}'
```

> The old `Auto` mode is deprecated since VPA 1.7.0; `Recreate` is its explicit equivalent.

Watch the requests change as the updater evicts and recreates pods:

```bash
kubectl get pods -o custom-columns=\
'NAME:.metadata.name,CPU_REQ:.spec.containers[0].resources.requests.cpu,MEM_REQ:.spec.containers[0].resources.requests.memory' -w
```

**Expected:** new pods appear with `CPU_REQ` close to the VPA `Target` instead of `50m`.

> **⚠️ Disruption warning:** `Recreate` mode evicts pods. Use a `PodDisruptionBudget` and never apply it to single-replica critical workloads.

## (Bonus) Resize in place, without recreating pods

Since **Kubernetes 1.33+**, the VPA can resize a running pod *without recreating it*, using the *In-Place Pod Resize* feature. The mode is `InPlaceOrRecreate`: it tries an in-place resize and falls back to `Recreate` only when needed.

### Q4: How is `InPlaceOrRecreate` different from the HPA?

{{%expand "Answer" %}}

Both avoid disrupting traffic, but they act on **different axes**:

- The **HPA** changes the **number** of pods (horizontal) and reacts in seconds.
- The **VPA in-place** changes the **size** (requests) of each *existing* pod (vertical), based on usage history.

They are complementary, not interchangeable — and must not drive the same CPU/memory metric.

{{% /expand%}}

> **⚠️ Version check:** this step requires the API server at **v1.33 or newer**. On older clusters it silently falls back to `Recreate`.
>
> ```bash
> kubectl get --raw /version | grep '"minor"'
> ```

The previous `Recreate` step already right-sized the pods, so there is nothing
left to resize. To actually *observe* an in-place resize, we first reset the pods
back to their `50m` baseline:

- set the VPA to `Off` so its admission webhook stops injecting the recommendation;
- delete the pods so the Deployment recreates them at the manifest's `50m`.

```bash
# 1. Stop the VPA from mutating new pods (admission webhook stays passive)
kubectl patch vpa hamster-vpa --type merge \
  -p '{"spec":{"updatePolicy":{"updateMode":"Off"}}}'

# 2. Recreate the pods at their baseline request
kubectl delete pod -l app=hamster
kubectl rollout status deployment/hamster

# 3. Confirm the requests have reverted to 50m
kubectl get pods -l app=hamster \
  -o custom-columns='NAME:.metadata.name,START:.status.startTime,CPU_REQ:.spec.containers[0].resources.requests.cpu'

# 4. Now switch to in-place mode and watch the live resize
kubectl patch vpa hamster-vpa --type merge \
  -p '{"spec":{"updatePolicy":{"updateMode":"InPlaceOrRecreate"}}}'
```

Watch the requests change while the pod keeps the **same `NAME` and `START` time**:

```bash
kubectl get pods -l app=hamster -w \
  -o custom-columns='NAME:.metadata.name,START:.status.startTime,CPU_REQ:.spec.containers[0].resources.requests.cpu,MEM_REQ:.spec.containers[0].resources.requests.memory'
```

**Expected:** unlike `Recreate`, the pod is **not** replaced — only its requests are updated live (CPU resizes without restart; a memory change may restart the container depending on its `resizePolicy`).

## Automated run

The whole exercise is automated in:

```bash
./ex2-vpa.sh
```

## Cleanup

```bash
kubectl delete namespace "$NS"
kubectl config set-context --current --namespace=default
```

## Troubleshooting

```bash
# No recommendation after several minutes?
kubectl logs -n kube-system deployment/vpa-recommender

# metrics-server must be serving usage data (VPA prerequisite)
kubectl top pods -n "$NS"

# Remove the VPA operator entirely (official uninstall)
# cd /tmp/autoscaler/vertical-pod-autoscaler && ./hack/vpa-down.sh
```
