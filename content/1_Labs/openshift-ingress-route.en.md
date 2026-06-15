---
title: 'OpenShift Networking: From Ingress to Route'
date: 2026-06-15T14:15:26+10:00
draft: false
weight: 156
tags: ["OpenShift", "Ingress", "Route", "Networking"]
---

**Author:** Fabrice JAMMES ([LinkedIn](https://www.linkedin.com/in/fabrice-jammes-5b29b042/)).
**Duration:** 20-30 minutes

## Objective

OpenShift predates the Kubernetes `Ingress` API by several years. Its native object for exposing HTTP(S) services is the **Route** (`route.openshift.io/v1`), handled by the HAProxy-based router. To stay compatible with portable Kubernetes manifests, OpenShift ships a controller — part of `openshift-controller-manager` / [`route-controller-manager`](https://github.com/openshift/route-controller-manager) — that watches every `Ingress` object cluster-wide and automatically creates a matching `Route` for it.

In this lab you'll deploy the same application behind progressively richer `Ingress` manifests and inspect the `Route` that OpenShift generates for each one. You'll learn:
- Which `Ingress` fields map to which `Route` fields
- How the `route.openshift.io/termination` annotation controls TLS termination
- Why `spec.tls.insecureEdgeTerminationPolicy: Redirect` appears even though you never asked for it

## Prerequisites

- An OpenShift cluster, logged in with `oc`/`kubectl`, with rights to create a project
- The `openshift-default` `IngressClass` (created by the cluster-ingress-operator on every OpenShift 4 cluster)

## Setup

```bash
NSAPP="ingress-route-$USER"
oc new-project "$NSAPP"

# Deploy a simple HTTP app, exactly like in the vanilla-Kubernetes Ingress lab
kubectl create deployment web -n "$NSAPP" --image=gcr.io/google-samples/hello-app:1.0
kubectl expose deployment web -n "$NSAPP" --port=8080
kubectl wait -n "$NSAPP" --for=condition=available deployment web
```

List the available `IngressClass`es:

```bash
oc get ingressclasses
```

```
NAME                CONTROLLER                       PARAMETERS   AGE
openshift-default   openshift.io/ingress-to-route     <none>       ...
```

`openshift-default` is the one handled by the **ingress-to-route controller** (`openshift.io/ingress-to-route`). Any `Ingress` whose `ingressClassName` points at a *different* controller — or at an `IngressClass` that doesn't exist — is silently **ignored**: no `Route` is created for it at all.

Compute the cluster's wildcard apps domain — you'll need it for the `Ingress` host:

```bash
APPS_DOMAIN=$(oc get ingresses.config.openshift.io cluster -o jsonpath='{.spec.domain}')
HOST="hello-world-$USER.$APPS_DOMAIN"
echo "$HOST"
# e.g. hello-world-alice.apps-crc.testing
```

## Exercise 1 — A plain, portable Ingress (no OpenShift annotations)

Create an `Ingress` with **no annotations at all** — the kind of manifest you'd write for any Kubernetes cluster:

```bash
cat <<EOF | kubectl apply -n "$NSAPP" -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: example-ingress
spec:
  ingressClassName: openshift-default
  rules:
    - host: $HOST
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: web
                port:
                  number: 8080
EOF
```

Look at what got created:

```bash
kubectl get -n "$NSAPP" ingress,route
```

```
NAME                                  CLASS               HOSTS                          ADDRESS   PORTS   AGE
ingress.networking.k8s.io/example-ingress   openshift-default   hello-world-alice.apps-crc.testing             3s

NAME                                            HOST/PORT                            PATH   SERVICES   PORT   TERMINATION   WILDCARD
route.route.openshift.io/example-ingress-xxxxx   hello-world-alice.apps-crc.testing          web        8080                 None
```

The controller generated a `Route` named `example-ingress-xxxxx` (your `Ingress` name plus a random 5-character suffix), **owned by your Ingress** (`ownerReferences`). Fetch its full spec:

```bash
ROUTE=$(kubectl get route -n "$NSAPP" -o jsonpath='{.items[0].metadata.name}')
kubectl get route -n "$NSAPP" "$ROUTE" -o yaml
```

```yaml
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: example-ingress-xxxxx
  namespace: ingress-route-alice
  ownerReferences:
    - apiVersion: networking.k8s.io/v1
      kind: Ingress
      name: example-ingress
      controller: true
spec:
  host: hello-world-alice.apps-crc.testing
  path: /
  to:
    kind: Service
    name: web
    weight: 100
  port:
    targetPort: 8080
  wildcardPolicy: None
```

**Question:** Match each field of the `Route`'s `spec` to the `Ingress` field it came from. Then try both:

```bash
curl http://$HOST
curl -k https://$HOST
```

What's the result of each command, and why?

{{%expand "Answer" %}}
| Route field | Comes from |
|---|---|
| `spec.host` | `Ingress.spec.rules[0].host` |
| `spec.path` | `Ingress.spec.rules[0].http.paths[0].path` |
| `spec.to.{kind,name}` | `Ingress.spec.rules[0].http.paths[0].backend.service.name` (always `kind: Service`) |
| `spec.port.targetPort` | `Ingress.spec.rules[0].http.paths[0].backend.service.port.number` |

`curl http://$HOST` succeeds — the router serves the `Route` on its insecure (HTTP) front-end:

```
Hello, world!
Version: 1.0.0
Hostname: web-...
```

`curl -k https://$HOST` does **not** return your application. Notice that `spec.tls` is **absent** from the `Route` — this `Ingress` declared no `spec.tls` block and no `route.openshift.io/termination` annotation, so the controller created a Route with `spec.tls: null`. A `Route` with no TLS config has **no entry at all** in the router's HTTPS/SNI map: HTTPS requests for this host never reach your Pod. You either get a TLS error, or the router's default 503 "Application is not available" page — never your `Hello, world!` response.

**Lesson:** unlike a generic ingress-nginx controller (which can terminate TLS for *every* host using a default certificate), OpenShift's ingress-to-route controller only enables TLS on the generated `Route` if the `Ingress` **explicitly asks for it**.
{{% /expand%}}

## Exercise 2 — Opting into TLS with `route.openshift.io/termination`

Add the OpenShift-specific annotation that tells the controller "terminate TLS at the router, edge-style":

```bash
kubectl annotate -n "$NSAPP" ingress example-ingress \
    route.openshift.io/termination=edge
```

Re-fetch the `Route`:

```bash
kubectl get route -n "$NSAPP" "$ROUTE" -o yaml
```

```yaml
spec:
  host: hello-world-alice.apps-crc.testing
  path: /
  to:
    kind: Service
    name: web
    weight: 100
  port:
    targetPort: 8080
  tls:
    termination: edge
    insecureEdgeTerminationPolicy: Redirect
  wildcardPolicy: None
```

Try both `curl`s again:

```bash
curl -k https://$HOST
curl -i http://$HOST
```

**Question:** `spec.tls.termination: edge` is no surprise — you asked for it. But where does `insecureEdgeTerminationPolicy: Redirect` come from? You never set anything like that on the `Ingress`.

{{%expand "Answer" %}}
`curl -k https://$HOST` now returns `Hello, world!` — TLS is terminated at the router using its **default wildcard certificate** (you didn't provide one, so `spec.tls.certificate`/`key` stay empty — that's exactly what `edge` with no secret means).

`curl -i http://$HOST` returns a redirect:

```
HTTP/1.1 302 Found
Location: https://hello-world-alice.apps-crc.testing/
```

`insecureEdgeTerminationPolicy: Redirect` is **hardcoded** by the ingress-to-route controller: as soon as it decides a `Route` needs a `tls` block at all (because of `route.openshift.io/termination`, or because `Ingress.spec.tls` references a valid secret for that host), it *always* sets `insecureEdgeTerminationPolicy: Redirect` — there is currently no `Ingress` annotation to get `Allow`/`None` instead. If you need a different `insecureEdgeTerminationPolicy`, you must edit the generated `Route` object directly (or manage your own `Route`, bypassing `Ingress` entirely).
{{% /expand%}}

## Going further — `passthrough` and `reencrypt`

`route.openshift.io/termination` accepts three values, mapping to the three `Route` TLS termination types:

| Annotation value | `spec.tls.termination` | Router behaviour |
|---|---|---|
| `edge` (or any unrecognized value, once TLS is enabled) | `edge` | Router decrypts TLS using its own (or the `Ingress`'s referenced) certificate; traffic to the Pod is plain HTTP |
| `passthrough` | `passthrough` | Router forwards the encrypted TCP stream untouched — **your Pod must terminate TLS itself**. No certificate is stored on the `Route` |
| `reencrypt` | `reencrypt` | Router decrypts, then re-encrypts towards the Pod using a CA certificate read from the secret named in `route.openshift.io/destination-ca-certificate-secret` |

For `edge`/`reencrypt`, an `Ingress.spec.tls` entry whose `hosts` matches the rule's host and whose `secretName` points at a valid `kubernetes.io/tls` secret is used to populate `spec.tls.certificate`/`key` on the `Route` — that's the **portable** way to ship a real certificate through an `Ingress` (instead of relying on the router's default wildcard certificate, as in Exercise 2).

## Cleanup

```bash
oc delete project "$NSAPP"
```

## Key Takeaways

1. **OpenShift runs an `Ingress` → `Route` controller** (`openshift.io/ingress-to-route`, the controller behind the `openshift-default` `IngressClass`): every `Ingress` rule/path becomes one `Route`, named `<ingress-name>-xxxxx` and owned by the `Ingress`. Write portable `networking.k8s.io/v1` manifests; OpenShift runs `Route`s underneath.
2. **TLS is opt-in.** A `Route` only gets a `spec.tls` block if the `Ingress` sets `route.openshift.io/termination: edge|reencrypt|passthrough`, or references a valid TLS secret via `spec.tls[].secretName` for that host. Otherwise `spec.tls` is `null` and the `Route` is HTTP-only — invisible to HTTPS clients, not just "insecure".
3. **`insecureEdgeTerminationPolicy: Redirect` is hardcoded** whenever TLS gets enabled on the generated `Route` — there's no `Ingress` annotation to request `Allow`/`None`; edit the `Route` directly if you need that.
4. **`kubectl get route <name> -o yaml`** (or `oc get route`) is your primary debugging tool when an `Ingress` "does nothing" on OpenShift — check whether a `Route` was created at all (`IngressClass` controller mismatch ⇒ none), and compare its `spec.tls` against what you expected.

## Reference / full solution

- Demo repository: [demo-nginx-controller](https://github.com/k8s-school/demo-nginx-controller)
  - [openshift-setup.sh](https://github.com/k8s-school/demo-nginx-controller/blob/main/openshift-setup.sh)
  - [example-ingress-openshift.yaml](https://github.com/k8s-school/demo-nginx-controller/blob/main/example-ingress-openshift.yaml)
- Controller source: [route-controller-manager](https://github.com/openshift/route-controller-manager) — `pkg/route/ingress/ingress.go` (conversion logic), `pkg/routecontroller/wellknown.go` (recognized annotations)
