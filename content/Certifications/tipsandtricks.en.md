---
title: 'Tips and Tricks'
date: 2025-11-22T14:15:26+10:00
draft: false
weight: 20
tags: ["kubernetes", "CKA", "CKAD"]
---

# Before the Exam

## Important Instructions

- [Agree to Global Candidate Agreement](https://docs.linuxfoundation.org/tc-docs/certification/lf-cert-agreement)
- [Get Candidate Handbook](https://docs.linuxfoundation.org/tc-docs/certification/lf-handbook2)
- [Read the Important Instructions](https://docs.linuxfoundation.org/tc-docs/certification/important-instructions-cks)

![CKS Homepage](https://k8s-school.fr/labs/images/LF-CKS-homepage.png?width=20vw)

## System Compatibility Check

All information is on [this page of the Linux Foundation site](https://docs.linuxfoundation.org/tc-docs/certification/tips-cka-and-ckad), to be done a few days before the exam.

## Simulators:

- [Interactive online scenarios for CKA](https://killercoda.com/killer-shell-cka)
- [Interactive online scenarios for CKAD](https://killercoda.com/killer-shell-ckad)
- Two [Simulator](https://killer.sh/) sessions are offered with CKA and CKAD, they are more complex than the actual exams and provide excellent training.

## Documentation Access

For CKA and CKAD exams, you are allowed to use certain websites and documentation to search for terminology and find answers to your questions. Here are the authorized sites:

- [Official Kubernetes Documentation](https://kubernetes.io/docs)
- [Official Kubernetes Blog](https://kubernetes.io/blog)
- [Official Kubernetes Github](https://github.com/kubernetes)

Developing good knowledge of these documents can help you gain agility and speed during the exam. Additionally, these documents will help you develop a solid foundation in Kubernetes. Use these sites only to search for concepts and tools, and prepare your answers. Also learn to use the search functions effectively throughout the K8s documentation and bookmark all relevant and useful pages.

# On Exam Day

The commands described here will certainly be useful:

- [kubectl Quick Reference](https://kubernetes.io/docs/reference/kubectl/quick-reference/) from the official documentation (accessible during the exam)
- [Essential kubectl commands]({{% ref "/Articles/kubectl-essential" %}} "Essential kubectl commands")
- [Linux tips and tricks]({{% ref "/0_Prereqs/tipsandtricks" %}} "Linux tips and tricks")

## Contexts

It is recommended to use `kubectx` in production but this tool is not available during the exam. Here are the main context management commands to know:

```shell
# List contexts
kubectl config get-contexts
# Switch context
kubectl config set-context <context-name>
# Modify current context, here to work in namespace <my-namespace>
kubectl config set-context  --current --namespace <my-namespace>
```

## Pre-configuration

Once you have access to your terminal, it may be wise to spend about 1 minute configuring your environment. You can set these elements:

```shell
alias k=kubectl # will already be pre-configured

export do="--dry-run=client -o yaml"
# k get pod x $do

export now="--force --grace-period 0"
# k delete pod x $now
```

## Vim

For vim to use 2 spaces for a tab, edit `~/.vimrc` to add:

```
set tabstop=2
set expandtab
set shiftwidth=2
```