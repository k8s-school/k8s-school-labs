---
marp: true
theme: custom-theme
paginate: true
backgroundColor: #ffffff
---

# Kubernetes Ingress, OpenShift Routes & API Gateway

<img src="images/logo.svg" alt="K8s School Logo" width="50%">

---

## Overview: Traffic Ingress in Kubernetes Ecosystems

Three generations of solutions for exposing services to the outside world:

| Technology | Origin | Status |
|---|---|---|
| **OpenShift Route** | Red Hat (2014) | Legacy, being replaced |
| **Kubernetes Ingress** | Kubernetes core (2015) | Stable, widely used |
| **Gateway API** | Kubernetes SIG-Network (2022) | Future standard |

> **Key Trend**: OpenShift is migrating from Routes to the Gateway API. Red Hat contributed the Gateway API implementation via the Ingress Node Firewall and OpenShift Service Mesh projects.

---

## OpenShift Route — Concepts

### What is an OpenShift Route?

A **Route** is an OpenShift-specific resource (not part of Kubernetes core) that exposes a Service externally via a hostname.

**Architecture**:

```
Internet ──▶ HAProxy Router (OpenShift) ──▶ Service ──▶ Pods
                    │
              (hostname matching,
               TLS termination,
               weight-based split)
```

- **Router**: An HAProxy-based component deployed as a DaemonSet on infra nodes
- **Namespace-scoped**: Routes live within a project (namespace)
- **TLS modes**: `edge`, `passthrough`, `re-encrypt`
- **Traffic Splitting**: Native `alternateBackends` for A/B or canary deployments

---

## OpenShift Route — YAML Example

```yaml
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: my-app-route
  namespace: production
spec:
  host: myapp.apps.cluster.example.com
  to:
    kind: Service
    name: my-app-service
    weight: 90
  alternateBackends:
  - kind: Service
    name: my-app-canary
    weight: 10
  port:
    targetPort: 8080
  tls:
    termination: edge
    insecureEdgeTerminationPolicy: Redirect
    certificate: |
      -----BEGIN CERTIFICATE-----
      ...
    key: |
      -----BEGIN PRIVATE KEY-----
      ...
```

> **Note**: The `host` field is auto-generated if omitted, using the pattern `<route-name>-<namespace>.<apps-domain>`.

---

## Kubernetes Ingress — Concepts

### What is a Kubernetes Ingress?

**Ingress** is a native Kubernetes API resource that manages external HTTP/HTTPS access to Services based on rules (host, path).

**Architecture**:

```
Internet ──▶ LoadBalancer (cloud) ──▶ Ingress Controller ──▶ Service ──▶ Pods
                                          │
                                   (nginx, traefik,
                                    haproxy, AWS ALB...)
```

- **Controller-agnostic**: The `Ingress` resource is a spec; the implementation is pluggable via **IngressClass**
- **HTTP/HTTPS only**: No TCP/UDP routing natively (requires controller-specific annotations)
- **Annotations-heavy**: Advanced features (rate limiting, auth, rewrites) use implementation-specific annotations
- **Limited expressiveness**: Path/host matching only; no traffic splitting, header routing, or retries in core spec

---

## Kubernetes Ingress — YAML Example

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-app-ingress
  namespace: production
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - myapp.example.com
    secretRef:
      name: myapp-tls-secret
  rules:
  - host: myapp.example.com
    http:
      paths:
      - path: /api
        pathType: Prefix
        backend:
          service:
            name: api-service
            port:
              number: 8080
      - path: /
        pathType: Prefix
        backend:
          service:
            name: frontend-service
            port:
              number: 80
```

> **⚠️ Limitation**: Traffic splitting, retries, circuit breaking, and header-based routing require controller-specific annotations — there is no standard.

---

## Gateway API — Concepts

### What is the Gateway API?

The **Gateway API** is the next-generation Kubernetes networking API designed to replace both Ingress and OpenShift Routes. It is **role-oriented**, **expressive**, and **extensible**.

**Architecture**:

```
Internet
   │
   ▼
GatewayClass         ← Cluster Admin (defines the implementation)
   │
   ▼
Gateway              ← Infrastructure Team (defines listeners/ports/TLS)
   │
   ▼
HTTPRoute / TCPRoute ← Developer (defines routing rules per app)
   │
   ▼
