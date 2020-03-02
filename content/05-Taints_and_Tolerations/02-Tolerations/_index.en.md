+++
menutitle = "Tolerations"
date = 2018-12-29T17:15:52Z
weight = 2
chapter = false
pre = "<b>- </b>"
+++

# Why we need Tolerations ?

Tolerations can be specified on Pods
Based on the taints on the nodes , Pods will scheduler will allow to run the Pod on the node.

Toleration syntax in Pod spec.

```yaml
spec:
  tolerations:
    - key: node-role.kubernetes.io/master
      effect: NoSchedule
```