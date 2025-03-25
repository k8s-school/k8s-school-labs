---
title: 'Infrastructure pod'
date: 2025-02-20T14:15:26+10:00
draft: false
weight: 20
tags: ["Kubernetes", "infrastructure pod", "crictl"]
---

**Author:** Fabrice JAMMES ([LinkedIn](https://www.linkedin.com/in/fabrice-jammes-5b29b042/))

## Task
Follow the steps below to investigate the relationship between Kubernetes pods and containers:

### Connect to a Kind node

{{%expand "Answer" %}}
- Run `docker ps` to find the Kind node name.
- Use `docker exec -it <kind-node-name> bash` to enter the container.
```bash
docker exec -it <kind-node-name> bash
```
{{% /expand%}}

### Use `crictl` to list pods and containers:

{{%expand "Answer" %}}
- `crictl ps -a` lists all containers.
- `crictl pods` shows running pods.
```bash
crictl ps -a
crictl pods
```
{{% /expand%}}

### Investigate the relationship between a pod and its container(s):

{{%expand "Answer" %}}
- `crictl inspect <container-id>` provides container details.
- `ps auxf` shows process hierarchy.

```bash
crictl inspect <container-id>
crictl inspectp <pod-id>
ps auxf
```
{{% /expand%}}

###  What is the role of the **"pause"** process?

{{%expand "Answer" %}}
- The "pause" container acts as the parent container for all other containers in a pod.
- It holds the network namespace and ensures pod lifecycle consistency.
{{% /expand%}}

### Explore the directories `/var/log` and `/var/lib/kubelet`.

{{%expand "Answer" %}}
- `/var/log`: Contains logs from Kubernetes components and container runtime.
- `/var/lib/kubelet/pods`: Stores pod data, volume mounts, and container runtime state
{{% /expand%}}

## Conclusion
This lab guides you through a better understanding of pod technical architecture.


