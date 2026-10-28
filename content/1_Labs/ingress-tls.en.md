---
title: 'Ingress with TLS'
date: 2026-10-28T09:00:00+01:00
draft: false
weight: 76
tags: ["kubernetes", "Ingress", "TLS", "Traefik", "CKS"]
---

**Author:** Fabrice JAMMES ([LinkedIn](https://www.linkedin.com/in/fabrice-jammes-5b29b042/)).

## Objective

- Expose an application with an `Ingress`, over HTTPS
- Store a certificate and its key in a `Secret` of type `kubernetes.io/tls`
- Check which certificate the ingress controller serves, and disable plain HTTP

The CKS curriculum lists "Properly set up Ingress with TLS" in the *Cluster setup* domain.

## Setup

The cluster is shared by the trainees: the [Traefik](https://doc.traefik.io/traefik/) ingress controller is installed once for the whole cluster by the trainer. Do not install it yourself.

{{% notice info %}}
Trainer only, once per cluster, before the lab. kind has no cloud load balancer: Traefik is exposed with a `NodePort` Service.

<!-- ci-skip -->
```bash
# The shared cluster
kubectx kind-kind
helm upgrade --install traefik traefik \
  --repo https://traefik.github.io/charts --version 41.6.1 \
  --namespace traefik --create-namespace \
  --set service.type=NodePort
kubectl wait --for=condition=available deployment traefik -n traefik
```

<!-- ci-exec
# Test runs of several accounts at the same time: the namespace is the lock.
# kubectl create is atomic, so only the first run installs Traefik,
# the other ones wait for its deployment.
kubectx kind-kind
if kubectl create namespace traefik 2>/dev/null; then
  helm upgrade --install traefik traefik \
    --repo https://traefik.github.io/charts --version 41.6.1 \
    --namespace traefik --set service.type=NodePort
else
  timeout 300 sh -c 'until kubectl get deployment traefik -n traefik >/dev/null 2>&1; do sleep 2; done'
fi
kubectl wait --for=condition=available deployment traefik -n traefik --timeout=300s
-->

The [demo-ingress](https://github.com/k8s-school/demo-ingress) repository holds the same setup as a script, and a version for OpenShift.
{{% /notice %}}

Each trainee works in a namespace of their own, with a host name of their own:

```bash
# The shared kind cluster (on the CKS training server: kind export kubeconfig, then kubectx kind-kind)
kubectx kind-kind
NS=ingress-tls-$(whoami)
HOST=hello-$(whoami).info
kubectl create namespace $NS
kubectl config set-context --current --namespace=$NS
mkdir -p $HOME/ingress-tls && cd $HOME/ingress-tls
```

Deploy the application:

```bash
kubectl create deployment web --image=gcr.io/google-samples/hello-app:1.0
kubectl expose deployment web --port=8080
kubectl wait --for=condition=available deployment web
```

## Exercise 1: the ingress controller

Which `IngressClass` is available? On which ports of the nodes does Traefik listen for HTTP and HTTPS?

{{%expand "Solution" %}}
```bash
kubectl get ingressclass
# NAME      CONTROLLER                      PARAMETERS   AGE
# traefik   traefik.io/ingress-controller   <none>       5m

NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
HTTP_PORT=$(kubectl get svc traefik -n traefik -o jsonpath='{.spec.ports[?(@.port==80)].nodePort}')
HTTPS_PORT=$(kubectl get svc traefik -n traefik -o jsonpath='{.spec.ports[?(@.port==443)].nodePort}')
echo $NODE_IP $HTTP_PORT $HTTPS_PORT
```

A `NodePort` Service listens on every node: any node IP works.
{{% /expand%}}

## Exercise 2: a certificate in a Secret

Create a self-signed certificate for `$HOST` with `openssl`, then store it in a `Secret` named `web-tls`.

{{%expand "Solution" %}}
```bash
openssl req -x509 -newkey rsa:2048 -nodes -days 365 \
  -keyout tls.key -out tls.crt \
  -subj "/CN=$HOST" -addext "subjectAltName=DNS:$HOST"
kubectl create secret tls web-tls --cert=tls.crt --key=tls.key
kubectl get secret web-tls -o jsonpath='{.type}{"\n"}'
# kubernetes.io/tls
```

The Secret holds the private key in the `tls.key` field: anybody who can read the Secrets of the namespace can impersonate the site. Restrict `get secrets` with RBAC, and encrypt the Secrets at rest (see the [etcd encryption lab]({{% ref "/1_Labs/etcd-encryption" %}})).

In production, [cert-manager](https://cert-manager.io/) creates and renews these Secrets, with a certificate signed by a real authority.
{{% /expand%}}

## Exercise 3: the Ingress with TLS

Create an Ingress `web` of class `traefik` which sends `https://$HOST/` to the Service `web` on port `8080`, with the certificate of `web-tls`. Use `kubectl create ingress -h`, or the [documentation](https://kubernetes.io/docs/concepts/services-networking/ingress/#tls).

Then call the application with `curl`, without and with the certificate.

{{% notice tip %}}
`curl --resolve $HOST:<port>:<ip>` resolves `$HOST` without `/etc/hosts`, and sends the right host name to the ingress controller (HTTP `Host` header and TLS SNI).
{{% /notice %}}

{{%expand "Solution" %}}
```bash
kubectl create ingress web --class=traefik --rule="$HOST/*=web:8080,tls=web-tls"
kubectl get ingress web -o yaml
```

The `tls` section of the Ingress lists the hosts and the Secret of their certificate:

```yaml
spec:
  ingressClassName: traefik
  rules:
  - host: hello-<user>.info
    http:
      paths:
      - backend:
          service:
            name: web
            port:
              number: 8080
        path: /
        pathType: Prefix
  tls:
  - hosts:
    - hello-<user>.info
    secretName: web-tls
```

```bash
curl --resolve "$HOST:$HTTPS_PORT:$NODE_IP" https://$HOST:$HTTPS_PORT/ || echo "EXPECTED ERROR"
# curl: (60) SSL certificate problem: self-signed certificate
curl --cacert tls.crt --resolve "$HOST:$HTTPS_PORT:$NODE_IP" https://$HOST:$HTTPS_PORT/
# Hello, world!
# Version: 1.0.0
```

`--cacert tls.crt` trusts our self-signed certificate: `curl` checks it, unlike `curl -k` which accepts any certificate.
{{% /expand%}}

## Exercise 4: which certificate is served?

Display the subject of the certificate served by Traefik for `$HOST`, then for another host name, `other.info`. Explain.

{{%expand "Solution" %}}
```bash
openssl s_client -connect $NODE_IP:$HTTPS_PORT -servername $HOST </dev/null 2>/dev/null | openssl x509 -noout -subject
# subject=CN = hello-<user>.info
openssl s_client -connect $NODE_IP:$HTTPS_PORT -servername other.info </dev/null 2>/dev/null | openssl x509 -noout -subject
# subject=CN = TRAEFIK DEFAULT CERT
```

The client sends the host name in the TLS handshake (SNI), and the ingress controller chooses the certificate from the `tls` sections of all the Ingresses. A host without certificate gets the default certificate of the controller.
{{% /expand%}}

## Exercise 5: HTTPS only

Call the application over plain HTTP. Then make the Ingress answer only over HTTPS.

{{% notice tip %}}
Look for the `router.entrypoints` annotation in the [Traefik documentation](https://doc.traefik.io/traefik/routing/providers/kubernetes-ingress/). The HTTPS entry point of the chart is `websecure`.
{{% /notice %}}

{{%expand "Solution" %}}
```bash
curl -s -o /dev/null -w "%{http_code}\n" --resolve "$HOST:$HTTP_PORT:$NODE_IP" http://$HOST:$HTTP_PORT/
# 200: the application is also served in clear

kubectl annotate ingress web traefik.ingress.kubernetes.io/router.entrypoints=websecure
curl -s -o /dev/null -w "%{http_code}\n" --resolve "$HOST:$HTTP_PORT:$NODE_IP" http://$HOST:$HTTP_PORT/
# 404
curl -s -o /dev/null -w "%{http_code}\n" --cacert tls.crt --resolve "$HOST:$HTTPS_PORT:$NODE_IP" https://$HOST:$HTTPS_PORT/
# 200
```

The `tls` section does not disable HTTP: it depends on the controller, with an annotation or its configuration (Traefik: entry points, or a redirection of the `web` entry point to `websecure` for the whole controller). In the exam, read the documentation of the controller given in the task.
{{% /expand%}}

## Questions

1. Where is the TLS connection terminated? Is the traffic between Traefik and the pod encrypted?
2. How do you protect the private key of the certificate?

{{%expand "Answers" %}}
1. In the ingress controller: the traffic from Traefik to the pod is plain HTTP, inside the cluster network. To encrypt it too, the application must serve TLS itself, or a service mesh (Istio, Linkerd) or the CNI (Cilium) encrypts the pod-to-pod traffic: this is the *pod-to-pod encryption* of the CKS curriculum.
2. RBAC on the Secrets of the namespace (no `get`/`list`/`watch` on `secrets` for the users and service accounts which do not need it), encryption at rest in etcd, and short-lived certificates renewed automatically (cert-manager).
{{% /expand%}}

## Clean up

```bash
kubectl delete namespace $NS
kubectl config set-context --current --namespace=default
rm -rf $HOME/ingress-tls
```
