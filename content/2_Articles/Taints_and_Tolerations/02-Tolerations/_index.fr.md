+++
title = "Pod Tolerations"
date = 2020-03-07T17:15:52Z
weight = 2
chapter = false
pre = "<b>- </b>"
tags = ["Kubernetes", "Scheduler", "Tolerations"]
+++

Des  `Tolerations` peuvent être ajoutées aux pods (ou à la section `Pod template` des Daemonset, Replicaset, Deployment et Statefulset).
Sur la base des Taints apposées sur un nœud, le Scheduler Kubernetes ne permettra d'exécuter le pod sur ce nœud que s'il dispose des `Tolerations` correspondantes.

### Syntaxe des Tolerations dans les spécifications yaml des Pods.

```yaml
apiVersion: v1
kind: Pod
metadata:
...
spec:
  tolerations:
    - key: node-role.kubernetes.io/master
      effect: NoSchedule
```
{{% notice note %}}
Ici le champ `value` n'est pas spécifié: seul la clef sera utilisée pour faire la correspondance entre une `Taint` et une `Toleration`.
{{% /notice %}}