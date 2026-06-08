---
title: 'Helm on OpenShift: Migrating to Security Context Constraints'
date: 2026-06-08T14:15:26+10:00
draft: false
weight: 152
tags: ["OpenShift", "Helm", "Security", "SCC"]
---

## Objective

A Helm chart that works perfectly on vanilla Kubernetes often fails on OpenShift. In this guided lab you'll deploy a generic nginx Helm chart step by step — from its default values (which fail) to an OpenShift-compatible configuration (which succeeds) — diagnosing each failure along the way with `oc`/`kubectl`.

You'll learn:
- Why OpenShift's Security Context Constraints (SCC) prevent containers from running as root
- How OpenShift assigns a non-root UID per namespace, and why that breaks images that assume root
- How to adapt a chart (here, the official `nginx` image) to run under `restricted-v2`

Complete this lab in 20-30 minutes.

## Prerequisites

- An OpenShift cluster, logged in with `oc`
- `helm` v3+
- `kubectl`

## Setup

Clone the chart and create a dedicated project:

```bash
git clone https://github.com/k8s-school/openshift-advanced.git
cd openshift-advanced/labs

NGINX_VERSION="1.25.3"     # see conf.version.sh
CHART="$PWD/nginx-chart"

oc new-project helm-migration-$USER
```

Have a look at the chart's default `values.yaml` (`$CHART/values.yaml`) — it is a typical "vanilla Kubernetes" chart: official `nginx` image, exposed on port 80 through a `LoadBalancer` Service:

```yaml
image:
  repository: nginx
  tag: "1.25.3"
service:
  type: LoadBalancer
  port: 80
containerPort: 80
```

## Exercise 1 — Deploy with the chart's default values

Install the chart as-is:

```bash
helm upgrade --install nginx $CHART \
    --namespace helm-migration-$USER \
    --set image.tag=$NGINX_VERSION \
    --wait --timeout 30s
```

**Question:** Does the install succeed? What's the status of the pod? Use `kubectl get events`, `kubectl get pods` and `kubectl logs` to find out **why**.

{{%expand "Answer" %}}
The Helm install times out (`Error: context deadline exceeded`): the pod gets scheduled and the container starts, but it keeps crashing.

```bash
kubectl get pods -l app=nginx
# nginx-5f567fd574-8jjln   0/1   CrashLoopBackOff   2 (15s ago)   31s

kubectl logs -l app=nginx --tail=10
# nginx: [warn] the "user" directive makes sense only if the master process runs with super-user privileges
# nginx: [emerg] mkdir() "/var/cache/nginx/client_temp" failed (13: Permission denied)
```

The official `nginx` image expects to run **as root** (UID 0): it writes its cache/temp directories under `/var/cache/nginx` (owned by root) and binds to port 80, a privileged port. OpenShift's `restricted-v2` Security Context Constraint forbids that — every container is forced to run under a non-root UID allocated to the namespace:

```bash
kubectl get namespace helm-migration-$USER \
    -o jsonpath='UID range: {.metadata.annotations.openshift\.io/sa\.scc\.uid-range}{"\n"}'
# UID range: 1000650000/10000

kubectl get pod -l app=nginx \
    -o jsonpath='{.items[0].spec.containers[0].securityContext.runAsUser}{"\n"}'
# 1000650000
```

UID `1000650000` owns nothing under `/var/cache/nginx` — hence the `Permission denied`. That non-root UID, not the `Service` type, is the real blocker (see the note below for a quota-related symptom that can appear *before* this one, on some clusters).
{{% /expand%}}

