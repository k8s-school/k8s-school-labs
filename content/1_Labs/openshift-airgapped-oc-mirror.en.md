---
title: 'OpenShift Airgapped: Declarative Mirroring with oc-mirror v2'
date: 2026-06-10T18:00:00+10:00
draft: false
weight: 154
tags: ["OpenShift", "Helm", "Airgapped", "Registry", "Mirror", "oc-mirror"]
---

**Author:** Fabrice JAMMES ([LinkedIn](https://www.linkedin.com/in/fabrice-jammes-5b29b042/)).
**Duration:** 25-35 minutes

## Objective

In the [previous lab](openshift-airgapped-image-mirroring.en.md) you mirrored a single image with `skopeo copy` and hand-wrote an `ImageTagMirrorSet` to redirect `docker.io` pulls to it. That works, but it doesn't scale: every image needs its own `skopeo copy`, and the mirror-set YAML must be kept perfectly in sync with whatever you copied — get the `library/` namespace wrong and pulls 404.

`oc-mirror` (the **v2** plugin, GA since OpenShift 4.16) replaces both steps:

- A single declarative **`ImageSetConfiguration`** lists everything you need (individual images, operator catalogs, even whole OCP release payloads).
- One `oc-mirror ... --v2` invocation mirrors all of it in one pass.
- oc-mirror then **generates** the `ImageTagMirrorSet`/`ImageDigestMirrorSet` manifests for you, scoped to exactly what it mirrored — no manual YAML.

In this lab you'll mirror **two** images (nginx + alpine) in a single pass, apply the mirror set oc-mirror generates, and deploy the same nginx chart — this time with an Alpine sidecar — to confirm both images are transparently redirected.

## Prerequisites

- A local clone of [`openshift-advanced`](https://github.com/k8s-school/openshift-advanced), with `openshift-advanced/labs` as your working directory (`cd openshift-advanced/labs`) — every relative path below is relative to it
- An OpenShift cluster with cluster-admin rights (`oc`/`kubectl` configured) — applying mirror sets requires patching `image.config.openshift.io/cluster` (see the [previous lab](openshift-airgapped-image-mirroring.en.md) for why this is a node-level, disruptive operation)
- `helm` v3+, `envsubst`, and a container engine able to run a local registry (e.g. `podman run registry:2`)
- The **`oc-mirror` v2 plugin** matching your `oc` client version. Download `oc-mirror.tar.gz` from (https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/stable), extract it, and place the `oc-mirror` binary in your `PATH` (e.g. `/usr/local/bin`). Check it's wired up:

```bash
oc-mirror version --v2
```

> **Note:** as of OCP 4.21, `--v2` is **mandatory** — `oc-mirror v1` still exists behind `--v1` but is deprecated. Every command below passes `--v2` explicitly.

- The `nginx-chart` used in the [Helm on OpenShift migration lab](helm-openshift-migration.en.md), and its `mirror=true` option which adds an Alpine **sidecar** container — used here to prove that *both* images mirrored in a single `oc-mirror` pass get redirected

## Pre-requisite — local mirror registry and insecure-registry patch

> **WARNING — do not start the local registry, this has been performed as a pre-requisite**
>
> Same shared `local-registry` instance as the previous lab — check it's up before continuing:
>
> ```bash
> curl -s http://localhost:5000/v2/_catalog
> ```

Do not run the commands below

```bash
HOST_IP=$(ip -4 addr show virbr0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -1)
LOCAL_REGISTRY="${HOST_IP}:5000"

podman run -d --name local-registry -p 5000:5000 \
    -e REGISTRY_STORAGE_DELETE_ENABLED=true \
    registry:2

oc patch image.config.openshift.io/cluster --type=merge \
    -p "{\"spec\":{\"registrySources\":{\"insecureRegistries\":[\"$LOCAL_REGISTRY\"]}}}"

oc wait machineconfigpool/worker --for=condition=Updated --timeout=300s
```

## Step 1 — describe everything to mirror in one `ImageSetConfiguration`

```yaml
# manifests/imageset-config.yaml
kind: ImageSetConfiguration
apiVersion: mirror.openshift.io/v2alpha1
mirror:
  additionalImages:
  - name: docker.io/library/nginx:${NGINX_VERSION}
  - name: docker.io/library/alpine:${ALPINE_VERSION}
```

Render the placeholders and write it to `/tmp`:

```bash
# NOTE: Change image tags to your convenience to use different images from others trainess
# Image tag are available on docker hub: https://hub.docker.com/_/nginx
NGINX_VERSION="1.25.3"
ALPINE_VERSION="3.19"
export NGINX_VERSION ALPINE_VERSION
envsubst < $HOME/openshift-advanced/labs/11_airgapped/manifests/imageset-config.yaml > /tmp/imageset-config-$USER.yaml
```

**Question:** Both images are referenced as `docker.io/library/nginx` and `docker.io/library/alpine` — i.e. with the `library/` namespace spelled out. Why does that matter, given what you learned in the previous lab?

{{%expand "Answer" %}}
oc-mirror derives the `source:`/`mirrors:` paths of the mirror set it generates from the **paths it actually copied**. If you mirror `docker.io/library/nginx` and `docker.io/library/alpine`, the generated rule will redirect `docker.io/library` → `$LOCAL_REGISTRY/library` — which matches how `nginx` and `alpine` are referenced *implicitly* by Docker Hub "official image" conventions (and by the nginx chart's default `values.yaml`, and its sidecar). Had you mirrored `docker.io/nginx` (without `library/`), oc-mirror would generate a rule for `docker.io` (or a narrower/different path) that wouldn't match those implicit references, and pulls would 404 — the exact same `library/` pitfall as the previous lab, just shifted from "you write the wrong path in the mirror set" to "you write the wrong path in the `ImageSetConfiguration`".
{{% /expand%}}

## Step 2 — mirror everything in one pass

```bash
HOST_IP=$(ip -4 addr show virbr0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -1)
LOCAL_REGISTRY="${HOST_IP}:5000"
MIRROR_WORKSPACE="/tmp/oc-mirror-workspace-$USER"
mkdir -p "$MIRROR_WORKSPACE"

oc-mirror -c /tmp/imageset-config-$USER.yaml \
    --workspace "file://$MIRROR_WORKSPACE" \
    --dest-tls-verify=false \
    "docker://$LOCAL_REGISTRY" \
    --v2
```

This is the **mirrorToMirror** workflow: oc-mirror reads `docker.io/library/{nginx,alpine}`, pushes them straight to `$LOCAL_REGISTRY`, and uses `$MIRROR_WORKSPACE/working-dir` to keep its state and generated manifests. Output looks like:

```
🔀 workflow mode: mirrorToMirror
🕵  going to discover the necessary images...
🔍 collecting additional images...
🚀 Start copying the images...
📌 images to copy 2
Success copying docker.io/library/alpine:3.19 ➡️ <mirror_ip_address>:5000/library/
Success copying docker.io/library/nginx:1.25.3 ➡️ <mirror_ip_address>:5000/library/
=== Results ===
✓ 2 / 2 additional images mirrored successfully
📄 No images by digests were mirrored. Skipping IDMS generation.
📄 Generating ITMS file...
/tmp/oc-mirror-workspace/working-dir/cluster-resources/itms-oc-mirror.yaml file created
```

**Question:** The previous lab used `skopeo copy ... --dest-tls-verify=false` with one invocation per image. What two things does `oc-mirror --v2` do differently here, just from the flags and output above?

{{%expand "Answer" %}}
1. **One config, many images** — `additionalImages` can list as many images (or operator catalogs, or OCP releases) as you need; `oc-mirror` mirrors all of them in a single invocation, instead of one `skopeo copy` per image.
2. **`--dest-tls-verify=false` replaces `--dest-skip-tls`** — `oc-mirror` v1 used `--dest-skip-tls`; in v2 the flag is the standard `--dest-tls-verify` boolean (default `true`), set to `false` for our plain-HTTP local registry. (`--src-tls-verify` exists symmetrically for an insecure *source*.)

Also note `--v2` is **mandatory** here — running `oc-mirror` without `--v1`/`--v2` refuses to start.
{{% /expand%}}

## Step 3 — inspect the `ImageTagMirrorSet` oc-mirror generated for you

```bash
cat $MIRROR_WORKSPACE/working-dir/cluster-resources/itms-oc-mirror.yaml
```

```yaml
apiVersion: config.openshift.io/v1
kind: ImageTagMirrorSet
metadata:
  annotations:
    createdAt: Wednesday, 10-Jun-26 17:46:05 UTC
    createdBy: oc-mirror v2
    oc-mirror_version: 4.21.0-...
  name: itms-generic-0
spec:
  imageTagMirrors:
  - mirrors:
    - <mirror_ip_address>:5000/library
    source: docker.io/library
```

(your timestamps/version annotation will differ)

**Question:** Compare this generated `ImageTagMirrorSet` with the hand-written one from the previous lab (`source: docker.io`, `mirrors: [$LOCAL_REGISTRY]`, `mirrorSourcePolicy: NeverContactSource`). What two differences stand out, and what's the practical consequence of each?

{{%expand "Answer" %}}
1. **Narrower `source`**: `docker.io/library` instead of `docker.io`. The redirect now applies *only* to Docker Hub's official-image namespace — exactly what was mirrored. A chart referencing `docker.io/someorg/something` (not under `library/`) would be left alone, whereas the previous lab's broad `source: docker.io` rule would have redirected *that* too (and failed, since it was never mirrored).

2. **No `mirrorSourcePolicy`**: the field is omitted, which defaults to allowing fallback to the source registry (`AllowContactingSource`) — the *opposite* of the previous lab's `NeverContactSource`. In a real disconnected cluster (no route to `docker.io` at all) this fallback simply times out rather than failing fast — about the same outcome either way. In a *connected* lab cluster like this one, it's actually convenient: if you forget to mirror an image, the pull still succeeds (from `docker.io`) instead of hard-failing as in the previous lab's bonus exercise. If you need the previous lab's strict "never touch docker.io" guarantee, edit this file and add `mirrorSourcePolicy: NeverContactSource` before applying it.
{{% /expand%}}

## Step 4 — apply the generated mirror set

```bash
kubectl apply -f $MIRROR_WORKSPACE/working-dir/cluster-resources/itms-oc-mirror.yaml

WORKER=$(oc get nodes -l node-role.kubernetes.io/worker -o jsonpath='{.items[0].metadata.name}')
until oc debug node/$WORKER -- chroot /host cat /etc/containers/registries.conf | grep -q "docker.io/library"; do
    sleep 5
done
```

As in the previous lab, polling `registries.conf` directly is more reliable than `oc wait machineconfigpool/worker --for=condition=Updated`: applying a *new* `ImageTagMirrorSet` kicks off a fresh Machine Config Operator rollout, and `Updated` can briefly still read `True` from a previous rollout before the new one starts.

## Step 5 — deploy nginx + its Alpine sidecar, unchanged

```bash

oc new-project airgapped-oc-mirror-$USER

# WARNING run it in $HOME/openshift-advanced/labs
helm install nginx ./nginx-chart \
    --namespace airgapped-oc-mirror-$USER \
    --values 6_helm_migration/manifests/nginx-values-v2.yaml \
    --set image.pullPolicy=Always \
    --set sidecar.image.pullPolicy=Always \
    --set mirror=true \
    --set sidecar.image.tag=3.19 \
    --wait --timeout 120s
```

`mirror=true` adds a second container to the Pod — an `alpine:3.19` sidecar running `sleep infinity`. Like the nginx container, it has **no `image.registry` set**: its image reference is the implicit `docker.io/library/alpine:3.19`, which is exactly the path the `ImageTagMirrorSet` from Step 4 redirects to `$LOCAL_REGISTRY/library`.

## Step 6 — verify both images came from the mirror

```bash
kubectl get pod -l app=nginx \
    -o jsonpath='{range .items[0].spec.containers[*]}{.name}: {.image}{"\n"}{end}'
kubectl describe pod -l app=nginx | grep -A10 Events:

# WARNING: Do not run it, ask trainer which owns the registry.
podman logs local-registry 2>&1 | grep GET
```

**Question:** Neither `Image` nor the Events mention your local registry — same as Approach A in the previous lab. How do the `local-registry` logs prove both images were actually pulled from the mirror, not from `docker.io`?

{{%expand "Answer" %}}
The Pod spec is unchanged and unhelpful, exactly like the previous lab's Approach A:

```
nginx: nginx:1.25.3
alpine-sidecar: alpine:3.19
```

But `local-registry`'s access log shows `GET` requests for **both** repositories' manifests and blobs, with `oc-mirror`'s pushes earlier and the nodes' pulls later:

```
"GET /v2/library/nginx/manifests/1.25.3 HTTP/1.1" 200 ...
"GET /v2/library/alpine/manifests/3.19 HTTP/1.1" 200 ...
"GET /v2/library/nginx/blobs/sha256:... HTTP/1.1" 200 ...
"GET /v2/library/alpine/blobs/sha256:... HTTP/1.1" 200 ...
```

Two repositories appear in `/v2/_catalog` (`library/nginx`, `library/alpine`) — confirming a *single* `oc-mirror` invocation populated the mirror for *both* images that the chart needs, and the `ImageTagMirrorSet` from Step 4 redirected both transparently.
{{% /expand%}}

## Bonus — rerun oc-mirror: the local cache

Run the exact same command from Step 2 again:

```bash
time oc-mirror -c /tmp/imageset-config.yaml \
    --workspace "file://$MIRROR_WORKSPACE" \
    --dest-tls-verify=false \
    "docker://$LOCAL_REGISTRY" \
    --v2
```

**Question:** The output still says `images to copy 2` and `Success copying` for both — so nothing was skipped. Yet the second run finishes in roughly a third of the time of the first. Where did the time go the first time, and where is state kept?

{{%expand "Answer" %}}
oc-mirror keeps a **layer cache** under `~/.oc-mirror/.cache` (override with `--cache-dir`), independent of `--workspace`. The first run had to pull every layer of `nginx:1.25.3` and `alpine:3.19` from `docker.io`; the second run finds those layers already in the cache and only has to verify/push them to `$LOCAL_REGISTRY` (itself a no-op if the destination already has them, since image storage is content-addressed — same principle as Approach B in the previous lab).

This matters in practice when you **iterate** on an `ImageSetConfiguration` — e.g. adding a third image to `additionalImages` — or **retry after a partial failure**: oc-mirror won't re-download what it already has, only the new/missing pieces.
{{% /expand%}}

## Comparing to the previous lab

| | Skopeo + hand-written mirror set ([previous lab](openshift-airgapped-image-mirroring.en.md)) | `oc-mirror` v2 (this lab) |
|---|---|---|
| Mirroring command | One `skopeo copy` **per image** | One `oc-mirror ... --v2`, any number of images/catalogs |
| Mirror set manifest | Hand-written; must match what you copied | **Generated** from what was actually mirrored |
| Redirect scope | Whatever `source:`/`mirrors:` you typed (`docker.io`, broad) | Scoped to exactly the namespaces mirrored (`docker.io/library`) |
| `mirrorSourcePolicy` | Explicit choice (e.g. `NeverContactSource`) | Not set by oc-mirror — defaults to allowing fallback to source |
| Re-running | Re-copies everything every time | Local layer cache (`~/.oc-mirror/.cache`) skips unchanged downloads |
| Operator catalogs / OCP releases | Not supported by this approach | Same `ImageSetConfiguration` syntax, just add `operators:`/`platform:` |

## Cleanup

```bash
oc delete project airgapped-oc-mirror-$USER
kubectl delete imagetagmirrorset itms-generic-0
podman rm -f local-registry
rm -rf /tmp/oc-mirror-workspace /tmp/imageset-config.yaml
```

## Key Takeaways

1. **`oc-mirror --v2` is declarative and batched**: one `ImageSetConfiguration` describes everything to mirror, one command mirrors it all — no per-image `skopeo copy`.
2. **`--v2` is mandatory** on current `oc-mirror` clients, and `--dest-tls-verify=false` (a standard boolean flag) replaces the old v1-only `--dest-skip-tls`.
3. **oc-mirror generates the `ImageTagMirrorSet`/`ImageDigestMirrorSet` for you**, scoped to exactly the paths it mirrored — but it does **not** set `mirrorSourcePolicy`, so review the generated file (and add `NeverContactSource` yourself) if you need a hard guarantee against contacting the original source.
4. **A local layer cache (`~/.oc-mirror/.cache`) makes iteration cheap** — adding images to your `ImageSetConfiguration` or retrying a failed run doesn't re-download what's already cached.
5. The same `ImageSetConfiguration` mechanism is what scales this approach to **operator catalogs and full OCP release payloads** — the building block for a real disconnected-cluster mirror, not just a couple of test images.

## Reference / full solution

- Full demo script: [ex3-airgapped-oc-mirror.sh](https://github.com/k8s-school/openshift-advanced/blob/main/labs/11_airgapped/ex3-airgapped-oc-mirror.sh)
- ImageSetConfiguration: [imageset-config.yaml](https://github.com/k8s-school/openshift-advanced/blob/main/labs/11_airgapped/manifests/imageset-config.yaml)
- Helm chart: [nginx-chart](https://github.com/k8s-school/openshift-advanced/tree/main/labs/nginx-chart) (see `mirror`/`sidecar` values) and OpenShift-compatible values [nginx-values-v2.yaml](https://github.com/k8s-school/openshift-advanced/blob/main/labs/6_helm_migration/manifests/nginx-values-v2.yaml)
- Previous lab: [OpenShift Airgapped: Mirroring Container Images](openshift-airgapped-image-mirroring.en.md)
