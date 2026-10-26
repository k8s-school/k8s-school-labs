---
title: 'Gateway API: canary release and A/B testing'
date: 2026-10-21T08:00:00+02:00
draft: false
weight: 153
tags: ["kubernetes", "Gateway API", "canary", "A/B testing", "OpenShift"]
---

## Objective

The [Gateway API](https://gateway-api.sigs.k8s.io/) is the successor of `Ingress`: traffic splitting and header-based routing are part of the standard API, with no controller-specific annotation. In this lab you will:

- Expose an application with a `Gateway` and an `HTTPRoute`
- Run a canary release, by sending a percentage of the traffic to a new version
- Run an A/B test, by routing the requests on an HTTP header

Complete this lab in 45 minutes.

## Prerequisites

- A Kubernetes cluster (kind is fine), version 1.31 or later, with `kubectl` and `helm`: older API servers reject the Gateway API CRDs installed by Envoy Gateway (`undeclared reference to 'isIP'`)
- The slides `D_08_openshift_ingress-gateway.pdf`, section *Gateway API*

| `Ingress` | Gateway API | Managed by |
|---|---|---|
| `IngressClass` | `GatewayClass`: the controller implementation | cluster admin |
| ingress controller Service, `spec.tls` | `Gateway`: listeners (ports, hostnames, TLS) | cluster admin |
| `spec.rules` | `HTTPRoute`: routing rules and backends | application team |

## Setup

{{% notice info %}}
Trainer only, once per cluster, before the lab: run `./setup.sh` below. It installs the Envoy Gateway controller shared by all the trainees. Otherwise, trainees starting `setup.sh` at the same time install it concurrently, and Helm fails with `cannot re-use a name that is still in use`.
{{% /notice %}}

Install the [Envoy Gateway](https://gateway.envoyproxy.io/) controller (skipped if already installed), its `GatewayClass` `eg`, and version 1 of the application:

```bash
git clone https://github.com/k8s-school/demo-apigateway
cd demo-apigateway
./setup.sh

# setup.sh deploys the application in a namespace of your own
NS=gateway-$(whoami)
kubectl config set-context --current --namespace=$NS
kubectl get gatewayclass
kubectl get deployment,service
```

{{% notice note %}}
The Envoy Gateway controller and the `GatewayClass` `eg` are shared by all the trainees of the cluster: `setup.sh` only resets your own namespace.
The `GatewayClass` is configured to expose each `Gateway` with a `NodePort` Service, since kind has no cloud LoadBalancer: see `gatewayclass.yaml`.
{{% /notice %}}

## Exercise 1: expose the application

Create a `Gateway` `example-gateway` with an HTTP listener on port 80 for the host `hello-world.info`, and an `HTTPRoute` `example-httproute` which sends all the requests to the Service `web`. Then call the application.

{{%expand "Solution" %}}
```bash
cat <<EOF | kubectl apply -f -
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: example-gateway
spec:
  gatewayClassName: eg
  listeners:
    - name: http
      protocol: HTTP
      port: 80
      hostname: hello-world.info
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: example-httproute
spec:
  parentRefs:
    - name: example-gateway
  hostnames:
    - hello-world.info
  rules:
    - backendRefs:
        - name: web
          port: 8080
EOF
kubectl wait --for=condition=Programmed gateway/example-gateway --timeout=2m
kubectl get gateway,httproute
```

The Envoy Gateway controller creates an Envoy Deployment and its Service for the `Gateway`, in the namespace `envoy-gateway-system`:

```bash
# Each trainee has a Gateway named example-gateway: select yours by namespace too
GW_LABELS=gateway.envoyproxy.io/owning-gateway-namespace=$NS,gateway.envoyproxy.io/owning-gateway-name=example-gateway
kubectl get pods,services -n envoy-gateway-system -l $GW_LABELS

NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[0].address}')
NODE_PORT=$(kubectl get svc -n envoy-gateway-system -l $GW_LABELS \
  -o jsonpath='{.items[0].spec.ports[?(@.port==80)].nodePort}')
# --resolve sends the request to the node, with the Host header the Gateway expects
alias curl-gw="curl -s --resolve hello-world.info:$NODE_PORT:$NODE_IP"
curl-gw hello-world.info:$NODE_PORT
# Hello, world!
# Version: 1.0.0
```
{{% /expand%}}

## Exercise 2: canary release

A **canary release** sends a small share of the real traffic to a new version, checks that it behaves well, then increases the share step by step until the new version gets all the traffic. If something goes wrong, the traffic goes back to the old version: only a few users were exposed.

1. Deploy version 2 of the application: Deployment and Service `web-v2`, image `gcr.io/google-samples/hello-app:2.0`, port 8080
2. Update the `HTTPRoute` to send 10% of the traffic to `web-v2`
3. Send 100 requests and count the answers of each version
4. Promote the canary: 50%, then 100% of the traffic to `web-v2`

{{%expand "Solution" %}}
```bash
kubectl create deployment web-v2 --image=gcr.io/google-samples/hello-app:2.0
kubectl expose deployment web-v2 --port=8080
kubectl wait --for=condition=available deployment web-v2

kubectl apply -f httproute-canary.yaml
sleep 5
cat httproute-canary.yaml

for i in $(seq 100); do curl-gw hello-world.info:$NODE_PORT | grep Version; done | sort | uniq -c
#      89 Version: 1.0.0
#      11 Version: 2.0.0
```

The `weight` of each `backendRef` sets its share of the traffic: 90/(90+10).
The controller pushes the new configuration to Envoy within a few seconds, hence the `sleep` before counting.
Without the Gateway API, a canary puts two Deployments behind one Service: the Service balances between pods, so the share is set by the number of replicas (9 pods of v1 and 1 pod of v2 for 10%). With the Gateway API, the share does **not** depend on the number of replicas: 1 pod of `web-v2` can receive 50% of the traffic.

Promote the canary:

```bash
kubectl patch httproute example-httproute --type=json \
  -p '[{"op": "replace", "path": "/spec/rules/0/backendRefs/0/weight", "value": 50},
       {"op": "replace", "path": "/spec/rules/0/backendRefs/1/weight", "value": 50}]'
sleep 5
for i in $(seq 100); do curl-gw hello-world.info:$NODE_PORT | grep Version; done | sort | uniq -c

kubectl patch httproute example-httproute --type=json \
  -p '[{"op": "replace", "path": "/spec/rules/0/backendRefs/0/weight", "value": 0},
       {"op": "replace", "path": "/spec/rules/0/backendRefs/1/weight", "value": 100}]'
sleep 5
for i in $(seq 100); do curl-gw hello-world.info:$NODE_PORT | grep Version; done | sort | uniq -c
#     100 Version: 2.0.0
```

A weight of 0 keeps the backend in the `HTTPRoute` without sending it any traffic: rolling back is a single patch.
{{% /expand%}}

## Exercise 3: A/B testing

A canary picks the users at random. An A/B test chooses them: here, the requests with the header `x-version: v2`, for example the beta testers, go to version 2.

Update the `HTTPRoute` so that:

- the requests with the header `x-version: v2` go to `web-v2`
- all the other requests go to `web`

{{%expand "Solution" %}}
```bash
kubectl apply -f httproute-ab.yaml
sleep 5
cat httproute-ab.yaml

for i in $(seq 20); do curl-gw hello-world.info:$NODE_PORT | grep Version; done | sort | uniq -c
#      20 Version: 1.0.0
for i in $(seq 20); do curl-gw -H "x-version: v2" hello-world.info:$NODE_PORT | grep Version; done | sort | uniq -c
#      20 Version: 2.0.0
```

When several rules match a request, the rule with the most specific match wins, whatever the order of the rules: the header rule takes precedence over the rule without match.
An `HTTPRoute` can also match on the path, the method or a query parameter, and combine matches with weights.
{{% /expand%}}

## On OpenShift

### Same with an OpenShift Route

A `Route` can split the traffic by weight between Services, with `spec.alternateBackends`. Deploy both versions in a project of your own:

```bash
oc new-project gateway-$(whoami)
oc create deployment web --image=gcr.io/google-samples/hello-app:1.0
oc expose deployment web --port=8080
oc create deployment web-v2 --image=gcr.io/google-samples/hello-app:2.0
oc expose deployment web-v2 --port=8080
oc wait --for=condition=available deployment web web-v2

oc expose service web
oc set route-backends web web=90 web-v2=10
oc set route-backends web
# NAME       KIND     TO      WEIGHT
# routes/web Service  web     90 (90%)
# routes/web Service  web-v2  10 (10%)

HOST=$(oc get route web -o jsonpath='{.spec.host}')
sleep 5
for i in $(seq 100); do curl -s http://$HOST | grep Version; done | sort | uniq -c
#      91 Version: 1.0.0
#       9 Version: 2.0.0
```

The HAProxy router reloads its configuration a few seconds after the change, hence the `sleep`. It also sets a session cookie: a browser sticks to one version, whereas `curl` without cookies shows the split.

A `Route` has no header-based routing: for A/B testing, use the Gateway API.

### Gateway API on OpenShift

From OpenShift 4.19, the Ingress Operator manages the Gateway API, with an Envoy-based implementation (OpenShift Service Mesh):

- The cluster admin creates a `GatewayClass` with `controllerName: openshift.io/gateway-controller/v1`, and a `Gateway` in the namespace `openshift-ingress`
- Each application team creates its `HTTPRoute`s in its own namespace: they are the same as in this lab

The Gateway API does not create `Route`s: the `Gateway` has its own Envoy proxy and LoadBalancer Service, next to the HAProxy router.

## Clean up

```bash
kubectl delete namespace gateway-$(whoami)
oc delete project gateway-$(whoami)
```

## Automated run

The solution of this lab is validated by [setup.sh](https://github.com/k8s-school/demo-apigateway/blob/main/setup.sh): `./setup.sh -a` runs the canary release and the A/B test, and checks the traffic split.
