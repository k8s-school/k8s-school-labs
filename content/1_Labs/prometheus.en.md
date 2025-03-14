---
title: Monitoring with Prometheus
date: 2025-02-20T14:15:26+10:00
draft: false
weight: 20
tags: ["Kubernetes", "monitoring", "prometheus"]
---

**Author:** Fabrice JAMMES ([LinkedIn](https://www.linkedin.com/in/fabrice-jammes-5b29b042/)).

## Prerequisites

```bash
# Launch the toolbox
ktbx desk

# Check your use kind-kind context
kubectx

#Launch initialization script
/home/k8s0/openshift-advanced/labs/3_policies/ex4-network.sh

# go to correct namespace
kubens network-k8s<ID>
```


# Kubernetes Monitoring Lab with Helm

## Objective
The goal of this lab is to deploy the Prometheus Stack using Helm while following best practices in shell scripting.

## Prerequisites
Ensure you have the following installed:
- Kubernetes cluster (e.g., Minikube, Kind, or a cloud-managed cluster)
- `kubectl` configured to access the cluster
- `helm` installed
- `bash` shell

## Steps to Deploy Prometheus Stack

{{% notice note %}}
The Prometheus installation is completed before the lab; the following instructions are for reference only.
{{% /notice %}}

### Install Prometheus Stack
```bash
git clone https://github.com/k8s-school/demo-prometheus
cd demo-prometheus
./install.sh
```

### 6. Access Prometheus and Grafana

Once the deployment is complete, follow these exercises to interact with the monitoring stack:

1. **Watch all pods in the monitoring namespace:**

{{%expand "Answer" %}}
```bash
kubectl get pods -n monitoring --watch
```
{{% /expand%}}

2. **Retrieve Grafana password:**

{{%expand "Answer" %}}
```bash
helm show values prometheus-community/kube-prometheus-stack | grep adminPassword
```
{{% /expand%}}

3. **Port forward Prometheus web UI to access it in a web browser:**

{{%expand "Answer" %}}
```bash
kubectl port-forward -n monitoring prometheus-prometheus-stack-kube-prom-prometheus-0 9090
```

Eventually create a ssh tunnel if Kubernetes is secured behing a ssh bastion.

Then open your browser and go to: [http://localhost:9090](http://localhost:9090)
{{% /expand%}}

Check the metrics and the alert rules.

4. **Port forward Grafana to access it in a web browser:**

Retrieve the Grafana port using `kubectl get svc ...`.

{{%expand "Answer" %}}
```bash
kubectl port-forward svc/prometheus-stack-grafana -n monitoring 808<ID>:80
```

Eventually create a ssh tunnel if Kubernetes is secured behing a ssh bastion.

Then open your browser and go to: [http://localhost:808<ID>](http://localhost:808<ID>)
{{% /expand%}}

Check the Kubernetes dashboards.

## Conclusion
This lab guides you through deploying a monitoring stack using Helm and Kubernetes, allowing you to explore Prometheus and Grafana for cluster monitoring.

The prometheus demo is available here: [https://github.com/k8s-school/demo-prometheus](https://github.com/k8s-school/demo-prometheus)