Service ──▶ Pods
```

- **Role separation**: Three distinct resources map to three organizational roles
- **Expressive routing**: Header matching, traffic weighting, redirects, and rewrites are first-class
- **Multi-protocol**: HTTP, HTTPS, TCP, TLS, GRPC routes
- **Portable**: Annotations no longer needed for advanced features

---

## Gateway API — Resource Model

### The Three Core Resources

| Resource | Owner | Responsibility |
|---|---|---|
| `GatewayClass` | Cluster Admin | Selects the controller implementation (e.g., `nginx`, `istio`, `envoy`) |
| `Gateway` | Platform Team | Defines entry points: listeners, ports, TLS certificates |
| `HTTPRoute` | Developer | Defines routing rules: hosts, paths, headers, weights |

### Key Advantages over Ingress

- **No more annotation sprawl**: Advanced features are in the spec, not annotations
- **Traffic splitting**: Native `weight` field on `backendRefs`
- **Header manipulation**: Add/remove/modify request/response headers
- **Cross-namespace routing**: `HTTPRoute` in namespace A can target a `Gateway` in namespace B (with `ReferenceGrant`)

---

## Gateway API — YAML Example (1/2): GatewayClass & Gateway

```yaml
# Cluster Admin: defines the implementation
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: envoy-gateway
spec:
  controllerName: gateway.envoyproxy.io/gatewayclass-controller

---
# Platform Team: defines the entry point
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: prod-gateway
  namespace: infra
spec:
  gatewayClassName: envoy-gateway
  listeners:
  - name: https
    port: 443
    protocol: HTTPS
    tls:
      mode: Terminate
      certificateRefs:
      - name: wildcard-tls-secret
        namespace: infra
    allowedRoutes:
      namespaces:
        from: All
```

---

## Gateway API — YAML Example (2/2): HTTPRoute with Traffic Splitting

```yaml
# Developer: defines routing rules for their application
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: my-app-route
  namespace: production
spec:
  parentRefs:
  - name: prod-gateway
    namespace: infra
  hostnames:
  - "myapp.example.com"
  rules:
  # Canary: 10% traffic to v2
  - matches:
    - path:
        type: PathPrefix
        value: /api
    backendRefs:
    - name: api-service-v1
      port: 8080
      weight: 90
    - name: api-service-v2
      port: 8080
      weight: 10
  # Header-based routing
  - matches:
    - headers:
      - name: X-Beta-User
        value: "true"
    backendRefs:
    - name: api-service-v2
      port: 8080
```

---

## OpenShift Migration: Routes → Gateway API

### Why OpenShift is Moving to Gateway API

Red Hat is actively migrating OpenShift's ingress stack from the proprietary `Route` resource to the standard Gateway API:

- **Standardization**: Avoid vendor lock-in; align with the upstream Kubernetes ecosystem
- **OpenShift Service Mesh v3**: Built on **Istio** + Gateway API (replaces Routes for mesh traffic)
- **OpenShift Router deprecation path**: Routes will remain for backward compatibility but new features target Gateway API

### Migration Timeline

```
OpenShift 4.x (current) ──▶ Routes + Ingress (both supported)
                         ──▶ Gateway API via OLM operator (tech preview)
OpenShift 4.16+         ──▶ Gateway API promoted to GA
OpenShift future        ──▶ Routes deprecated, Gateway API default
```

---

## Migration: Route → HTTPRoute Equivalence

### OpenShift Route (legacy)

```yaml
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: my-app
spec:
  host: myapp.apps.example.com
  to:
    kind: Service
    name: my-app-service
    weight: 100
  tls:
    termination: edge
```

### Equivalent HTTPRoute (Gateway API)

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: my-app
spec:
  parentRefs:
  - name: openshift-gateway
    namespace: openshift-ingress
  hostnames: ["myapp.apps.example.com"]
  rules:
  - backendRefs:
    - name: my-app-service
      port: 8080
```

---

## Comparison Summary

| Feature | OpenShift Route | Kubernetes Ingress | Gateway API |
|---|---|---|---|
| **Scope** | OpenShift only | All Kubernetes | All Kubernetes |
| **API group** | `route.openshift.io` | `networking.k8s.io` | `gateway.networking.k8s.io` |
| **Role separation** | No | No | Yes (3 resources) |
| **Traffic splitting** | Yes (native) | Annotation-based | Yes (native) |
| **TCP/UDP routing** | Passthrough only | No (core spec) | Yes (TCPRoute) |
| **Header routing** | Limited | Annotation-based | Yes (native) |
| **gRPC support** | No | No | Yes (GRPCRoute) |
| **Portability** | None | Medium | High |
| **Maturity** | Stable (legacy) | Stable | GA (v1.0, 2023) |
| **Future** | Deprecated | Maintained | **Recommended** |

---

## Summary

### Key Takeaways

- **OpenShift Route**: Powerful but proprietary. TLS modes (`edge`, `passthrough`, `re-encrypt`) and native traffic splitting. Being superseded by Gateway API in OpenShift 4.16+.

- **Kubernetes Ingress**: The current standard, widely supported but limited. Relies on controller-specific annotations for advanced features, leading to portability issues between implementations.

- **Gateway API**: The future of Kubernetes ingress. Role-oriented design separates concerns between cluster admins, platform teams, and developers. Expressive, portable, and multi-protocol.

### Recommended Path

> For new deployments, use the **Gateway API**. For OpenShift, follow the migration from `Route` to `HTTPRoute`. For existing Ingress users, plan a migration — the Gateway API has a well-documented [migration guide](https://gateway-api.sigs.k8s.io/guides/migrating-from-ingress/).
