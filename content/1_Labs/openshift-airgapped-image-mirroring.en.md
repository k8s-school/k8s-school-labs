---
title: 'OpenShift Airgapped: Mirroring Container Images'
date: 2026-06-08T14:15:26+10:00
draft: false
weight: 153
tags: ["OpenShift", "Helm", "Airgapped", "Registry", "Mirror"]
---

**Author:** Fabrice JAMMES ([LinkedIn](https://www.linkedin.com/in/fabrice-jammes-5b29b042/)).
**Duration:** 25-35 minutes

## Objective

Clusters running in restricted networks ("airgapped") cannot pull images directly from the internet (i.e. `docker.io`). You must mirror the images you need into a registry the cluster *can* reach, and then make the cluster use that mirror.

There are two fundamentally different ways to achieve this:
- **A. Cluster-wide transparent redirection** — configure OpenShift itself (`ImageTagMirrorSet`) to silently redirect every `docker.io` pull to your local mirror. Charts and Deployments stay untouched.
- **B. Explicit reference** — point each chart/Deployment directly at the mirror registry (`image.registry=...`). No cluster-level redirection is configured.

In this guided lab you'll deploy the *same* nginx chart both ways, observe how the resulting Pods differ, and weigh the trade-offs of each approach.

## Prerequisites

- A local clone of [`openshift-advanced`](https://github.com/k8s-school/openshift-advanced), with `openshift-advanced/labs` as your working directory (`cd openshift-advanced/labs`) — every relative path below is relative to it
- An OpenShift cluster with cluster-admin rights (`oc`/`kubectl` configured) — both approaches below require patching `image.config.openshift.io/cluster`
- `helm` v3+, `skopeo`, and a container engine able to run a local registry (e.g. `podman run registry:2`)
- The `nginx-chart` used in the [Helm on OpenShift migration lab](helm-openshift-migration.en.md) — this lab reuses its OpenShift-compatible values (`nginx-values-v2.yaml`, port 8080, non-root `securityContext`) so that the only variable left is *where the image comes from*

## Pre-requisite — start a local mirror registry and copy the image into it

> **WARNING — do not start the local registry, this has been performed as a pre-requisite**
>
> `local-registry` is a single container running on the **host**, not inside the cluster — it's shared infrastructure for the *whole* lab: both Approach A and Approach B mirror their images into this very same instance, and `LOCAL_REGISTRY` is reused everywhere below. Don't recreate it. Check first whether it's already running and reachable:
>
> ```bash
> curl -s http://localhost:5000/v2/_catalog
> ```
>

Do not run the commands below

```bash
NGINX_VERSION="1.25.3"

# Run a local registry reachable from the cluster (adapt HOST_IP to your network)
HOST_IP=$(ip -4 addr show virbr0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -1)
REGISTRY_PORT=5000
LOCAL_REGISTRY="${HOST_IP}:$REGISTRY_PORT"

podman run -d --name local-registry -p $REGISTRY_PORT:$REGISTRY_PORT \
    -e REGISTRY_STORAGE_DELETE_ENABLED=true \
    registry:2

# Allow the cluster nodes to pull over plain HTTP from this mirror
oc patch image.config.openshift.io/cluster --type=merge \
    -p "{\"spec\":{\"registrySources\":{\"insecureRegistries\":[\"$LOCAL_REGISTRY\"]}}}"

oc wait machineconfigpool/worker --for=condition=Updated --timeout=300s
```

**Question:** Why does patching `image.config.openshift.io/cluster` require waiting on a `MachineConfigPool`?

{{%expand "Answer" %}}
The list of insecure/mirror registries isn't just an API object — it has to be written to `/etc/containers/registries.conf.d/` on **every node** (use `oc debug` to check it), because that's what the container runtime (CRI-O) reads when pulling images. OpenShift's Machine Config Operator turns the `image.config.openshift.io/cluster` change into a `MachineConfig`, rolls it out to the `worker` (and `master`) `MachineConfigPool`s, and — in a real multi-node cluster — drains and reboots each node one at a time to apply it. `oc wait machineconfigpool/worker --for=condition=Updated` blocks until that rollout is finished. This is also why such a change is **disruptive**: plan it like any node-level maintenance operation, not like a simple API patch.

You can verify the configuration was applied at two levels:

**1. MachineConfig API objects** — inspect the `MachineConfig` generated from `image.config.openshift.io/cluster`:

```bash
oc get machineconfigpool/worker -o yaml
oc get machineconfig
oc get machineconfig 99-worker-generated-registries -o yaml
# the file contents are base64-encoded in the YAML — decode them:
oc get machineconfig 99-worker-generated-registries -o json | \
    jq -r '.spec.config.storage.files[].contents.source' | \
    sed 's|data:.*base64,||' | base64 -d
```

**2. On the node itself** — confirm the files CRI-O actually reads:

```bash
WORKER=$(oc get nodes -l node-role.kubernetes.io/worker -o jsonpath='{.items[0].metadata.name}')
oc debug node/$WORKER -- chroot /host cat /etc/containers/registries.conf
```

The `99-worker-generated-registries` MachineConfig is the exact content the MachineConfig Operator writes to those files on every node.
{{% /expand%}}

## Approach A — Transparent mirroring with `ImageTagMirrorSet`

Mirror the image **preserving Docker Hub's implicit `library/` namespace** — this matters, see the question below:

```bash
NGINX_VERSION="1.25.3"
skopeo copy \
    "docker://docker.io/nginx:$NGINX_VERSION" \
    "docker://localhost:5000/library/nginx:$NGINX_VERSION" \
    --dest-tls-verify=false
```

Then tell OpenShift to redirect every `docker.io` pull to your mirror:

```bash
HOST_IP=$(ip -4 addr show virbr0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -1)

cat <<EOF | kubectl apply -f -
apiVersion: config.openshift.io/v1
kind: ImageTagMirrorSet
metadata:
  name: local-registry-mirror
spec:
  imageTagMirrors:
  - mirrors:
    - ${HOST_IP}:5000
    source: docker.io
    mirrorSourcePolicy: NeverContactSource
EOF

WORKER=$(oc get nodes -l node-role.kubernetes.io/worker -o jsonpath='{.items[0].metadata.name}')
until oc debug node/$WORKER -- chroot /host cat /etc/containers/registries.conf | grep -q docker.io; do
    sleep 5
done
```

> **Recommendation**: don't use `oc wait machineconfigpool/worker --for=condition=Updated` here. The `Updated` condition can stay `True` for a short moment after the `kubectl apply`, while the MachineConfig Operator detects the new `ImageTagMirrorSet` and kicks off a new rollout — `oc wait` would then return immediately, before the rollout even starts. The loop above polls `/etc/containers/registries.conf` on the node directly until the `docker.io` rule shows up. Without this synchronization, a learner in a hurry could run `helm install` before the mirror rule is actually live on the node.

Now deploy the chart **without changing anything about the image** — same values file as in the [Helm migration lab](helm-openshift-migration.en.md):

```bash
oc new-project airgapped-$USER

helm install nginx-mirror ./nginx-chart \
    --namespace airgapped-$USER \
    --values 6_helm_migration/manifests/nginx-values-v2.yaml \
    --set image.pullPolicy=Always \
    --wait --timeout 120s
```

**Question:** Look at the Pod's image reference (`kubectl get pod -l app=nginx-mirror -o jsonpath='{.items[0].spec.containers[0].image}'`) and at `kubectl describe pod -l app=nginx-mirror` (Events). Where did the image actually come from — `docker.io` or your mirror? How can you tell?

{{%expand "Answer" %}}
The Pod's image reference is **unchanged** — still `nginx:1.25.3`, exactly as the chart's default `values.yaml` declares it (`image.repository: nginx`, no registry):

```bash
kubectl get pod -l app=nginx-mirror -o jsonpath='{.items[0].spec.containers[0].image}'
# nginx:1.25.3
```

The pull event doesn't reveal the source registry either:

```bash
kubectl describe pod -l app=nginx-mirror | grep -A6 Events:
# Normal  Pulling  Pulling image "nginx:1.25.3"
# Normal  Pulled   Successfully pulled image "nginx:1.25.3" in 10.919s ... Image size: 190871508 bytes
```

Even **`Image ID`** doesn't help — it still shows the canonical `docker.io` reference:

```bash
kubectl get pod -l app=nginx-mirror -o jsonpath='{.items[0].status.containerStatuses[0].imageID}'
# docker.io/library/nginx@sha256:b41c95c4...
```

**You can't tell — and that's the point.** The `ImageTagMirrorSet` rule (`source: docker.io → mirrors: [$LOCAL_REGISTRY]`) made CRI-O silently rewrite `docker.io/library/nginx:1.25.3` to `$LOCAL_REGISTRY/library/nginx:1.25.3` *before* pulling, but nothing visible to `kubectl` reports that rewrite back. The only way to confirm the redirect is active is at the node level — the `registries.conf` check from the previous step. (The bonus exercise below shows a case where the redirect *does* leave a visible trace: when the mirror is missing the image.)

**This is also why the `library/` namespace mattered**: Docker Hub "official" images like `nginx` actually live at `docker.io/library/nginx`. The mirror rule rewrites the *whole* `docker.io/...` path, so your local copy has to sit at the matching path (`$LOCAL_REGISTRY/library/nginx`) — mirror it to `$LOCAL_REGISTRY/nginx` instead and the redirected pull would 404.
{{% /expand%}}

### Bonus — what happens when the mirror doesn't have the image?

`mirrorSourcePolicy: NeverContactSource` means CRI-O will **only** look at `$LOCAL_REGISTRY` for any `docker.io` image — including ones you haven't mirrored yet. Try it with an image you haven't copied anywhere:

```bash
oc run ubuntu --image=ubuntu -it --restart=Never -- bash
```

This hangs trying to attach (Ctrl+C to get back your prompt). Check why:

```bash
kubectl describe pod ubuntu | grep -A6 Events:
```

**Question:** What does the pull error reference — `docker.io/library/ubuntu` or your mirror? What does this tell you, compared to the previous question?

{{%expand "Answer" %}}
The error references **your mirror**, not `docker.io`:

```
Failed to pull image "ubuntu": ... 192.168.122.1:5000/library/ubuntu:latest: manifest unknown
```

Unlike a *successful* pull (where neither `Image` nor `Image ID` reveal the redirect — see the previous question), a *failed* pull error message leaks the rewritten reference, because that's the URL CRI-O actually tried and failed to reach. `NeverContactSource` means it never falls back to `docker.io`, so the chart "looks normal" right up until it doesn't.

Now mirror the missing image, preserving the `library/` namespace, and retry:

```bash
skopeo copy \
    "docker://docker.io/ubuntu:latest" \
    "docker://localhost:5000/library/ubuntu:latest" \
    --dest-tls-verify=false

oc delete pod ubuntu
oc run ubuntu --image=ubuntu -it --rm --restart=Never -- bash
```

This time the pull succeeds and you get a shell.
{{% /expand%}}

## Approach B — Explicit registry reference in the chart values

This time, mirror the image to a path **of your own choosing** (no `library/` needed — you're not relying on any redirect rule):

```bash
skopeo copy \
    "docker://docker.io/nginx:$NGINX_VERSION" \
    "docker://localhost:5000/nginx:$NGINX_VERSION" \
    --dest-tls-verify=false
```

Deploy the *same* chart and values, but this time tell Helm explicitly which registry to use — via the chart's `image.registry` value:

```bash
helm install nginx-explicit ./nginx-chart \
    --namespace airgapped-$USER \
    --values 6_helm_migration/manifests/nginx-values-v2.yaml \
    --set image.registry="$LOCAL_REGISTRY" \
    --set image.pullPolicy=IfNotPresent \
    --wait --timeout 120s
```

**Question:** What does the Pod's image reference look like now? Does the node actually pull anything?

{{%expand "Answer" %}}
This time the Pod's image reference **explicitly** shows the local registry — no redirection magic involved, what you see is what gets pulled:

```bash
kubectl get pod -l app=nginx-explicit -o jsonpath='{.items[0].spec.containers[0].image}'
# 192.168.122.1:5000/nginx:1.25.3
```

And the kubelet doesn't even pull anything:

```bash
kubectl describe pod -l app=nginx-explicit | grep -A5 Events:
# Normal  Pulled  Container image "192.168.122.1:5000/nginx:1.25.3" already present on machine
```

"Already present" even though this exact reference was never pulled before! Container image storage is **content-addressed**: every layer is identified by its SHA-256 digest, not by the tag/registry path used to fetch it. Since `$LOCAL_REGISTRY/nginx:1.25.3` and `$LOCAL_REGISTRY/library/nginx:1.25.3` were mirrored from the very same upstream image, their layers are byte-for-byte identical to the ones already cached on the node from Approach A — so CRI-O just reuses them under the new name instead of downloading anything again.
{{% /expand%}}

## Comparing the two approaches

### Observing the difference with `helm get values` and `kubectl describe`

Run both commands on each release and compare the output:

```bash
# Approach A — nginx-mirror
helm get values nginx-mirror -n airgapped-$USER
kubectl describe pod -l app=nginx-mirror -n airgapped-$USER | grep -E "^\s+Image"

# Approach B — nginx-explicit
helm get values nginx-explicit -n airgapped-$USER
kubectl describe pod -l app=nginx-explicit -n airgapped-$USER | grep -E "^\s+Image"
```

**Approach A — `helm get values` does not mention `image.registry`** (it was never set):

```yaml
image:
  pullPolicy: Always
```

And `kubectl describe` doesn't reveal anything either — both `Image` and `Image ID` still point to `docker.io`:

```
Image:          nginx:1.25.3
Image ID:       docker.io/library/nginx@sha256:b41c95c4...
```

**Approach B — `helm get values` explicitly shows the local registry**:

```yaml
image:
  pullPolicy: IfNotPresent
  registry: 192.168.122.1:5000
```

And `kubectl describe` is fully honest — both `Image` and `Image ID` point to the local registry:

```
Image:          192.168.122.1:5000/nginx:1.25.3
Image ID:       192.168.122.1:5000/nginx@sha256:a484...
```

**Key insight**: in Approach A, **nothing in the Pod spec or status reveals the redirect** — both `Image` and `Image ID` still reference `docker.io`, exactly as if the mirror didn't exist. The only way to confirm it's active is at the node level (`registries.conf`), or indirectly when the mirror is *missing* an image and the pull error references the mirror path (see the bonus exercise after Approach A). In Approach B, there is no ambiguity.

| | A — `ImageTagMirrorSet` (transparent) | B — explicit `image.registry` |
|---|---|---|
| Chart / Deployment changes | **None** — references stay `docker.io/...` | Every chart/values must reference the mirror |
| Cluster-level configuration | `ImageTagMirrorSet` + `insecureRegistries` patch (cluster-admin, `MachineConfigPool` rollout / node reboot) | `insecureRegistries` patch only (still cluster-admin + rollout) |
| Visibility | Image reference in the Pod spec is misleading (looks like `docker.io`, isn't) | Image reference is honest and explicit |
| Portability | Works for *any* image referencing `docker.io`, including third-party charts you don't control | Only works for images/charts you can configure yourself |
| Failure mode | `mirrorSourcePolicy: NeverContactSource` makes pulls fail hard if the mirror is missing the image — easy to overlook since the chart "looks normal" | A typo in `image.registry` fails immediately and visibly at deploy time |

## Cleanup

```bash
oc delete project airgapped-$USER
podman rm -f local-registry
```

## Key Takeaways

1. **Two strategies, one goal**: an `ImageTagMirrorSet`/`ImageDigestMirrorSet` redirects pulls *transparently* at the infrastructure level (no chart changes, but cluster-admin + node rollout required and the Pod spec becomes misleading); an explicit `image.registry` override is *honest* but pushes the airgapped concern into every chart you deploy.
2. **`docker.io` "official" images live under `library/`** — `nginx` really means `docker.io/library/nginx`. Forgetting this when mirroring for a tag/digest mirror set is a classic, silent failure mode (the redirected pull 404s).
3. **Patching `image.config.openshift.io/cluster` is a node-level, disruptive operation** — it flows through the Machine Config Operator and a `MachineConfigPool` rollout (rolling node reboot), not just an API object update. Always pair it with `oc wait machineconfigpool/<pool> --for=condition=Updated`.
4. **Container image storage is content-addressed**: identical layers are never re-pulled, no matter which tag or registry path was used to reference them — `kubectl describe pod` will tell you "already present on machine" even for a reference the node has never seen before.

## Reference / full solution

- Full demo scripts: [`ex1-airgapped-helm.sh`](https://github.com/k8s-school/openshift-advanced/blob/main/labs/11_airgapped/ex1-airgapped-helm.sh) (Approach A) and [`ex2-airgapped-helm-explicit-registry.sh`](https://github.com/k8s-school/openshift-advanced/blob/main/labs/11_airgapped/ex2-airgapped-helm-explicit-registry.sh) (Approach B)
- Mirror set manifest: [`image-tag-mirror-set.yaml`](https://github.com/k8s-school/openshift-advanced/blob/main/labs/11_airgapped/manifests/image-tag-mirror-set.yaml)
- Helm chart: [`nginx-chart`](https://github.com/k8s-school/openshift-advanced/tree/main/labs/nginx-chart) and OpenShift-compatible values [`nginx-values-v2.yaml`](https://github.com/k8s-school/openshift-advanced/blob/main/labs/6_helm_migration/manifests/nginx-values-v2.yaml)
