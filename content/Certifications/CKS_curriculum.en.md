---
title: 'CKS: Required Skills'
date: 2025-01-18T14:15:26+10:00
draft: false
weight: 30
tags: ["kubernetes", "CKS", "security"]
---

The requirements are listed in the [CKS Curriculum](https://github.com/cncf/curriculum/tree/master). Make sure to check the up-to-date version.

Here is the content of version `1.34` of the Curriculum:

# CKS Program

## 10% - Cluster Setup

- Use CIS benchmark to review the security configuration of Kubernetes components (etcd, kubelet, kubedns, kubeapi)
- Properly set up Ingress objects with security controls
- Protect node metadata and endpoints
- Minimize use of, and access to, GUI elements
- Verify platform binaries before deploying

## 15% - Cluster Hardening

- Restrict access to Kubernetes API
- Use Role Based Access Controls to minimize exposure
- Exercise caution in using service accounts, e.g. disable defaults, minimize permissions on newly created ones
- Update Kubernetes frequently

## 15% - System Hardening

- Minimize host OS footprint (reduce attack surface)
- Minimize IAM roles
- Minimize external access to the network
- Appropriately use kernel hardening tools such as AppArmor, seccomp

## 20% - Minimize Microservice Vulnerabilities

- Setup appropriate OS level security domains e.g. using PSP, OPA, security contexts
- Manage Kubernetes secrets
- Use container runtime sandboxes in multi-tenant environments (e.g. gvisor, kata containers)
- Implement pod to pod encryption by use of mTLS

## 20% - Supply Chain Security

- Minimize base image footprint
- Secure your supply chain: whitelist allowed registries, sign and validate images
- Use static analysis of user workloads (e.g. kubernetes resources, docker files)
- Scan images for known vulnerabilities

## 20% - Monitoring, Logging and Runtime Security

- Perform behavioral analytics of syscall process and file activities at the host and container level to detect malicious activities
- Detect threats within physical infrastructure, apps, networks, data, users and workloads
- Detect all phases of attack regardless of where it occurs and how it spreads
- Perform deep analytical investigation and identification of bad actors within environment
- Ensure immutability of containers at runtime
- Use Audit Logs to monitor access

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
