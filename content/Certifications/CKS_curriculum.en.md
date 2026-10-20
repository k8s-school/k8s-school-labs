---
title: 'CKS: Required Skills'
date: 2026-10-16T08:00:00+02:00
draft: false
weight: 30
tags: ["kubernetes", "CKS", "security"]
---

The requirements are listed in the [CKS Curriculum](https://github.com/cncf/curriculum/tree/master). Make sure to check the up-to-date version.

Here is the content of version `1.34` of the Curriculum ([PDF](https://github.com/cncf/curriculum/blob/master/CKS_Curriculum%20v1.34.pdf)):

# CKS Program

## 15% - Cluster Setup

- Use Network security policies to restrict cluster level access
- Use CIS benchmark to review the security configuration of Kubernetes components (etcd, kubelet, kubedns, kubeapi)
- Properly set up Ingress objects with TLS
- Protect node metadata and endpoints
- Verify platform binaries before deploying

## 15% - Cluster Hardening

- Use Role Based Access Controls to minimize exposure
- Exercise caution in using service accounts e.g. disable defaults, minimize permissions on newly created ones
- Restrict access to Kubernetes API
- Upgrade Kubernetes to avoid vulnerabilities

## 10% - System Hardening

- Minimize host OS footprint (reduce attack surface)
- Using least-privilege identity and access management
- Minimize external access to the network
- Appropriately use kernel hardening tools such as AppArmor, seccomp

## 20% - Minimize Microservice Vulnerabilities

- Use appropriate pod security standards
- Manage Kubernetes secrets
- Understand and implement isolation techniques (multi-tenancy, sandboxed containers, etc.)
- Implement Pod-to-Pod encryption (Cilium, Istio)

## 20% - Supply Chain Security

- Minimize base image footprint
- Understand your supply chain (e.g. SBOM, CI/CD, artifact repositories)
- Secure your supply chain (permitted registries, sign and validate artifacts, etc.)
- Perform static analysis of user workloads and container images (e.g. Kubesec, KubeLinter)

## 20% - Monitoring, Logging and Runtime Security

- Perform behavioral analytics to detect malicious activities
- Detect threats within physical infrastructure, apps, networks, data, users and workloads
- Investigate and identify phases of attack and bad actors within the environment
- Ensure immutability of containers at runtime
- Use Kubernetes audit logs to monitor access

The training program is based on this curriculum.

## Prerequisites

**Important**: To take the CKS exam, you must have a valid CKA (Certified Kubernetes Administrator) certification.

## Exam Details

- **Duration**: 2 hours
- **Passing Score**: 67%
- **Format**: Performance-based exam with hands-on tasks
- **Environment**: 16 clusters (one for each task)
- **Validity**: 2 years from certification date

## Security Tools and Technologies

The exam may include working with:
- Network policies
- Pod Security Standards
- RBAC (Role-Based Access Control)
- Security contexts and capabilities
- Image scanning and vulnerability assessment
- Runtime security monitoring (Falco)
- Audit logging
- TLS and certificate management
- Container runtime security

## CKS training

[Free Kubernetes CKS Full Course Theory](https://www.youtube.com/watch?v=d9xfB5qaOfg)

A comprehensive course led by Fabrice Jammes, a CKS/CKA certified expert, is also available at [k8s-school.fr](https://k8s-school.fr). This training provides the unique opportunity to benefit from his extensive field experience and valuable insights from managing Kubernetes in large-scale production environments.
