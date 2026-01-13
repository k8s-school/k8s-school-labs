---
title: 'CKS - Certified Kubernetes Security Specialist'
date: 2024-06-06T10:00:00+10:00
draft: false
weight: 30
tags: ["CKS", "Security", "Certification", "Kubernetes"]
---

# CKS Training Program - 2 Days

## Overview

This comprehensive 2-day training program prepares participants for the **Certified Kubernetes Security Specialist (CKS)** exam. The focus is on hands-on security implementation, best practices, and real-world scenarios.

## Prerequisites

- **CKA certification required** (or equivalent knowledge)
- Strong understanding of Kubernetes fundamentals
- Linux command line proficiency
- Basic networking and security concepts

---

## Day 1: Security Foundations & Access Control

### Morning Session

#### **Introduction & CKS Overview**
**Slides:**
- CKS exam format and objectives (25% of Kubernetes certifications)
- Defense in depth security model
- Threat landscape and attack vectors
- Lab environment setup

#### **RBAC & Service Accounts**
**Theory:** Role-based access control principles
**Labs:**
- ✅ [RBAC Fundamentals](../1_Labs/rbac.en.md) - Roles, RoleBindings, ClusterRoles
- ✅ [Service Account Deep Dive](../1_Labs/service-account.en.md) - JWT tokens, mounting, API access
- ✅ **Shell Solutions:** `k8s-advanced/labs/2_authorization/`
  - `1_RBAC_sa.sh` - Service Account creation
  - `2_RBAC_role.sh` - Role and RoleBinding
  - `3_RBAC_clusterrole.sh` - ClusterRole scenarios
  - `A_rbac_tools_demo.sh` - RBAC tooling (rbac-tool, kubescape)

**Practice:** Multi-tenant RBAC scenarios, least privilege principles

#### **Security Context & Pod Security Standards**
**Theory:** Linux security primitives, capabilities, user namespaces
**Labs:**
- ✅ **Shell Solution:** `k8s-advanced/labs/3_policies/ex1-securitycontext.sh`
  - Pod security contexts (runAsUser, runAsGroup, fsGroup)
  - Capabilities management (CAP_NET_ADMIN, CAP_SYS_TIME)
  - Host network/PID/IPC access
- ✅ **Shell Solution:** `k8s-advanced/labs/3_policies/ex2-podsecurity.sh`
  - Pod Security Standards (privileged, baseline, restricted)
  - Namespace-level enforcement
  - seccomp profiles (RuntimeDefault)

**Practice:** Hardening pod configurations, capability drops

### Afternoon Session

#### **Network Security**
**Theory:** Kubernetes networking model, CNI security implications
**Labs:**
- ✅ [Network Policies](../1_Labs/networkpolicy.en.md) - Ingress/egress control
- ✅ **Shell Solution:** `k8s-advanced/labs/3_policies/ex4-network.sh`
- **Practice:** Default deny policies, micro-segmentation, CNI-specific policies

<span style="color: red;">**TODO:** Create advanced NetworkPolicy scenarios (namespace isolation, external traffic control)</span>

#### **Image Security & Supply Chain**
**Theory:** Container image security, supply chain attacks
**Labs:**
- Trivy vulnerability scanning
- Kyverno admission controller (block latest tags)

<span style="color: red;">**TODO:** Create comprehensive supply chain security labs:
- Image signing with cosign
- SBOM (Software Bill of Materials) analysis
- Private registry security
- ImagePolicyWebhook concepts (theory only per TODO.CKS)</span>

#### **Day 1 Wrap-up & Q&A**
- Security incident response basics
- Common CKS exam patterns
- Day 2 preview

---

## Day 2: Advanced Security & Monitoring

### Morning Session

#### **Kubernetes Internals & API Security**
**Theory:** API server architecture, etcd security, control plane hardening
**Practice:** Static pod management, certificate locations

#### **Audit Logging**
**Theory:** Audit policy levels, compliance requirements
**Labs:**
- ✅ [Audit Logs Configuration](../1_Labs/audit-logs.en.md) - Complete API server audit setup
- ✅ **Shell Solution:** `k8s-advanced/labs/1_internals/apiserver-auditlogs.sh`
  - Automated audit policy creation
  - API server manifest modification
  - Log analysis and verification

**Practice:** Audit log analysis, security event correlation

