+++
title = "Taints"
date = 2020-03-07T17:15:52Z
weight = 2
chapter = false
pre = "<b>- </b>"
+++

# Add Taints to nodes

To make it simple, adding a taint to a node is like adding a bad smell to this node. Only pods that tolerate that bad smell can be scheduled on the node.

Just like labels, one or more taints can be applied to a node; this marks that the node should not accept any pods that do not tolerate the taints.

```shell
$ kubectl taint node k8s-master-ah-01 node-role.kubernetes.io/master="":NoSchedule
```

Format key=value:Effect

### Effects

`NoSchedule` - Pods will not be scheduled on this node. This is a strong constraint for the Kubernetes scheduler.

`PreferNoSchedule`- The kubernetes scheduler will avoid placing a pod that does not tolerate the taint on the node, but it is not required. This is a “soft” constraint for the Kubernetes scheduler.

`NoExecute` - Pod will be evicted from the node (if already running on the node), or won't be scheduled onto the node (if not yet running on the node). This is a strong constraint for the Kubernetes scheduler.
