---
title: 'Formation CKS'
date: 2026-10-16T08:00:00+02:00
draft: false
weight: 105
tags: ["kubernetes", "labs", "pre-requis", "CKS", "sécurité"]
---

Formation de deux jours pour préparer la certification **Certified Kubernetes Security Specialist (CKS)**.

{{% notice info %}}
La certification CKA est obligatoire pour passer l'examen CKS.
{{% /notice %}}

{{% notice note %}}
Les travaux pratiques sont rédigés en anglais.
{{% /notice %}}

## Supports de cours

- [CKS.pdf](https://k8s-school.fr/labs/k8s/pdf/CKS.pdf)
- [E_01_advanced-k8s-cluster-internals.pdf](https://k8s-school.fr/labs/k8s/pdf/E_01_advanced-k8s-cluster-internals.pdf)
- [E_02_advanced-k8s_RBAC.pdf](https://k8s-school.fr/labs/k8s/pdf/E_02_advanced-k8s_RBAC.pdf)
- [E_03_advanced-k8s_Security_node+network.pdf](https://k8s-school.fr/labs/k8s/pdf/E_03_advanced-k8s_Security_node+network.pdf)
- [E_04_advanced-k8s_computational_resources.pdf](https://k8s-school.fr/labs/k8s/pdf/E_04_advanced-k8s_computational_resources.pdf)
- [D_01_Ingress.pdf](https://k8s-school.fr/labs/k8s/pdf/D_01_Ingress.pdf)

## Travaux pratiques par module

### 1. Configuration du cluster (15 %)

Network policies, benchmark CIS, Ingress avec TLS, protection des métadonnées des nœuds, vérification des binaires.

- [NetworkPolicy](https://k8s-school.fr/labs/k8s/en/1_labs/networkpolicy/index.html)
- [Hardening with CIS Benchmarks - Running kube-bench Jobs](https://k8s-school.fr/labs/k8s/en/1_labs/kubebench-10-jobs/index.html)
- [Hardening with CIS Benchmarks - Security Remediations](https://k8s-school.fr/labs/k8s/en/1_labs/kubebench-20-remediations/index.html)
- [Hardening with CIS Benchmarks - Automation and Continuous Compliance](https://k8s-school.fr/labs/k8s/en/1_labs/kubebench-30-automation/index.html)
- Démo d'un contrôleur Ingress (slides `D_01_Ingress`) : [nginx-controller-example](https://github.com/k8s-school/nginx-controller-example)

### 2. Durcissement du cluster (15 %)

RBAC, service accounts, restriction de l'accès à l'API, mises à jour de Kubernetes.

- [Kubectl proxy and curl](https://k8s-school.fr/labs/k8s/en/1_labs/kubectl-proxy/index.html)
- [RBAC](https://k8s-school.fr/labs/k8s/en/1_labs/rbac/index.html)
- [RBAC monitoring](https://k8s-school.fr/labs/k8s/en/1_labs/rbac-secissue/index.html)
- Bonus : [Kubernetes Service Account Token Lab](https://k8s-school.fr/labs/k8s/en/1_labs/service-account/index.html)
- Exercice RBAC 2, ClusterRole sur les PersistentVolumes (slides `E_02`) : [solution](https://github.com/k8s-school/k8s-advanced/blob/master/labs/2_authorization/3_RBAC_clusterrole.sh)
- Mise à jour avec kubeadm (slides `E_01`) : [consignes](https://github.com/k8s-school/k8s-advanced/blob/master/labs/0_kubeadm/exercice-kubeadm.md)

### 3. Durcissement du système (10 %)

Empreinte de l'OS hôte, IAM au moindre privilège, accès réseau externe, outils de durcissement du noyau (AppArmor, seccomp).

- [Seccomp Security Profiles](https://k8s-school.fr/labs/k8s/en/1_labs/seccomp/index.html)
- [AppArmor Security Profiles](https://k8s-school.fr/labs/k8s/en/1_labs/apparmor/index.html)

### 4. Réduction des vulnérabilités des microservices (20 %)

Pod Security Standards, gestion des secrets, techniques d'isolation (multi-tenancy, conteneurs sandboxés), chiffrement entre pods (Cilium, Istio).

- [Security context](https://k8s-school.fr/labs/k8s/en/1_labs/security-context/index.html) (slides `E_03`)
- [Pod Security Admission](https://k8s-school.fr/labs/k8s/en/1_labs/pod-security-admission/index.html) (slides `E_03`)
- [Encrypt Secrets at rest in etcd](https://k8s-school.fr/labs/k8s/en/1_labs/etcd-encryption/index.html)
- RuntimeClass avec gVisor : démo dans les slides `CKS`

### 5. Sécurité de la chaîne d'approvisionnement (20 %)

Images de base minimales, SBOM et dépôts d'artefacts, registres autorisés, signature et validation des artefacts, analyse statique (Kubesec, KubeLinter).

- [Trivy: Container Vulnerability Scanning](https://k8s-school.fr/labs/k8s/en/1_labs/trivy/index.html), dont la génération de SBOM
- [Cosign: Container Image Signing & Verification](https://k8s-school.fr/labs/k8s/en/1_labs/cosign/index.html)

### 6. Supervision, journalisation et sécurité à l'exécution (20 %)

Analyse comportementale, détection et investigation des menaces, immutabilité des conteneurs, logs d'audit Kubernetes.

- [Audit Logs & API Server](https://k8s-school.fr/labs/k8s/en/1_labs/audit-logs/index.html)
- [Runtime Security with Falco](https://k8s-school.fr/labs/k8s/en/1_labs/falco/index.html)

## Autres travaux pratiques de la formation

### Fonctionnement interne du cluster

- [Kubelet and static pods on Kubernetes](https://k8s-school.fr/labs/k8s/en/1_labs/staticpod/index.html)

### Bonus : quotas et LimitRanges

Hors du programme CKS, mais ils protègent le cluster contre un namespace qui consomme toutes les ressources (déni de service).

- ResourceQuotas et LimitRanges (slides `E_04`) : [scripts](https://github.com/k8s-school/k8s-advanced/tree/master/labs/4_computational_resources)

## Préparation à l'examen

- [CKS : compétences nécessaires](https://k8s-school.fr/labs/k8s/en/certifications/cks_curriculum/index.html)
- [Trucs et astuces]({{% ref "/Certifications/tipsandtricks" %}})
