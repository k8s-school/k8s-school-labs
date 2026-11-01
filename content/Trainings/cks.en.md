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

The slides and labs below are listed in the order of the training. The same labs, sorted by domain of the CKS curriculum: [CKS labs by exam domain]({{% ref "/Certifications/cks-domains" %}}).

## 1. Cluster internals

Slides: [E_01_advanced-k8s-cluster-internals.pdf](https://k8s-school.fr/labs/k8s/pdf/E_01_advanced-k8s-cluster-internals.pdf)

- [Kubelet and static pods on Kubernetes]({{% ref "/1_Labs/staticpod" %}})
- [Encrypt Secrets at rest in etcd]({{% ref "/1_Labs/etcd-encryption" %}})
- Optional, the cluster can be installed by the trainer: [Kubernetes easy install with Kubeadm]({{% ref "/1_Labs/kubeadm" %}})
- [Upgrade a cluster with kubeadm]({{% ref "/1_Labs/kubeadm-upgrade" %}})

## 2. RBAC

Slides: [E_02_advanced-k8s_RBAC.pdf](https://k8s-school.fr/labs/k8s/pdf/E_02_advanced-k8s_RBAC.pdf)

- [Kubectl proxy and curl]({{% ref "/1_Labs/kubectl-proxy" %}})
- [RBAC]({{% ref "/1_Labs/rbac" %}})
- RBAC exercise 2, ClusterRole on PersistentVolumes: [solution](https://github.com/k8s-school/k8s-advanced/blob/master/labs/2_authorization/3_RBAC_clusterrole.sh)
- [RBAC monitoring]({{% ref "/1_Labs/rbac-secissue" %}})
- Bonus: [Kubernetes Service Account Token Lab]({{% ref "/1_Labs/service-account" %}})

## 3. Securing the nodes and the network

Slides: [E_03_advanced-k8s_Security_node+network.pdf](https://k8s-school.fr/labs/k8s/pdf/E_03_advanced-k8s_Security_node+network.pdf)

- [Security context]({{% ref "/1_Labs/security-context" %}})
- [Pod Security Admission]({{% ref "/1_Labs/pod-security-admission" %}})
- [NetworkPolicy]({{% ref "/1_Labs/networkpolicy" %}})

## 4. Ingress

Slides: [D_01_Ingress.pdf](https://k8s-school.fr/labs/k8s/pdf/D_01_Ingress.pdf)

- [Ingress with TLS]({{% ref "/1_Labs/ingress-tls" %}})

## 5. CKS topics

Slides: [CKS.pdf](https://k8s-school.fr/labs/k8s/pdf/CKS.pdf)

Cluster setup and hardening:

- [Hardening with CIS Benchmarks - Running kube-bench Jobs]({{% ref "/1_Labs/kubebench-10-jobs" %}})
- [Hardening with CIS Benchmarks - Security Remediations]({{% ref "/1_Labs/kubebench-20-remediations" %}})
- [Hardening with CIS Benchmarks - Automation and Continuous Compliance]({{% ref "/1_Labs/kubebench-30-automation" %}})

Auditing, monitoring and logging:

- [Audit Logs & API Server]({{% ref "/1_Labs/audit-logs" %}})
- [Runtime Security with Falco]({{% ref "/1_Labs/falco" %}})

System hardening:

- [Seccomp Security Profiles]({{% ref "/1_Labs/seccomp" %}})
- [AppArmor Security Profiles]({{% ref "/1_Labs/apparmor" %}})
- Optional: [Sandboxed containers with gVisor and RuntimeClass]({{% ref "/1_Labs/gvisor" %}}), also covers the binary verification with `sha512sum`

Supply chain security:

- [Trivy: Container Vulnerability Scanning]({{% ref "/1_Labs/trivy" %}}), including SBOM generation
- [Cosign: Container Image Signing & Verification]({{% ref "/1_Labs/cosign" %}})
- Optional: [Allowed registries with a ValidatingAdmissionPolicy]({{% ref "/1_Labs/allowed-registries" %}})

## 6. Optional: computational resources

Not in the CKS curriculum, but quotas and LimitRanges protect the cluster against a namespace which consumes all the resources (denial of service).

Slides: [E_04_advanced-k8s_computational_resources.pdf](https://k8s-school.fr/labs/k8s/pdf/E_04_advanced-k8s_computational_resources.pdf)

- ResourceQuotas and LimitRanges: [scripts](https://github.com/k8s-school/k8s-advanced/tree/master/labs/4_computational_resources)

## Exam preparation

All the pages of the [Certifications]({{% ref "/Certifications" %}}) section, including:

- [CKS: Required Skills]({{% ref "/Certifications/CKS_curriculum" %}})
- [Tips and Tricks]({{% ref "/Certifications/tipsandtricks" %}})