> **Note — LoadBalancer quota on the Red Hat Developer Sandbox**
>
> On the [Red Hat Developer Sandbox](https://developers.redhat.com/developer-sandbox), a `ClusterResourceQuota` sets `services.loadbalancers: 0`. Requesting a `LoadBalancer` Service is then rejected outright by the admission controller — before any pod is even created (`oc get appliedclusterresourcequota` shows the quota; no Kubernetes `Event` is generated, the error goes straight back to the Helm client). If your cluster enforces that quota, switch the `Service` type to `ClusterIP` first (Exercise 2), then come back to the SCC issue above.

## Exercise 2 — Switch the Service to ClusterIP

Override the service type only:

```bash
helm upgrade --install nginx $CHART \
    --namespace helm-migration-$USER \
    --set service.type=ClusterIP \
    --set image.tag=$NGINX_VERSION \
    --wait --timeout 30s
```

(equivalently, use the ready-made values file `6_helm_migration/manifests/nginx-values-v1.yaml`)

**Question:** Does this fix the deployment? Why or why not?

{{%expand "Answer" %}}
No. `ClusterIP` removes any `LoadBalancer`-quota concern, but the pod still crashes with the **exact same** `Permission denied` error as in Exercise 1:

```bash
kubectl get pods -l app=nginx
# nginx-...   0/1   CrashLoopBackOff
```

The `Service` type was never the root cause — it's that the official `nginx` image cannot start as a non-root UID, on a privileged port, with its default file paths. **Lesson:** the first symptom you encounter (a quota error, a `Service` misconfiguration) can mask a deeper platform-vs-image incompatibility. Keep diagnosing with `kubectl get events` / `oc logs` / `oc describe pod` until the pod actually reaches `Running`.
{{% /expand%}}

## Exercise 3 — Make the chart OpenShift-compatible

Look at `6_helm_migration/manifests/nginx-values-v2.yaml`. It changes three things compared to the defaults:

```yaml
service:
  type: ClusterIP
  port: 8080
containerPort: 8080

openShiftConfig: true        # mounts a custom nginx.conf, see below

podSecurityContext:
  runAsNonRoot: true
  seccompProfile:
    type: RuntimeDefault

securityContext:
  allowPrivilegeEscalation: false
  capabilities:
    drop: ["ALL"]
  seccompProfile:
    type: RuntimeDefault
```

`openShiftConfig: true` makes the chart mount a custom `nginx.conf` through a `ConfigMap` (see `$CHART/templates/configmap.yaml`) that:
- listens on port `8080` (non-privileged) instead of `80`
- redirects `pid` and every `*_temp_path` (client/proxy/fastcgi/uwsgi/scgi) to `/tmp` — writable by any UID

Deploy it:

```bash
helm upgrade --install nginx $CHART \
    --namespace helm-migration-$USER \
    --values 6_helm_migration/manifests/nginx-values-v2.yaml \
    --set image.tag=$NGINX_VERSION \
    --wait --timeout 60s
```

**Question:** Does it work this time? Which SCC is the running pod actually admitted under — and which UID does it run as?

{{%expand "Answer" %}}
Yes — the pod reaches `Running`:

```bash
kubectl get pods -l app=nginx
# nginx-5749599c9-kx2wd   1/1   Running   0   3s

kubectl get pod -l app=nginx \
    -o jsonpath='{.items[0].metadata.annotations.openshift\.io/scc}{"\n"}'
# restricted-v2
```

And the assigned UID is **still** `1000650000` — exactly the same as in Exercises 1 and 2. OpenShift granted no special privilege: the *application* was adapted to the constraints the platform enforced from the very first attempt (non-privileged port, writable paths under `/tmp`, an explicit `securityContext` matching what `restricted-v2` requires).
{{% /expand%}}

## Going further — inspecting SCCs directly

If you have enough rights, you can look at what `restricted-v2` enforces:

```bash
oc get scc restricted-v2 -o jsonpath='runAsUser: {.runAsUser}
fsGroup: {.fsGroup}
allowPrivilegedContainer: {.allowPrivilegedContainer}
requiredDropCapabilities: {.requiredDropCapabilities}
'
```

You can also ask the API server, *before* deploying anything, which SCC would admit a given pod spec — this requires `create podsecuritypolicyselfsubjectreviews.security.openshift.io`, a permission usually unavailable on shared/sandboxed clusters:

```bash
oc auth can-i create podsecuritypolicyselfsubjectreviews.security.openshift.io \
    --namespace helm-migration-$USER && \
oc adm policy scc-subject-review -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: nginx-probe
spec:
  containers:
  - name: nginx
    image: nginx:$NGINX_VERSION
    ports:
    - containerPort: 80
EOF
```

## Cleanup

```bash
oc delete project helm-migration-$USER
```

## Key Takeaways

1. **SCCs don't (only) reject pods at admission time** — `restricted-v2` silently assigns each pod a non-root UID from the range allocated to its namespace (`oc get namespace <ns> -o jsonpath='{.metadata.annotations.openshift\.io/sa\.scc\.uid-range}'`). The failure then surfaces *at runtime*, when the application can't operate under that UID.
2. **The first error you see is rarely the real one.** A `LoadBalancer` quota error or a `Service` misconfiguration can mask a deeper image/platform incompatibility — keep digging (`kubectl get events`, `oc logs`, `oc describe pod`) until the pod is actually `Running`.
3. **Fixing the chart means adapting the application, not relaxing the platform**: use non-privileged ports (`>1024`), redirect writable paths to `/tmp`, and declare a `securityContext` that matches what `restricted-v2` already requires (`runAsNonRoot`, all capabilities dropped, no privilege escalation, `seccompProfile: RuntimeDefault`).
4. **`oc get pod <name> -o jsonpath='{.metadata.annotations.openshift\.io/scc}'`** tells you exactly which SCC admitted a running pod — the fastest way to confirm what's really happening.

## Reference / full solution

- Full demo script: [`ex1-helm-migration.sh`](https://github.com/k8s-school/openshift-advanced/blob/main/labs/6_helm_migration/ex1-helm-migration.sh)
- Helm chart used in this lab: [`nginx-chart`](https://github.com/k8s-school/openshift-advanced/tree/main/labs/nginx-chart)
- Values files: [`nginx-values-v1.yaml`](https://github.com/k8s-school/openshift-advanced/blob/main/labs/6_helm_migration/manifests/nginx-values-v1.yaml), [`nginx-values-v2.yaml`](https://github.com/k8s-school/openshift-advanced/blob/main/labs/6_helm_migration/manifests/nginx-values-v2.yaml)
