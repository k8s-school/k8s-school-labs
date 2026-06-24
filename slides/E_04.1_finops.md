---
marp: true
theme: custom-theme
paginate: true
backgroundColor: #ffffff
---

# Cost Management on Kubernetes

## FinOps, Cost Optimization, HPA & VPA

<img src="images/logo.svg" alt="K8s School Logo" width="40%">

---

## Part 2: Cost Management

- **FinOps culture**
- **Cost Optimization**
- **Horizontal Pod Autoscaling (HPA)**
- **Vertical Pod Autoscaling (VPA)**
- **Instructor demo**
- **2 Labs**

---

## What is FinOps?

- **Definition**: A cultural practice bringing financial accountability to cloud spend.
- **Goal**: Maximize business value, not just minimize cost.
- **Shared ownership**: Engineering, Finance and Product decide together.

---

## The FinOps Lifecycle

- **Inform**: Visibility, allocation and showback/chargeback.
- **Optimize**: Right-sizing, autoscaling, removing waste.
- **Operate**: Continuous improvement and governance.

*An iterative loop, not a one-off project.*

---

## Why Kubernetes Costs Drift

- **Over-provisioning**: Requests set "just in case", far above real usage.
- **Idle capacity**: Nodes paid for but barely used.
- **No limits / no requests**: Unpredictable scheduling and bin-packing.
- **Forgotten workloads**: Dev namespaces never cleaned up.

---

## Cost Optimization Levers

- **Right-sizing**: Align requests/limits with actual consumption.
- **Autoscaling**: Match capacity to demand (HPA, VPA, Cluster Autoscaler).
- **Bin-packing**: Improve node density.
- **Spot / scheduling**: Cheaper compute for fault-tolerant jobs.

---

## Requests vs Limits

- **Requests**: Guaranteed resources → drive scheduling **and cost**.
- **Limits**: Hard ceiling → protect neighbours.
- **The FinOps target**: requests close to the real p95 usage.

*Too high → you pay for nothing. Too low → throttling and OOMKills.*

---

## Horizontal Pod Autoscaling (HPA)

- **Scales OUT**: adds/removes **replicas** of a workload.
- **Signal**: CPU, memory or custom/external metrics.
- **Needs**: `metrics-server` and resource **requests** defined.
- **Best for**: stateless services with variable traffic.

---

## HPA: How It Works

- **1.** `metrics-server` exposes pod CPU/memory usage.
- **2.** HPA controller compares usage to the target (e.g. 50% CPU).
- **3.** It computes the desired replica count.
- **4.** The Deployment is scaled out or in.

`desiredReplicas = ceil(currentReplicas × currentMetric / targetMetric)`

---

## LAB: Horizontal Pod Autoscaling

- **Exercise**: [Scaling php-apache under load with HPA](https://k8s-school.fr/labs/en/1_labs/hpa/index.html)

*Deploy a CPU-bound app, attach an HPA, generate load, watch it scale out and back in.*

---

## Vertical Pod Autoscaling (VPA)

- **Scales UP/DOWN**: adjusts CPU/memory **requests** per pod.
- **Components**: Recommender, Updater, Admission Controller.
- **Modes**: `Off` (recommend), `Initial`, `Recreate` (`Auto` deprecated).
- **Best for**: right-sizing workloads with stable replica counts.

---

## VPA: How It Works

- **Recommender**: observes usage history → computes target requests.
- **Updater**: evicts pods whose requests are off-target.
- **Admission Controller**: injects the new requests at pod (re)creation.

*Recommender → Updater → Admission Controller.*

---

## HPA vs VPA

- **HPA**: more pods for more traffic (horizontal).
- **VPA**: better-sized pods for real usage (vertical).
- **⚠️ Conflict**: avoid HPA + VPA on the **same CPU/memory** metric.
- **Combine**: VPA for memory, HPA for CPU, or VPA in `Off` mode for advice.

---

## HPA vs VPA at a glance

| | **HPA** | **VPA** |
|---|---|---|
| **Axis** | Horizontal (replicas) | Vertical (requests) |
| **Reaction** | Seconds | Minutes → hours |
| **Based on** | Current utilization | Usage history (percentiles) |
| **Disruption** | None | `Recreate` evicts; `InPlaceOrRecreate` resizes live (1.33+) |
| **Best for** | Traffic spikes | Right-sizing a workload |

---

## LAB: Vertical Pod Autoscaling

- **Exercise**: [Right-sizing with the VPA recommender](https://k8s-school.fr/labs/en/1_labs/vpa/index.html)

*Deploy an under-sized workload, read VPA recommendations, then let `Recreate` mode apply them.*

---

## Summary

- **FinOps** = culture of shared accountability for cloud cost.
- **Optimize** = right-size + autoscale + remove waste.
- **HPA** = scale replicas horizontally on load.
- **VPA** = right-size requests vertically from real usage.
- **Measure first**: `metrics-server` is the foundation of both.
