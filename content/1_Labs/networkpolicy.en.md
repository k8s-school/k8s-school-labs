---
title: 'NetworkPolicy'
date: 2024-06-06T14:15:26+10:00
draft: false
weight: 75
tags: ["Kubernetes", "NetworkPolicy", "Security", "CKS"]
---

**Author:** Fabrice JAMMES ([LinkedIn](https://www.linkedin.com/in/fabrice-jammes-5b29b042/)).

## Objective

Isolate the pods of a namespace with [NetworkPolicies](https://kubernetes.io/docs/concepts/services-networking/network-policies/): deny everything by default, then allow only the needed flows, in ingress **and** in egress.

The application has three pods:

| Pod | Labels | Role |
|---|---|---|
| `postgresql` | `tier=database` | The database, behind the Service `pgsql` (port `5432`) |
| `webserver` | `tier=webserver` | The only client allowed to reach the database |
| `external` | `app=external` | Any other pod: must reach nothing |

The lab works on a cluster shared by the trainees: each one works in a namespace of their own. The NetworkPolicies are enforced by the CNI plugin: the one of the training cluster supports them.

## Setup

```bash
# The shared kind cluster (on the CKS training server: kind export kubeconfig, then kubectx kind-kind)
kubectx kind-kind
NS=network-$(whoami)
kubectl create namespace $NS
kubectl config set-context --current --namespace=$NS

kubectl run postgresql --image=postgres:17-alpine --labels=tier=database --env=POSTGRES_PASSWORD=postgres --port=5432
kubectl expose pod postgresql --name=pgsql --port=5432
kubectl run webserver --image=busybox:1.36 --labels=tier=webserver -- sleep infinity
kubectl run external --image=busybox:1.36 --labels=app=external -- sleep infinity
kubectl wait --for=condition=Ready pod --all --timeout=120s
kubectl get pods --show-labels
```

This function tests a TCP connection from a pod, with `nc` (2 seconds timeout):

```bash
can() {
  if kubectl exec $1 -- nc -z -w 2 $2 $3 >/dev/null 2>&1; then
    echo "$1 -> $2:$3 open"
  else
    echo "$1 -> $2:$3 BLOCKED"
  fi
}
can webserver pgsql 5432
can external pgsql 5432
can external k8s-school.fr 443
# webserver -> pgsql:5432 open
# external -> pgsql:5432 open
# external -> k8s-school.fr:443 open
```

Without any NetworkPolicy, all the flows are open: inside the namespace, with the other namespaces, and to Internet.

## Exercise 1: deny all the ingress traffic

Create a NetworkPolicy `default-deny-ingress` which denies all the incoming connections to all the pods of the namespace. Test the connections again.

{{%expand "Solution" %}}
```bash
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-ingress
spec:
  podSelector: {}
  policyTypes:
  - Ingress
EOF
can webserver pgsql 5432
can external pgsql 5432
can external k8s-school.fr 443
# webserver -> pgsql:5432 BLOCKED
# external -> pgsql:5432 BLOCKED
# external -> k8s-school.fr:443 open
```

`podSelector: {}` selects all the pods of the namespace. A policy with `policyTypes: [Ingress]` and no `ingress` rule allows nothing: the selected pods are isolated in ingress. The egress is still open.
{{% /expand%}}

## Exercise 2: allow the webserver to reach the database

Create a NetworkPolicy `db-from-webserver` which allows the pods `tier=webserver` to connect to the pods `tier=database` on port `5432` only.

{{%expand "Solution" %}}
```bash
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: db-from-webserver
spec:
  podSelector:
    matchLabels:
      tier: database
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          tier: webserver
    ports:
    - protocol: TCP
      port: 5432
EOF
can webserver pgsql 5432
can external pgsql 5432
# webserver -> pgsql:5432 open
# external -> pgsql:5432 BLOCKED
```

The NetworkPolicies are additive: a connection is allowed if **one** policy allows it. `default-deny-ingress` does not block what `db-from-webserver` allows.
{{% /expand%}}

## Exercise 3: deny all the egress traffic, except DNS

1. Create a NetworkPolicy `default-deny-egress` which denies all the outgoing connections of all the pods of the namespace. Test the connections: why is `webserver -> pgsql` blocked now?
2. Allow the DNS requests of all the pods to the DNS server of the cluster (pods `k8s-app=kube-dns` in `kube-system`, port `53` in UDP and TCP).
3. Allow the egress traffic from the webserver to the database, on port `5432`.

{{%expand "Solution" %}}
```bash
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-egress
spec:
  podSelector: {}
  policyTypes:
  - Egress
EOF
can webserver pgsql 5432
# webserver -> pgsql:5432 BLOCKED
kubectl exec webserver -- nslookup pgsql || echo "EXPECTED ERROR"
# ;; connection timed out; no servers could be reached
```

The webserver can no longer resolve the name `pgsql`: the DNS requests to CoreDNS are egress traffic too.

```bash
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-dns
spec:
  podSelector: {}
  policyTypes:
  - Egress
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: kube-system
      podSelector:
        matchLabels:
          k8s-app: kube-dns
    ports:
    - protocol: UDP
      port: 53
    - protocol: TCP
      port: 53
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: webserver-to-db
spec:
  podSelector:
    matchLabels:
      tier: webserver
  policyTypes:
  - Egress
  egress:
  - to:
    - podSelector:
        matchLabels:
          tier: database
    ports:
    - protocol: TCP
      port: 5432
EOF
can webserver pgsql 5432
can external pgsql 5432
can external k8s-school.fr 443
# webserver -> pgsql:5432 open
# external -> pgsql:5432 BLOCKED
# external -> k8s-school.fr:443 BLOCKED
kubectl get networkpolicy
```

The webserver needs two policies: its egress (`webserver-to-db`) **and** the ingress of the database (`db-from-webserver`), since both sides are isolated.
{{% /expand%}}

## Exercise 4: AND or OR?

What is the difference between these two rules?

```yaml
# Rule A
ingress:
- from:
  - namespaceSelector:
      matchLabels:
        team: frontend
    podSelector:
      matchLabels:
        tier: webserver
```

```yaml
# Rule B
ingress:
- from:
  - namespaceSelector:
      matchLabels:
        team: frontend
  - podSelector:
      matchLabels:
        tier: webserver
```

{{%expand "Answer" %}}
- **Rule A**, one element with two selectors: the pods `tier=webserver` **of** the namespaces `team=frontend` (AND).
- **Rule B**, two elements (two `-`): **all** the pods of the namespaces `team=frontend`, **or** the pods `tier=webserver` of the namespace of the policy (OR).

One dash changes the meaning: it is a classic trap of the exam. The rule `allow-dns` of exercise 3 uses the AND form, to only allow the CoreDNS pods of `kube-system`.
{{% /expand%}}

## Questions

1. A pod is selected by no NetworkPolicy. Which traffic is allowed?
2. Do the NetworkPolicies filter the traffic of the pods with `hostNetwork: true`?

{{%expand "Answers" %}}
1. Everything: a pod is isolated, in ingress or egress, only if a policy with this `policyType` selects it.
2. No: they share the network of the node, the CNI plugin does not see their traffic as pod traffic. It is one more reason to forbid `hostNetwork` (Pod Security Standards `baseline`).
{{% /expand%}}

## Clean up

```bash
kubectl delete namespace $NS
kubectl config set-context --current --namespace=default
```

The [ex4-network.sh](https://github.com/k8s-school/k8s-advanced/blob/master/labs/3_policies/ex4-network.sh) script of the k8s-advanced repository runs a similar scenario with a webserver based on nginx.
