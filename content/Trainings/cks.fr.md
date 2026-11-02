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

Les supports de cours et les travaux pratiques sont listés dans l'ordre de la formation. Les mêmes travaux pratiques, classés par domaine du programme CKS : [travaux pratiques CKS par domaine]({{% ref "/Certifications/cks-domains" %}}).

## 1. Fonctionnement interne du cluster

Supports : [E_01_advanced-k8s-cluster-internals.pdf](https://k8s-school.fr/labs/k8s/pdf/E_01_advanced-k8s-cluster-internals.pdf)

- [Kubelet and static pods on Kubernetes](https://k8s-school.fr/labs/k8s/en/1_labs/staticpod/index.html)
- [Encrypt Secrets at rest in etcd](https://k8s-school.fr/labs/k8s/en/1_labs/etcd-encryption/index.html)
- [etcd backup and restore](https://k8s-school.fr/labs/k8s/en/1_labs/etcd-backup/index.html) (sur OpenShift : [etcd administration](https://k8s-school.fr/labs/k8s/en/1_labs/openshift-etcd/index.html))
- Bonus, le formateur peut installer le cluster : [Kubernetes easy install with Kubeadm](https://k8s-school.fr/labs/k8s/en/1_labs/kubeadm/index.html)
- [Upgrade a cluster with kubeadm](https://k8s-school.fr/labs/k8s/en/1_labs/kubeadm-upgrade/index.html)

## 2. RBAC

Supports : [E_02_advanced-k8s_RBAC.pdf](https://k8s-school.fr/labs/k8s/pdf/E_02_advanced-k8s_RBAC.pdf)

- [Kubectl proxy and curl](https://k8s-school.fr/labs/k8s/en/1_labs/kubectl-proxy/index.html)
- [RBAC](https://k8s-school.fr/labs/k8s/en/1_labs/rbac/index.html)
- Exercice RBAC 2, ClusterRole sur les PersistentVolumes : [solution](https://github.com/k8s-school/k8s-advanced/blob/master/labs/2_authorization/3_RBAC_clusterrole.sh)
- [RBAC monitoring](https://k8s-school.fr/labs/k8s/en/1_labs/rbac-secissue/index.html)
- Bonus : [Kubernetes Service Account Token Lab](https://k8s-school.fr/labs/k8s/en/1_labs/service-account/index.html)

## 3. Sécurité des nœuds et du réseau

Supports : [E_03_advanced-k8s_Security_node+network.pdf](https://k8s-school.fr/labs/k8s/pdf/E_03_advanced-k8s_Security_node+network.pdf)

- [Security context](https://k8s-school.fr/labs/k8s/en/1_labs/security-context/index.html)
- [Pod Security Admission](https://k8s-school.fr/labs/k8s/en/1_labs/pod-security-admission/index.html)
- [NetworkPolicy](https://k8s-school.fr/labs/k8s/en/1_labs/networkpolicy/index.html)

## 4. Ingress

Supports : [D_01_Ingress.pdf](https://k8s-school.fr/labs/k8s/pdf/D_01_Ingress.pdf)

- [Ingress with TLS](https://k8s-school.fr/labs/k8s/en/1_labs/ingress-tls/index.html)

## 5. Durcissement, sécurité à l'exécution et chaîne d'approvisionnement

Supports : [CKS.pdf](https://k8s-school.fr/labs/k8s/pdf/CKS.pdf)

Configuration et durcissement du cluster :

- [Hardening with CIS Benchmarks - Running kube-bench Jobs](https://k8s-school.fr/labs/k8s/en/1_labs/kubebench-10-jobs/index.html)
- [Hardening with CIS Benchmarks - Security Remediations](https://k8s-school.fr/labs/k8s/en/1_labs/kubebench-20-remediations/index.html)
- Bonus : [Hardening with CIS Benchmarks - Automation and Continuous Compliance](https://k8s-school.fr/labs/k8s/en/1_labs/kubebench-30-automation/index.html)

Audit, supervision et journalisation :

- [Audit Logs & API Server](https://k8s-school.fr/labs/k8s/en/1_labs/audit-logs/index.html)
- [Runtime Security with Falco](https://k8s-school.fr/labs/k8s/en/1_labs/falco/index.html)

Durcissement du système :

- [Seccomp Security Profiles](https://k8s-school.fr/labs/k8s/en/1_labs/seccomp/index.html)
- Bonus : [AppArmor Security Profiles](https://k8s-school.fr/labs/k8s/en/1_labs/apparmor/index.html)
- Bonus : [Sandboxed containers with gVisor and RuntimeClass](https://k8s-school.fr/labs/k8s/en/1_labs/gvisor/index.html), couvre aussi la vérification des binaires avec `sha512sum`

Sécurité de la chaîne d'approvisionnement :

- [Trivy: Container Vulnerability Scanning](https://k8s-school.fr/labs/k8s/en/1_labs/trivy/index.html), dont la génération de SBOM
- [Cosign: Container Image Signing & Verification](https://k8s-school.fr/labs/k8s/en/1_labs/cosign/index.html)
- Bonus : [Allowed registries with a ValidatingAdmissionPolicy](https://k8s-school.fr/labs/k8s/en/1_labs/allowed-registries/index.html)

## 6. Bonus : ressources de calcul

Hors du programme CKS, mais les quotas et les LimitRanges protègent le cluster contre un namespace qui consomme toutes les ressources (déni de service).

Supports : [E_04_advanced-k8s_computational_resources.pdf](https://k8s-school.fr/labs/k8s/pdf/E_04_advanced-k8s_computational_resources.pdf)

- ResourceQuotas et LimitRanges : [scripts](https://github.com/k8s-school/k8s-advanced/tree/master/labs/4_computational_resources)

## Préparation à l'examen

Toutes les pages de la section [Certifications]({{% ref "/Certifications" %}}), dont :

- [CKS : compétences nécessaires](https://k8s-school.fr/labs/k8s/en/certifications/cks_curriculum/index.html)
- [Trucs et astuces]({{% ref "/Certifications/tipsandtricks" %}})

Pour s'entraîner sur un environnement proche de l'examen (cluster kubeadm, ssh vers les nœuds) : les scénarios CKS gratuits de [Killercoda](https://killercoda.com/killer-shell-cks).
