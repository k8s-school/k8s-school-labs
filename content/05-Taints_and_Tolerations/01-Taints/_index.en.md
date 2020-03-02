+++
menutitle = "Taints"
date = 2018-12-29T17:15:52Z
weight = 1
chapter = false
pre = "<b>- </b>"
+++

# Why we need Taints ?

Just like labels , one or more taints can be applied to a node; this marks that the node should not accept any pods that do not tolerate the taints

```shell
$ kubectl taint node k8s-master-ah-01 node-role.kubernetes.io/master="":NoSchedule
```

Format key=value:Effect

### Effects

`NoSchedule` - Pods will not be schedules

`PreferNoSchedule`- This is a “preference” or “soft” version of `NoSchedule` – the system will try to avoid placing a pod that does not tolerate the taint on the node, but it is not required. 

`NoExecute` - pod will be evicted from the node (if it is already running on the node), and will not be scheduled onto the node (if it is not yet running on the node)
