---
title: 'CKS training'
date: 2026-10-16T08:00:00+02:00
draft: false
weight: 105
tags: ["kubernetes", "labs", "pre-requisite", "CKS", "security"]
---

Two-day training to prepare the **Certified Kubernetes Security Specialist (CKS)** exam.

{{% notice info %}}
Holding the CKA certification is required to sit the CKS exam.
{{% /notice %}}

## Slides

- [CKS.pdf](https://k8s-school.fr/labs/k8s/pdf/CKS.pdf)
- [E_01_advanced-k8s-cluster-internals.pdf](https://k8s-school.fr/labs/k8s/pdf/E_01_advanced-k8s-cluster-internals.pdf)
- [E_02_advanced-k8s_RBAC.pdf](https://k8s-school.fr/labs/k8s/pdf/E_02_advanced-k8s_RBAC.pdf)
- [E_03_advanced-k8s_Security_node+network.pdf](https://k8s-school.fr/labs/k8s/pdf/E_03_advanced-k8s_Security_node+network.pdf)
- [E_04_advanced-k8s_computational_resources.pdf](https://k8s-school.fr/labs/k8s/pdf/E_04_advanced-k8s_computational_resources.pdf)
- [D_01_Ingress.pdf](https://k8s-school.fr/labs/k8s/pdf/D_01_Ingress.pdf)

## Labs by module

### 1. Cluster setup (15%)

Network policies, CIS benchmark, Ingress with TLS, node metadata protection, binary verification.

- [NetworkPolicy]({{% ref "/1_Labs/networkpolicy" %}})
- [Hardening with CIS Benchmarks - Running kube-bench Jobs]({{% ref "/1_Labs/kubebench-10-jobs" %}})
- [Hardening with CIS Benchmarks - Security Remediations]({{% ref "/1_Labs/kubebench-20-remediations" %}})
- [Hardening with CIS Benchmarks - Automation and Continuous Compliance]({{% ref "/1_Labs/kubebench-30-automation" %}})
- [Ingress with TLS]({{% ref "/1_Labs/ingress-tls" %}}) (`D_01_Ingress` slides)

### 2. Cluster hardening (15%)

RBAC, service accounts, API access restriction, Kubernetes upgrades.

- [Kubectl proxy and curl]({{% ref "/1_Labs/kubectl-proxy" %}})
- [RBAC]({{% ref "/1_Labs/rbac" %}})
- [RBAC monitoring]({{% ref "/1_Labs/rbac-secissue" %}})
- Bonus: [Kubernetes Service Account Token Lab]({{% ref "/1_Labs/service-account" %}})
- RBAC exercise 2, ClusterRole on PersistentVolumes (`E_02` slides): [solution](https://github.com/k8s-school/k8s-advanced/blob/master/labs/2_authorization/3_RBAC_clusterrole.sh)
- Upgrade with kubeadm (`E_01` slides): [instructions](https://github.com/k8s-school/k8s-advanced/blob/master/labs/0_kubeadm/exercice-kubeadm.md)

### 3. System hardening (10%)

Host OS footprint, least-privilege IAM, external network access, kernel hardening tools (AppArmor, seccomp).

- [Seccomp Security Profiles]({{% ref "/1_Labs/seccomp" %}})
- [AppArmor Security Profiles]({{% ref "/1_Labs/apparmor" %}})

### 4. Minimize microservice vulnerabilities (20%)

Pod Security Standards, secrets management, isolation techniques (multi-tenancy, sandboxed containers), pod-to-pod encryption (Cilium, Istio).

- [Security context]({{% ref "/1_Labs/security-context" %}}) (`E_03` slides)
- [Pod Security Admission]({{% ref "/1_Labs/pod-security-admission" %}}) (`E_03` slides)
- [Encrypt Secrets at rest in etcd]({{% ref "/1_Labs/etcd-encryption" %}})
- Optional: [Sandboxed containers with gVisor and RuntimeClass]({{% ref "/1_Labs/gvisor" %}}), also covers the binary verification with `sha512sum` (`CKS` slides)

### 5. Supply chain security (20%)

Base image footprint, SBOM and artifact repositories, permitted registries, artifact signing and validation, static analysis (Kubesec, KubeLinter).

- [Trivy: Container Vulnerability Scanning]({{% ref "/1_Labs/trivy" %}}), including SBOM generation
- [Cosign: Container Image Signing & Verification]({{% ref "/1_Labs/cosign" %}})
- Optional: [Allowed registries with a ValidatingAdmissionPolicy]({{% ref "/1_Labs/allowed-registries" %}})

### 6. Monitoring, logging and runtime security (20%)

Behavioral analytics, threat detection and investigation, container immutability, Kubernetes audit logs.

- [Audit Logs & API Server]({{% ref "/1_Labs/audit-logs" %}})
- [Runtime Security with Falco]({{% ref "/1_Labs/falco" %}})

## Other labs of the training

### Cluster internals

- [Kubelet and static pods on Kubernetes]({{% ref "/1_Labs/staticpod" %}})

### Bonus: quotas and LimitRanges

Not in the CKS curriculum, but they protect the cluster against a namespace which consumes all the resources (denial of service).

- ResourceQuotas and LimitRanges (`E_04` slides): [scripts](https://github.com/k8s-school/k8s-advanced/tree/master/labs/4_computational_resources)

## Exam preparation

- [CKS: Required Skills]({{% ref "/Certifications/CKS_curriculum" %}})
- [Tips and Tricks]({{% ref "/Certifications/tipsandtricks" %}})
