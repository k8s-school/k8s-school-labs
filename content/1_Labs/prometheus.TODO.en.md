---
title: Monitoring with Prometheus'
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

### Create Namespace
```bash
NS="monitoring"
kubectl create namespace "$NS"
kubectl label ns "$NS" "name=$NS"
```

### Add and Update Helm Repositories
```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts || echo "Unable to add repo prometheus-community"
helm repo add stable https://charts.helm.sh/stable --force-update
helm repo update
```

### Install Prometheus Stack
```bash
helm install --version "69.3.0" prometheus-stack prometheus-community/kube-prometheus-stack -n "$NS"  -f "$DIR"/values.yaml --create-namespace
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

3. **Port forward Grafana to access it in a web browser:**
  {{%expand "Answer" %}}
   ```bash
   kubectl port-forward svc/prometheus-stack-grafana -n monitoring 3000:3000
   ```
   Then open your browser and go to: [http://localhost:3000](http://localhost:3000)
  {{% /expand%}}

### Cleanup

To remove the deployed stack:
```bash
helm delete prometheus-stack -n "$NS"
kubectl delete namespace "$NS"
```

## Conclusion
This lab guides you through deploying a monitoring stack using Helm and Kubernetes, allowing you to explore Prometheus and Grafana for cluster monitoring.


