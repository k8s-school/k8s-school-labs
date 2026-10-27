---
title: 'NetworkPolicy'
date: 2024-06-06T14:15:26+10:00
draft: false
weight: 75
tags: ["Kubernetes", "NetworkPolicy", "Security", "CKS"]
---

## Prerequisites

```bash
# Check you use the context of the shared kind cluster (kind-kind),
# or of your own cluster on the CKS training server (kind-$CLUSTER_NAME)
kubectx

# Launch initialization script
git clone https://github.com/k8s-school/k8s-advanced ~/k8s-advanced
~/k8s-advanced/labs/3_policies/ex4-network.sh

# go to correct namespace
kubens network-student<ID>
```

Check that 3 pods have been created.

{{%expand "Solution" %}}
```bash
kubectl get pods --show-labels
NAME         READY   STATUS    RESTARTS   AGE   LABELS
external     1/1     Running   0          2m    app=external
postgresql   1/1     Running   0          2m    app=postgresql,tier=database
webserver    1/1     Running   0          2m    tier=webserver
```
{{% /expand%}}



## Play with network policy

Look at the [official documentation](https://kubernetes.io/docs/concepts/services-networking/network-policies/#the-networkpolicy-resource) and at the [examples](https://github.com/ahmetb/kubernetes-network-policy-recipes)

### Prevent all ingress connections

Add a rule which prevents all ingress connections in the namespace

{{%expand "Solution" %}}
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny
spec:
  podSelector: {}
  policyTypes:
  - Ingress
{{% /expand%}}

### Create network policy

Create a network policy to restrict ingress connection to `postgresql`. Only `webserver` pod should be able to connect to `postgresql` on port `5432`.

{{%expand "Solution" %}}
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: ingress-www-db
spec:
  podSelector:
    matchLabels:
      tier: database
  ingress:
  - from:
    - podSelector:
        matchLabels:
          tier: webserver
    ports:
    - port: 5432
  policyTypes:
  - Ingress
```
{{% /expand%}}

### Check network connections between pods
Using `kubectl exec -n network-student<ID> external -- netcat -w 2 -zv pgsql-postgresql 5432`

{{%expand "Solution" %}}
```bash
# webserver pod to database pod, using DNS name
kubectl exec -n network-student<ID> webserver -- netcat -q 2 -zv pgsql-postgresql 5432
pgsql-postgresql.network-student<ID>.svc.cluster.local [10.96.205.70] 5432 (postgresql) open

# external pod to database pod
kubectl exec -n network-student<ID> external -- netcat -w 2 -zv pgsql-postgresql 5432
pgsql-postgresql.network-student<ID>.svc.cluster.local [10.96.205.70] 5432 (postgresql) : Connection timed out
```
{{% /expand%}}

## Reference
For more details, check the [k8s-school NetworkPolicy lab](https://github.com/k8s-school/k8s-advanced/tree/master/labs/3_policies/ex4-network.sh).