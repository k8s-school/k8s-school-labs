---
title: 'Audit Logs & API Server'
date: 2024-06-06T15:00:00+10:00
draft: false
weight: 30
tags: ["CKS", "Security", "Audit", "API-server", "Kubernetes", "Control-plane"]
---

## Objectives
Configure audit policies to trace modifications on critical resources and secure the API Server in a Kubernetes cluster.

## Prerequisites

Define your cluster name:

```bash
$CLUSTER_NAME="my-cluster"
```

### Q1: How to modify the API Server configuration?
{{%expand "Answer" %}}
The API Server in Kubernetes runs as a **static pod** managed by the kubelet. Static pods are defined by YAML manifests in the `/etc/kubernetes/manifests/` directory. When you modify a static pod manifest:

1. The kubelet automatically detects the file changes
2. It stops the current pod
3. It starts a new pod with the updated configuration

This means you don't need to manually restart the API Server - just modify the manifest file and kubelet handles the rest.

It might be faster it restart kubelet manually:

```bash
docker exec -it ${CLUSTER_NAME}-control-plane bash
systemctl restart kubelet
```

{{% /expand%}}

### Q2: How to backup the API Server manifest locally?
{{%expand "Answer" %}}
Since the API Server runs inside a kind container, use `docker cp` to backup the manifest to your local machine:

```bash
# Find your kind cluster name
kind get clusters

# Backup the manifest from container to local machine
docker cp ${CLUSTER_NAME}-control-plane:/etc/kubernetes/manifests/kube-apiserver.yaml ./kube-apiserver.yaml.backup

# To restore later (if needed)
docker cp ./kube-apiserver.yaml.backup ${CLUSTER_NAME}-control-plane:/etc/kubernetes/manifests/kube-apiserver.yaml
```
{{% /expand%}}

### Q3: How to connect to the kind control plane node?
{{%expand "Answer" %}}
Use `docker exec` to access the kind control plane container:

```bash
# List running kind containers
docker ps | grep control-plane

# Connect to the control plane container
docker exec -it ${CLUSTER_NAME}-control-plane bash

# You're now inside the container and can access:
# - /etc/kubernetes/manifests/ (static pod manifests)
# - /var/log/kubernetes/ (log files)
# - /etc/kubernetes/pki/ (certificates)
```
{{% /expand%}}

### Setup Commands
```bash
# Find your kind cluster name (if you have multiple clusters)
kind get clusters

# Access the kind control plane container
docker exec -it ${CLUSTER_NAME}-control-plane bash

```

## Configure the Audit Policy

Create a file `/etc/kubernetes/audit-policy.yaml` that logs:

* Requests on `Secrets` at `Metadata` level.
* Requests on `Pods` at `RequestResponse` level.

{{%expand "Solution" %}}

```bash
# Create the audit policy file inside the kind container
cat > /etc/kubernetes/audit-policy.yaml <<EOF
apiVersion: audit.k8s.io/v1
kind: Policy
rules:
- level: Metadata
  resources:
  - group: ""
    resources: ["secrets"]
- level: RequestResponse
  resources:
  - group: ""
    resources: ["pods"]
EOF
```

{{% /expand%}}

## Enable audit in the API Server

Configure `/etc/kubernetes/manifests/kube-apiserver.yaml` to enable audit logs

{{%expand "Solution" %}}

Use this step-by-step approach to add audit configuration:

**Add to command flags:**
```yaml
- --audit-policy-file=/etc/kubernetes/audit-policy.yaml
- --audit-log-path=/var/log/kubernetes/audit.log
- --audit-log-maxsize=10
```

**Add to volumeMounts:**
```yaml
- mountPath: /etc/kubernetes/audit-policy.yaml
  name: audit-policy
  readOnly: true
- mountPath: /var/log/kubernetes
  name: audit-logs
```

**Add to volumes:**
```yaml
- hostPath:
    path: /etc/kubernetes/audit-policy.yaml
    type: File
  name: audit-policy
- hostPath:
    path: /var/log/kubernetes
    type: DirectoryOrCreate
  name: audit-logs
```

{{% /expand%}}

## Verify Audit Configuration

To verify your audit configuration is working correctly:

```bash
# Check if audit policy file exists
ls -la /etc/kubernetes/audit-policy.yaml

# Verify API server manifest has audit flags
grep -A3 "audit" /etc/kubernetes/manifests/kube-apiserver.yaml

# Check audit log directory exists
ls -la /var/log/kubernetes/

# Count audit log entries
wc -l /var/log/kubernetes/audit.log 2>/dev/null || echo "No audit log file found"
```

## Test the Audit Configuration

```bash
# Create a test secret to generate audit logs
kubectl create secret generic test-secret --from-literal=key=value

# Create a test pod to generate audit logs (use --restart=Never to avoid issues)
kubectl run test-pod --image=nginx --restart=Never

# Wait a moment for logs to be written
sleep 3
```

Then access audit logs content on the control-plane.

{{%expand "Solution" %}}

```bash
# Check if audit log file exists and has content
ls -la /var/log/kubernetes/audit.log

# Check for secret-related audit entries
grep "secrets" /var/log/kubernetes/audit.log | head -2

# Check for pod-related audit entries
grep "pods" /var/log/kubernetes/audit.log | head -2

# View recent audit logs in JSON format (if jq is available)
tail -10 /var/log/kubernetes/audit.log | jq . || tail -10 /var/log/kubernetes/audit.log

# Clean up test resources
kubectl delete secret test-secret --ignore-not-found=true
kubectl delete pod test-pod --ignore-not-found=true
```

{{% /expand%}}

## Troubleshooting

### API Server Won't Start After Modification

If the API server fails to start after modifying the manifest, here are comprehensive debugging steps:

#### Check Kubelet Logs
```bash
# From inside the kind control plane container
docker exec -it ${CLUSTER_NAME}-control-plane journalctl -u kubelet | grep -i kube-apiserver

# Look for specific error patterns
docker exec -it ${CLUSTER_NAME}-control-plane journalctl -u kubelet | grep -E "(error|failed|couldn't parse)"

# Follow kubelet logs in real-time
docker exec -it ${CLUSTER_NAME}-control-plane journalctl -u kubelet -f
```

#### Check Container Runtime Status
```bash
# Check API server container status using crictl
docker exec -it ${CLUSTER_NAME}-control-plane crictl ps -a | grep kube-apiserver

# Get detailed container info
docker exec -it ${CLUSTER_NAME}-control-plane crictl inspect <container-id>

# Check container logs directly
docker exec -it ${CLUSTER_NAME}-control-plane crictl logs <container-id>

# List all pods in kube-system namespace
docker exec -it ${CLUSTER_NAME}-control-plane crictl pods | grep kube-system
```

#### Common Error Patterns and Solutions

**YAML Parsing Errors:**
```bash
# Check for YAML syntax errors
python3 -c "import yaml; yaml.safe_load(open('/etc/kubernetes/manifests/kube-apiserver.yaml'))"

# If YAML is invalid, restore from backup
docker cp ./kube-apiserver.yaml.backup ${CLUSTER_NAME}-control-plane:/etc/kubernetes/manifests/kube-apiserver.yaml
```

**File Permission Issues:**
```bash
# Check audit policy file permissions
ls -la /etc/kubernetes/audit-policy.yaml

# Fix permissions if needed
chmod 644 /etc/kubernetes/audit-policy.yaml
chown root:root /etc/kubernetes/audit-policy.yaml
```