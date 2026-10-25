---
title: 'OpenShift administration'
date: 2026-10-20T08:00:00+02:00
draft: false
weight: 120
tags: ["kubernetes", "labs", "pre-requisite", "openshift"]
---

Three-part training on **OpenShift 4 administration**. Topics shared with vanilla Kubernetes use the Kubernetes slides, listed with each topic below.

## Slides used throughout the training

These decks are used across all parts:

- [OPENSHIFT.pdf](https://k8s-school.fr/labs/k8s/pdf/OPENSHIFT.pdf): differences with vanilla Kubernetes, installation, Machine API, RBAC, SCCs
- [C_K8s_02_standard_API.pdf](https://k8s-school.fr/labs/k8s/pdf/C_K8s_02_standard_API.pdf): Kubernetes basics reminder: Deployments, rollouts, StatefulSets, K9s

## Part 1: Introduction

### Back to Kubernetes basics

**Slides:**

- [E_01_advanced-k8s-cluster-internals.pdf](https://k8s-school.fr/labs/k8s/pdf/E_01_advanced-k8s-cluster-internals.pdf): cluster internals, etcd, API server, scheduler

**Labs:**

- [Kubernetes Controllers]({{% ref "/1_Labs/controller" %}})
- [Multi-Container Pod Design Patterns]({{% ref "/1_Labs/multi-container-patterns" %}})
- [Kubelet and static pods]({{% ref "/1_Labs/openshift-staticpod" %}})
- [etcd administration]({{% ref "/1_Labs/openshift-etcd" %}})

### Ingress, Routes and DeploymentConfig

**Slides:**

- [D_01_Ingress.pdf](https://k8s-school.fr/labs/k8s/pdf/D_01_Ingress.pdf)
- [D_08_openshift_ingress-gateway.pdf](https://k8s-school.fr/labs/k8s/pdf/D_08_openshift_ingress-gateway.pdf): Ingress, Routes and Gateway API

**Labs:**

- [OpenShift Networking: From Ingress to Route]({{% ref "/1_Labs/openshift-ingress-route" %}})

### Pod placement: affinity, anti-affinity, taints

**Slides:**

- [E_05_advanced-k8s_advanced_scheduling.pdf](https://k8s-school.fr/labs/k8s/pdf/E_05_advanced-k8s_advanced_scheduling.pdf)

**Labs:**

- [Pod placement: affinity, anti-affinity, taints]({{% ref "/1_Labs/antiaffinity" %}})

**Article:**

- [Taints and tolerations]({{% ref "/Articles/Taints_and_Tolerations/01-Taints" %}})

## Part 2: Administration and security

### Operators

**Slides:**

- [E_06_advanced-k8s_operators.pdf](https://k8s-school.fr/labs/k8s/pdf/E_06_advanced-k8s_operators.pdf)

**Demo:**

- Install and use an operator from the OpenShift web console (OperatorHub)

**Labs:**

- [Operators with OLM: the Grafana Operator]({{% ref "/1_Labs/openshift-olm" %}})

### Monitoring: application metrics and Thanos

**Slides:**

- [D_03_Prometheus_monitoring.pdf](https://k8s-school.fr/labs/k8s/pdf/D_03_Prometheus_monitoring.pdf)
- [D_05_multicluster-monitoring.pdf](https://k8s-school.fr/labs/k8s/pdf/D_05_multicluster-monitoring.pdf): Thanos

**Labs:**

- [Monitoring with Prometheus]({{% ref "/1_Labs/prometheus" %}})
- [Prometheus operator demo](https://github.com/k8s-school/demo-prometheus)

### Stateful applications

**Slides:**

- [C_K8s_02_standard_API.pdf](https://k8s-school.fr/labs/k8s/pdf/C_K8s_02_standard_API.pdf): StatefulSets

**Labs:**

- [MongoDB]({{% ref "/1_Labs/mongo" %}}): up to the Rolling Update section, which is done in Part 3

### MachineSets and availability zones

**Slides:**

- [OPENSHIFT.pdf](https://k8s-school.fr/labs/k8s/pdf/OPENSHIFT.pdf): Machine API, MachineSets

**Labs:**

- [OpenShift MachineSets and availability zones]({{% ref "/1_Labs/openshift-machineset" %}}) (on the shared Azure IPI cluster)

### RBAC

**Slides:**

- [E_02_advanced-k8s_RBAC.pdf](https://k8s-school.fr/labs/k8s/pdf/E_02_advanced-k8s_RBAC.pdf)

**Labs:**

- [Kubectl proxy and curl]({{% ref "/1_Labs/kubectl-proxy" %}})
- [RBAC]({{% ref "/1_Labs/rbac" %}})
- [RBAC monitoring]({{% ref "/1_Labs/rbac-secissue" %}})
- [Kubernetes Service Account Token Lab]({{% ref "/1_Labs/service-account" %}})

### Security context and SCCs

**Slides:**

- [E_03_advanced-k8s_Security_node+network.pdf](https://k8s-school.fr/labs/k8s/pdf/E_03_advanced-k8s_Security_node+network.pdf): security context, Pod Security Admission, NetworkPolicy

**Labs:**

- Security context (on kind): [script](https://github.com/k8s-school/k8s-advanced/blob/master/labs/3_policies/ex1-securitycontext.sh)
- Pod Security Admission (on kind): [script](https://github.com/k8s-school/k8s-advanced/blob/master/labs/3_policies/ex2-podsecurity.sh)
- [OpenShift Security Context Constraints (SCC)]({{% ref "/1_Labs/openshift-scc" %}})
- [Helm on OpenShift: Migrating to Security Context Constraints]({{% ref "/1_Labs/helm-openshift-migration" %}})
- [NetworkPolicy]({{% ref "/1_Labs/networkpolicy" %}}) (optional, on kind)

### Autoscaling

**Slides:**

- [E_04_advanced-k8s_computational_resources.pdf](https://k8s-school.fr/labs/k8s/pdf/E_04_advanced-k8s_computational_resources.pdf)

**Labs:**

- Requests, limits, quotas and LimitRanges: [scripts](https://github.com/k8s-school/openshift-advanced/tree/master/labs/4_computational_resources)
- [Horizontal Pod Autoscaling (HPA)]({{% ref "/1_Labs/hpa" %}})
- [Vertical Pod Autoscaling (VPA)]({{% ref "/1_Labs/vpa" %}})

## Part 3: Deployment and troubleshooting

### Rolling updates, rollback, canary and A/B testing

**Slides:**

- [C_K8s_02_standard_API.pdf](https://k8s-school.fr/labs/k8s/pdf/C_K8s_02_standard_API.pdf): Deployments, rollouts
- [D_08_openshift_ingress-gateway.pdf](https://k8s-school.fr/labs/k8s/pdf/D_08_openshift_ingress-gateway.pdf): Gateway API

**Labs:**

- [Deployments: rolling update, rollback and canary]({{% ref "/1_Labs/rollout" %}})
- [StatefulSet: canary with partition, rolling update and rollback of MongoDB](https://k8s-school.fr/labs/k8s/en/1_labs/mongo/index.html#rolling-update)
- [Gateway API: canary release and A/B testing]({{% ref "/1_Labs/gateway-api-ab-testing" %}})

### Troubleshooting

**Slides:**

- [D_06_develop_with_k8s.pdf](https://k8s-school.fr/labs/k8s/pdf/D_06_develop_with_k8s.pdf): `kubectl debug` and ephemeral containers

**Labs:**

- [ktbx, the Kubernetes toolbox](https://github.com/k8s-school/ktbx), including K9s
- [kubectl essentials]({{% ref "/Articles/kubectl-essential" %}})
- [Troubleshooting an application from A to Z]({{% ref "/1_Labs/troubleshooting" %}})
- [Debugging with an ephemeral container](https://kubernetes.io/docs/tasks/debug/debug-application/debug-running-pod/#ephemeral-container) (Kubernetes documentation)
