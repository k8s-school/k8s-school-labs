---
title: 'RBAC monitoring'
date: 2024-06-06T14:15:26+10:00
draft: false
weight: 70
tags: ["Kubernetes", "RBAC", "Authorization", "Monitoring", "Security", "CKA", "CKS"]
---

## Exercice: find RBAC security issue

Connect to Kubernetes:

```bash
# The shared kind cluster, prepared by the trainer
kubectx kind-kind
```

Somewhere in this cluster, a `ServiceAccount` has been granted far more power
than it needs. Find it.

Three tools are already installed on the training server:

| Tool | Try |
|---|---|
| [rakkess](https://github.com/corneliusweig/rakkess) | `rakkess` — or `kubectl access-matrix resource pods --verbs get` to see it per ServiceAccount |
| [kubescape](https://github.com/kubescape/kubescape) | `kubescape scan`, then drill into the administrative roles it counts: `kubescape scan control C-0035 -v` |
| [rbac-tool](https://github.com/alcideio/rbac-tool) | `rbac-tool who-can delete secrets` |

{{% notice tip %}}
`rbac-tool` is not preinstalled: get it with
`curl https://raw.githubusercontent.com/alcideio/rbac-tool/master/download.sh | bash`,
which downloads it into `./bin`.
{{% /notice %}}

Once you have found it, answer: which `ClusterRole` is bound, to which
`ServiceAccount`, and what could an attacker do with a pod running under it?
