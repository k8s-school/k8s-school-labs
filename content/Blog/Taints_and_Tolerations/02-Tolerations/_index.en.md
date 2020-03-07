+++
menutitle = "Tolerations"
date = 2020-03-07T17:15:52Z
weight = 2
chapter = false
pre = "<b>- </b>"
+++

# Add Tolerations to pods

Tolerations can be added to pods, or pod templates (for Daemonset, Replicaset, Deployment and Statefulset).
Based on the taints on a node, the Kubernetes scheduler will allow to run the Pod on this node if it has the corresponding tolerations.

Toleration syntax in Pod spec.

```yaml
spec:
  tolerations:
    - key: node-role.kubernetes.io/master
      effect: NoSchedule
```