#### **Secrets & Encryption**
**Theory:** Kubernetes secrets, encryption at rest, external secret management
**Labs:**
- ✅ [Secrets Encryption at Rest](../1_Labs/kubebench-20-remediations.en.md#advanced-remediation-encryption-at-rest) - Covered in kube-bench remediations
  - etcd encryption configuration
  - Key rotation procedures

<span style="color: red;">**TODO:** Complete and translate secrets encryption lab:
- AES encryption setup with multiple providers
- External KMS integration concepts
- Secret rotation best practices
- HashiCorp Vault integration example</span>

### Afternoon Session

#### **Runtime Security & Monitoring**
**Theory:** Runtime threats, behavioral analysis, intrusion detection
**Labs:**
- ✅ [Falco Runtime Security](../1_Labs/falco.en.md) - Complete implementation
- ✅ **Shell Solution:** `k8s-advanced/labs/5_runtime_security/falco.sh`
  - Automated Falco installation and configuration
  - Custom rule creation (network tools, privilege escalation)
  - Alert correlation and response

**Practice:** Security rule tuning, incident response workflows

#### **Compliance & Hardening**
**Theory:** CIS benchmarks, compliance frameworks
**Labs:**
- ✅ [CIS Kubernetes Benchmark - Jobs](../1_Labs/kubebench-10-jobs.en.md) - kube-bench usage
- ✅ [CIS Kubernetes Benchmark - Remediations](../1_Labs/kubebench-20-remediations.en.md) - Security fixes
- ✅ [CIS Kubernetes Benchmark - Automation](../1_Labs/kubebench-30-automation.en.md) - Continuous compliance
  - Manual and automated scanning
  - Remediation examples
  - Continuous compliance monitoring

<span style="color: red;">**TODO:** Add comprehensive hardening labs:
- **kube-bench** - Complete automation script
- **AppArmor/SELinux profiles** - Pod-level security (TODO.CKS requirement)
- **seccomp profiles** - Custom profile creation and application
- **gVisor/Kata Containers** - Runtime class concepts (theory only per TODO.CKS)</span>

#### **Advanced Topics & Exam Preparation**

<span style="color: red;">**TODO:** Create admission controller labs:
- **OPA Gatekeeper policies** - But favor Kyverno (per TODO.CKS guidance)
- **Advanced Kyverno scenarios** - Policy-as-code examples
- **Custom admission webhooks** - Concepts and validation examples</span>

---

## Assessment & Practical Exercises

### **Security Incident Simulation**
**Scenario:** Multi-stage attack simulation
1. **Initial Access:** Exploit misconfigured RBAC
2. **Lateral Movement:** Network policy bypass attempts
3. **Persistence:** Privilege escalation via SecurityContext
4. **Detection:** Falco alerts and audit log analysis
5. **Response:** Containment and remediation

### **Exam-Style Challenges**
- Implement network micro-segmentation for multi-tenant environment
- Configure comprehensive audit logging with log forwarding
- Create custom Pod Security Standards for specific workload requirements
- Investigate security incidents using audit logs and runtime monitoring

---

## Learning Resources

### **Official Documentation**
- [Kubernetes Security Concepts](https://kubernetes.io/docs/concepts/security/)
- [Pod Security Standards](https://kubernetes.io/docs/concepts/security/pod-security-standards/)
- [CKS Curriculum](https://github.com/cncf/curriculum/blob/master/CKS_Curriculum_%20v1.28.pdf)

### **Additional Tools & Projects**
- [RBAC Tool](https://github.com/alcideio/rbac-tool) - RBAC visualization
- [Kubescape](https://github.com/kubescape/kubescape) - Security posture scanning
- [Falco Rules](https://github.com/falcosecurity/rules) - Community security rules
- [Kubernetes Network Policy Recipes](https://github.com/ahmetb/kubernetes-network-policy-recipes)

### **Security Frameworks**
- [CIS Kubernetes Benchmark](https://www.cisecurity.org/benchmark/kubernetes/)
- [NIST Cybersecurity Framework](https://www.nist.gov/cyberframework)
- [OWASP Kubernetes Security Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Kubernetes_Security_Cheat_Sheet.html)

---

## Important Notes

### **Based on TODO.CKS Guidelines:**
- ✅ **kube-bench** - Included with hands-on labs
- ✅ **seccomp/apparmor/selinux** - Marked as TODO for development
- ✅ **OPA Gatekeeper** - Limited coverage, prefer Kyverno (as recommended)
- ✅ **gVisor/Kata Containers** - Concept-only coverage (no installation labs)
- ✅ **ImagePolicyWebhook** - Concept explanation only (no hands-on per guidance)

### **Training Delivery Notes:**
- **Hands-on Focus:** 80% practical labs, 20% theory
- **Real-world Scenarios:** Security incident simulations
- **Exam Preparation:** Practice questions throughout
- **Tool Proficiency:** kubectl, bash scripting for automation
- **Flexible Scheduling:** Adjust timing based on group pace and experience level
- **Topic Prioritization:** Core CKS topics prioritized, optional content can be abbreviated if needed

### **Prerequisites for Trainers:**
- Access to Kind/Kubernetes clusters for each participant
- Shell scripts from `k8s-advanced` repository pre-configured
- Sample vulnerable applications for incident response scenarios

---

## Success Metrics

**By the end of this training, participants will:**
- ✅ **Implement comprehensive RBAC** for multi-tenant environments
- ✅ **Configure runtime security monitoring** with Falco
- ✅ **Design and enforce Pod Security Standards** across namespaces
- ✅ **Establish audit logging and analysis** workflows
- ✅ **Apply network security policies** for micro-segmentation
- ✅ **Perform security compliance scanning** with industry standards
- ✅ **Respond to security incidents** using Kubernetes-native tools
- ✅ **Pass the CKS certification exam** with confidence

**Estimated Pass Rate:** 85%+ for participants who complete all hands-on exercises

---

*Last updated: January 2026*
*Training materials version: 2.0*
*Compatible with Kubernetes 1.28+ and CKS exam v1.28*
