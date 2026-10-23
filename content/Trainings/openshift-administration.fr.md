---
title: 'Administration OpenShift'
date: 2026-10-20T08:00:00+02:00
draft: false
weight: 120
tags: ["kubernetes", "labs", "pre-requis", "openshift"]
---

Formation de trois jours à l'**administration d'OpenShift 4**. Les sujets communs avec Kubernetes utilisent les supports Kubernetes.

{{% notice note %}}
Les travaux pratiques sont rédigés en anglais.
{{% /notice %}}

## Supports de cours

### OpenShift

- [OPENSHIFT.pdf](https://k8s-school.fr/labs/k8s/pdf/OPENSHIFT.pdf) : différences avec Kubernetes, installation, Machine API, RBAC, SCC
- [D_08_openshift_ingress-gateway.pdf](https://k8s-school.fr/labs/k8s/pdf/D_08_openshift_ingress-gateway.pdf) : Ingress, Routes et Gateway API

### Kubernetes

- [E_01_advanced-k8s-cluster-internals.pdf](https://k8s-school.fr/labs/k8s/pdf/E_01_advanced-k8s-cluster-internals.pdf)
- [C_K8s_02_standard_API.pdf](https://k8s-school.fr/labs/k8s/pdf/C_K8s_02_standard_API.pdf) : Deployments, rollouts, StatefulSets, K9s
- [E_02_advanced-k8s_RBAC.pdf](https://k8s-school.fr/labs/k8s/pdf/E_02_advanced-k8s_RBAC.pdf)
- [E_03_advanced-k8s_Security_node+network.pdf](https://k8s-school.fr/labs/k8s/pdf/E_03_advanced-k8s_Security_node+network.pdf) : security context, Pod Security Admission, NetworkPolicy
- [E_04_advanced-k8s_computational_resources.pdf](https://k8s-school.fr/labs/k8s/pdf/E_04_advanced-k8s_computational_resources.pdf)
- [E_05_advanced-k8s_advanced_scheduling.pdf](https://k8s-school.fr/labs/k8s/pdf/E_05_advanced-k8s_advanced_scheduling.pdf)
- [E_06_advanced-k8s_operators.pdf](https://k8s-school.fr/labs/k8s/pdf/E_06_advanced-k8s_operators.pdf)
- [D_03_Prometheus_monitoring.pdf](https://k8s-school.fr/labs/k8s/pdf/D_03_Prometheus_monitoring.pdf)
- [D_05_multicluster-monitoring.pdf](https://k8s-school.fr/labs/k8s/pdf/D_05_multicluster-monitoring.pdf) : Thanos
- [D_06_develop_with_k8s.pdf](https://k8s-school.fr/labs/k8s/pdf/D_06_develop_with_k8s.pdf) : `kubectl debug` et conteneurs éphémères

## Jour 1 : introduction

### Retour sur les bases de Kubernetes (slides `E_01` : fonctionnement interne du cluster, etcd, API server, scheduler)

- [Kubernetes Controllers](https://k8s-school.fr/labs/k8s/en/1_labs/controller/index.html)
- [Multi-Container Pod Design Patterns](https://k8s-school.fr/labs/k8s/en/1_labs/multi-container-patterns/index.html)
- [Kubelet and static pods](https://k8s-school.fr/labs/k8s/en/1_labs/openshift-staticpod/index.html)
- [etcd administration](https://k8s-school.fr/labs/k8s/en/1_labs/openshift-etcd/index.html)

### Routes et DeploymentConfig

- [OpenShift Networking: From Ingress to Route](https://k8s-school.fr/labs/k8s/en/1_labs/openshift-ingress-route/index.html)

### Placement des pods : affinité, anti-affinité, taints

- [Pod placement: affinity, anti-affinity, taints](https://k8s-school.fr/labs/k8s/en/1_labs/antiaffinity/index.html)
- [Taints et tolérations]({{% ref "/Articles/Taints_and_Tolerations" %}})

## Jour 2 : administration et sécurité

### Opérateurs

- [Démo de l'opérateur Prometheus](https://github.com/k8s-school/demo-prometheus)

### Supervision : métriques applicatives et Thanos

- [Monitoring with Prometheus](https://k8s-school.fr/labs/k8s/en/1_labs/prometheus/index.html)

### Applications stateful

- [MongoDB]({{% ref "/1_Labs/mongo" %}})

### MachineSets et zones de disponibilité

- [OpenShift MachineSets and availability zones](https://k8s-school.fr/labs/k8s/en/1_labs/openshift-machineset/index.html) (slides `OPENSHIFT`, sur le cluster Azure IPI partagé)

### RBAC et SCC

- [Kubectl proxy and curl](https://k8s-school.fr/labs/k8s/en/1_labs/kubectl-proxy/index.html)
- [RBAC](https://k8s-school.fr/labs/k8s/en/1_labs/rbac/index.html)
- [RBAC monitoring](https://k8s-school.fr/labs/k8s/en/1_labs/rbac-secissue/index.html)
- [Kubernetes Service Account Token Lab](https://k8s-school.fr/labs/k8s/en/1_labs/service-account/index.html)
- Security context (slides `E_03`, sur kind) : [script](https://github.com/k8s-school/k8s-advanced/blob/master/labs/3_policies/ex1-securitycontext.sh)
- Pod Security Admission (slides `E_03`, sur kind) : [script](https://github.com/k8s-school/k8s-advanced/blob/master/labs/3_policies/ex2-podsecurity.sh)
- [OpenShift Security Context Constraints (SCC)](https://k8s-school.fr/labs/k8s/en/1_labs/openshift-scc/index.html)
- [Helm on OpenShift: Migrating to Security Context Constraints](https://k8s-school.fr/labs/k8s/en/1_labs/helm-openshift-migration/index.html)
- [NetworkPolicy](https://k8s-school.fr/labs/k8s/en/1_labs/networkpolicy/index.html) (optionnel, slides `E_03`, sur kind)

### Autoscaling

- Requests, limits, quotas et LimitRanges (slides `E_04`) : [scripts](https://github.com/k8s-school/openshift-advanced/tree/master/labs/4_computational_resources)
- [Horizontal Pod Autoscaling (HPA)](https://k8s-school.fr/labs/k8s/en/1_labs/hpa/index.html)
- [Vertical Pod Autoscaling (VPA)](https://k8s-school.fr/labs/k8s/en/1_labs/vpa/index.html)

## Jour 3 : déploiement et dépannage

### Rolling update, rollback, canary et A/B testing

- [Deployments: rolling update, rollback and canary](https://k8s-school.fr/labs/k8s/en/1_labs/rollout/index.html) (slides `C_K8s_02`)
- [StatefulSet : canary avec partition, rolling update et rollback de MongoDB](https://k8s-school.fr/labs/k8s/en/1_labs/mongo/index.html#rolling-update)
- [Gateway API: canary release and A/B testing](https://k8s-school.fr/labs/k8s/en/1_labs/gateway-api-ab-testing/index.html) (slides `D_08`)

### Dépannage

- [ktbx, la boîte à outils Kubernetes](https://github.com/k8s-school/ktbx), dont K9s
- [kubectl essentiel]({{% ref "/Articles/kubectl-essential" %}})
- [Troubleshooting an application from A to Z](https://k8s-school.fr/labs/k8s/en/1_labs/troubleshooting/index.html)
- [Debugging with an ephemeral container](https://kubernetes.io/docs/tasks/debug/debug-application/debug-running-pod/#ephemeral-container) (documentation Kubernetes)
