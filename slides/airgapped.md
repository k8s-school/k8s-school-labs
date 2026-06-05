---
marp: true
theme: custom-theme
paginate: true
backgroundColor: #ffffff
---

# OpenShift Airgapped Deployments

<img src="images/logo.svg" alt="K8s School Logo" width="50%">

---

## What is an Airgapped Environment?

An **airgapped** (disconnected) cluster has no Internet access from its nodes.

```
┌─────────────────────────────────────┐
│  Secured network (datacenter, OT…)  │
│                                     │
│  ┌──────────┐      ┌─────────────┐  │
│  │  Worker  │  ✗   │  docker.io  │  │
│  │  node    │──────│  quay.io    │  │
│  └──────────┘      │  registry.k8s│ │
│                    └─────────────┘  │
└─────────────────────────────────────┘
```

### Key Constraints

- **Images unreachable**: `docker.io`, `quay.io`, `registry.k8s.io` are blocked
- **Operator Catalogs**: OperatorHub offline → no OLM-based installs
- **Cluster updates**: OpenShift release images must be pre-downloaded
- **Third-party tools**: Helm chart images, base images, debug tools

> **Typical contexts**: industrial (OT/SCADA), defense, finance, sovereign cloud, certified environments (CC, SecNumCloud)

---

## OpenShift Solutions for Airgapped

### Target Architecture

```
Internet          DMZ / Bastion              Airgapped cluster
   │                   │                           │
   │  skopeo /         │                           │
   │  oc mirror ──────▶│  Local registry  ────────▶│  CRI-O
   │                   │  (Quay, Harbor,            │    │
   │                   │   registry:2)              │    ▼
   │                   │                           Pods
```

### The Three Building Blocks

| Block | Role | OpenShift resource |
|---|---|---|
| **Local registry** | Stores images internally | `registry:2`, Quay, Harbor |
| **Transparent redirect** | CRI-O redirects pulls to the mirror | `ImageTagMirrorSet` / `ImageDigestMirrorSet` |
| **Mirroring tool** | Feeds the local registry | `skopeo`, `oc mirror` |

> **`ImageTagMirrorSet`**: for **tag**-based pulls (`nginx:1.25.3`) — the common case with Helm charts
> **`ImageDigestMirrorSet`**: for **digest**-based pulls (`nginx@sha256:…`) — OLM, OCP release images

---

## Mirroring Tool: skopeo vs oc mirror

### skopeo — simple, one image at a time

```bash
skopeo copy docker://docker.io/library/nginx:1.25.3 \
            docker://registry.local:5000/library/nginx:1.25.3 \
            --dest-tls-verify=false
```

### oc mirror — declarative, delta-aware

```yaml
# imageset-config.yaml
kind: ImageSetConfiguration
apiVersion: mirror.openshift.io/v2alpha1
mirror:
  additionalImages:
  - name: docker.io/library/nginx:1.25.3
  - name: docker.io/library/alpine:3.19
  operators:
  - catalog: registry.redhat.io/redhat/redhat-operator-index:v4.16
```

```bash
oc mirror -c imageset-config.yaml \
    --workspace file:///tmp/mirror-workspace \
    docker://registry.local:5000
```

---

## skopeo vs oc mirror — Comparison

| | skopeo | oc mirror |
|---|---|---|
| **Config** | one command per image | single declarative YAML |
| **Delta between runs** | re-mirrors everything | state tracking → pushes only new layers |
| **Operator Catalogs** | no | yes (bundles, index) |
| **OCP release images** | manual | yes (built-in) |
| **10+ images** | 10 commands | 10 YAML lines |
| **Idempotent** | no | yes |
| **Dependencies** | lightweight | `oc-mirror` plugin required |
| **Recommended for** | PoC, 1–3 images | production, full application |

> **Rule of thumb**: use `skopeo` for a lab or a handful of one-off images; switch to `oc mirror` as soon as you manage a full application with multiple images or operators.

---

## Labs

### Exercise 1 — Transparent mirror with `ImageTagMirrorSet`
Deploy nginx via Helm in airgapped mode. CRI-O transparently redirects `docker.io` pulls to the local registry via `ImageTagMirrorSet`. No chart modification required.

### Exercise 2 — Explicit registry in the chart
Same deployment, but the local registry is passed explicitly via `--set image.registry`. No `MachineConfigPool` rollout to wait for.

### Exercise 3 — Multi-image mirroring with `oc mirror`
Use `oc mirror` to pre-load nginx + alpine into the local registry via an `ImageSetConfiguration`. Deploy the chart with `mirror=true` to enable the Alpine sidecar and verify that **both images** are pulled from the mirror.
