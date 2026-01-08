---
title: 'Audit Logs & API Server'
date: 2024-06-06T15:00:00+10:00
draft: false
weight: 30
tags: ["CKS", "Security", "Audit"]
---

## Objectives
Configure an audit policy to trace modifications on critical resources and secure the API Server in a kind cluster.

## Prerequisites

### Q1: How to modify the API Server configuration?
{{%expand "Answer" %}}
The API Server in Kubernetes runs as a **static pod** managed by the kubelet. Static pods are defined by YAML manifests in the `/etc/kubernetes/manifests/` directory. When you modify a static pod manifest:

1. The kubelet automatically detects the file changes
2. It stops the current pod
3. It starts a new pod with the updated configuration

This means you don't need to manually restart the API Server - just modify the manifest file and kubelet handles the rest.
{{% /expand%}}

### Q2: How to backup the API Server manifest locally?
{{%expand "Answer" %}}
Since the API Server runs inside a kind container, use `docker cp` to backup the manifest to your local machine:

```bash
# Find your kind cluster name
kind get clusters

# Backup the manifest from container to local machine
docker cp <cluster-name>-control-plane:/etc/kubernetes/manifests/kube-apiserver.yaml ./kube-apiserver.yaml.backup

# To restore later (if needed)
docker cp ./kube-apiserver.yaml.backup <cluster-name>-control-plane:/etc/kubernetes/manifests/kube-apiserver.yaml
```
{{% /expand%}}

### Q3: How to connect to the kind control plane node?
{{%expand "Answer" %}}
Use `docker exec` to access the kind control plane container:

```bash
# List running kind containers
docker ps | grep control-plane

# Connect to the control plane container
docker exec -it <cluster-name>-control-plane bash

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
docker exec -it <kind-cluster-name>-control-plane bash

# Alternative: If you have only one kind cluster
docker exec -it $(docker ps --filter "name=control-plane" --format "{{.Names}}") bash

# Backup the API Server manifest inside the container
cp /etc/kubernetes/manifests/kube-apiserver.yaml /tmp/kube-apiserver.yaml.bak

# Also backup locally (recommended)
# From your host machine:
docker cp <kind-cluster-name>-control-plane:/etc/kubernetes/manifests/kube-apiserver.yaml ./kube-apiserver.yaml.backup

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

Modify `/etc/kubernetes/manifests/kube-apiserver.yaml` to point to the policy.

{{%expand "Solution" %}}

Use this step-by-step approach to add audit configuration:

**Method 1: Using Python for Safe YAML Modification (Recommended)**

```bash
# Backup the original manifest
cp /etc/kubernetes/manifests/kube-apiserver.yaml /tmp/kube-apiserver.yaml.backup

# Create logs directory
mkdir -p /var/log/kubernetes

# Use Python to safely modify the YAML manifest
python3 << 'EOF'
import yaml
import sys

try:
    # Read the backup file
    with open('/tmp/kube-apiserver.yaml.backup', 'r') as f:
        data = yaml.safe_load(f)

    # Add audit command flags
    container = data['spec']['containers'][0]
    audit_flags = [
        '--audit-policy-file=/etc/kubernetes/audit-policy.yaml',
        '--audit-log-path=/var/log/kubernetes/audit.log',
        '--audit-log-maxsize=10'
    ]

    # Only add flags that aren't already present
    for flag in audit_flags:
        flag_name = flag.split('=')[0]
        if not any(cmd.startswith(flag_name) for cmd in container['command']):
            container['command'].append(flag)

    # Add audit volume mounts
    audit_mounts = [
        {'mountPath': '/etc/kubernetes/audit-policy.yaml', 'name': 'audit-policy', 'readOnly': True},
        {'mountPath': '/var/log/kubernetes', 'name': 'audit-logs'}
    ]

    for mount in audit_mounts:
        if not any(vm.get('name') == mount['name'] for vm in container.get('volumeMounts', [])):
            container.setdefault('volumeMounts', []).append(mount)

    # Add audit volumes
    audit_volumes = [
        {'hostPath': {'path': '/etc/kubernetes/audit-policy.yaml', 'type': 'File'}, 'name': 'audit-policy'},
        {'hostPath': {'path': '/var/log/kubernetes', 'type': 'DirectoryOrCreate'}, 'name': 'audit-logs'}
    ]

    for volume in audit_volumes:
        if not any(v.get('name') == volume['name'] for v in data['spec'].get('volumes', [])):
            data['spec'].setdefault('volumes', []).append(volume)

    # Clean up runtime metadata to make it suitable for static manifest
    runtime_fields = ['creationTimestamp', 'resourceVersion', 'uid', 'generation', 'ownerReferences']
    for field in runtime_fields:
        data['metadata'].pop(field, None)

    # Remove status section if it exists
    data.pop('status', None)

    # Write the modified file with proper YAML formatting
    with open('/tmp/kube-apiserver-work.yaml', 'w') as f:
        yaml.dump(data, f, default_flow_style=False, width=1000, indent=2, sort_keys=False)

    print("✓ Python YAML modification completed successfully")

except Exception as e:
    print(f"✗ Error modifying YAML: {e}")
    sys.exit(1)
EOF

# Verify the result
echo "=== Verifying generated manifest ==="
echo "Audit flags: $(grep -c "audit-policy-file" /tmp/kube-apiserver-work.yaml)"
echo "Audit mounts: $(grep -c "audit-policy" /tmp/kube-apiserver-work.yaml)"

# Validate YAML syntax
if python3 -c "import yaml; yaml.safe_load(open('/tmp/kube-apiserver-work.yaml'))" 2>/dev/null; then
    echo "✓ Generated manifest is valid YAML"

    # Apply the modified manifest
    cp /tmp/kube-apiserver-work.yaml /etc/kubernetes/manifests/kube-apiserver.yaml
    echo "Applied modified manifest"

    # Force kubelet to notice the change
    touch /etc/kubernetes/manifests/kube-apiserver.yaml
else
    echo "✗ Generated manifest has YAML errors"
    exit 1
fi

# Wait for API server to restart (can take 30-60 seconds)
echo "Waiting for API server to restart..."
until kubectl get nodes >/dev/null 2>&1; do
    echo -n "."
    sleep 2
done
echo "API server restarted successfully"
```

**Method 2: Automated Script (Easiest)**

```bash
# Download and run the test-audit-logs.sh script
curl -O https://raw.githubusercontent.com/k8s-school/k8s-school-labs/master/test-audit-logs.sh
chmod +x test-audit-logs.sh
./test-audit-logs.sh
```

Alternatively, manually add these lines to the kube-apiserver manifest:

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

## Test the Audit Configuration

```bash
# Create a test secret to generate audit logs
kubectl create secret generic test-secret --from-literal=key=value

# Create a test pod to generate audit logs (use --restart=Never to avoid issues)
kubectl run test-pod --image=nginx --restart=Never

# Wait a moment for logs to be written
sleep 3

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

## Troubleshooting

### API Server Won't Start After Modification

If the API server fails to start after modifying the manifest, here are comprehensive debugging steps:

#### Check Kubelet Logs
```bash
# From inside the kind control plane container
docker exec -it <cluster-name>-control-plane journalctl -u kubelet | grep -i kube-apiserver

# Look for specific error patterns
docker exec -it <cluster-name>-control-plane journalctl -u kubelet | grep -E "(error|failed|couldn't parse)"

# Follow kubelet logs in real-time
docker exec -it <cluster-name>-control-plane journalctl -u kubelet -f
```

#### Check Container Runtime Status
```bash
# Check API server container status using crictl
docker exec -it <cluster-name>-control-plane crictl ps -a | grep kube-apiserver

# Get detailed container info
docker exec -it <cluster-name>-control-plane crictl inspect <container-id>

# Check container logs directly
docker exec -it <cluster-name>-control-plane crictl logs <container-id>

# List all pods in kube-system namespace
docker exec -it <cluster-name>-control-plane crictl pods | grep kube-system
```

#### Common Error Patterns and Solutions

**YAML Parsing Errors:**
```bash
# Check for YAML syntax errors
python3 -c "import yaml; yaml.safe_load(open('/etc/kubernetes/manifests/kube-apiserver.yaml'))"

# If YAML is invalid, restore from backup
cp /tmp/kube-apiserver.yaml.bak /etc/kubernetes/manifests/kube-apiserver.yaml
```

**File Permission Issues:**
```bash
# Check audit policy file permissions
ls -la /etc/kubernetes/audit-policy.yaml

# Fix permissions if needed
chmod 644 /etc/kubernetes/audit-policy.yaml
chown root:root /etc/kubernetes/audit-policy.yaml
```

**Volume Mount Issues:**
```bash
# Check if audit log directory exists
ls -la /var/log/kubernetes/

# Create directory if missing
mkdir -p /var/log/kubernetes
chmod 755 /var/log/kubernetes
```

#### Recovery Methods

**Method 1: Restore from Internal Backup**
```bash
# If you created a backup inside the container
cp /tmp/kube-apiserver.yaml.bak /etc/kubernetes/manifests/kube-apiserver.yaml

# Wait for API server to restart
until kubectl get nodes >/dev/null 2>&1; do
    echo -n "."
    sleep 2
done
```

**Method 2: Restore from External Backup**
```bash
# From your host machine
docker cp ./kube-apiserver.yaml.backup <cluster-name>-control-plane:/etc/kubernetes/manifests/kube-apiserver.yaml

# Force kubelet to notice the change
docker exec <cluster-name>-control-plane touch /etc/kubernetes/manifests/kube-apiserver.yaml
```

### No Audit Logs Generated

If audit logs are not being created after successful API server restart:

#### Verify Configuration
```bash
# 1. Check if audit policy file exists and is readable
ls -la /etc/kubernetes/audit-policy.yaml
cat /etc/kubernetes/audit-policy.yaml

# 2. Verify API server process has audit flags
docker exec -it <cluster-name>-control-plane ps aux | grep kube-apiserver | grep audit

# 3. Check if log directory exists and has correct permissions
ls -la /var/log/kubernetes/

# 4. Check API server container logs for audit-related errors
docker exec -it <cluster-name>-control-plane crictl logs $(docker exec <cluster-name>-control-plane crictl ps | grep kube-apiserver | awk '{print $1}')
```

#### Test Audit Functionality
```bash
# Create test resources to generate audit events
kubectl create secret generic test-audit-secret --from-literal=key=value
kubectl run test-audit-pod --image=nginx --restart=Never

# Wait and check for audit logs
sleep 3
ls -la /var/log/kubernetes/audit.log

# Check log content
grep "secrets" /var/log/kubernetes/audit.log | wc -l
grep "pods" /var/log/kubernetes/audit.log | wc -l

# Clean up
kubectl delete secret test-audit-secret --ignore-not-found=true
kubectl delete pod test-audit-pod --ignore-not-found=true
```

#### Check Volume Mounts
```bash
# Verify volume mounts are correctly configured
kubectl get pod -n kube-system -l component=kube-apiserver -o yaml | grep -A10 -B5 audit

# Check if volumes are properly mounted inside the container
docker exec -it <cluster-name>-control-plane ls -la /etc/kubernetes/audit-policy.yaml
docker exec -it <cluster-name>-control-plane ls -la /var/log/kubernetes/
```

### Debug API Server Startup Issues

#### Container Runtime Debugging
```bash
# Get detailed information about API server container
CONTAINER_ID=$(docker exec <cluster-name>-control-plane crictl ps | grep kube-apiserver | awk '{print $1}')

# Check container configuration
docker exec -it <cluster-name>-control-plane crictl inspect $CONTAINER_ID

# Check container mounts
docker exec -it <cluster-name>-control-plane crictl inspect $CONTAINER_ID | grep -A20 -B5 mounts

# Check container logs with timestamps
docker exec -it <cluster-name>-control-plane crictl logs -t $CONTAINER_ID
```

#### Manual Validation Before Applying
```bash
# Validate manifest before applying
python3 << 'EOF'
import yaml
try:
    with open('/tmp/kube-apiserver-work.yaml', 'r') as f:
        data = yaml.safe_load(f)
    print("✓ YAML is valid")

    # Check for required audit configuration
    container = data['spec']['containers'][0]
    has_audit_flags = any('audit-policy-file' in cmd for cmd in container['command'])
    has_audit_mounts = any(vm.get('name') == 'audit-policy' for vm in container.get('volumeMounts', []))
    has_audit_volumes = any(v.get('name') == 'audit-policy' for v in data['spec'].get('volumes', []))

    print(f"✓ Audit flags: {has_audit_flags}")
    print(f"✓ Audit mounts: {has_audit_mounts}")
    print(f"✓ Audit volumes: {has_audit_volumes}")

except Exception as e:
    print(f"✗ Error: {e}")
EOF
```

### Advanced Debugging

#### Check Kind Cluster Status
```bash
# From host machine - check kind cluster status
kind get clusters
docker ps | grep control-plane

# Check kind cluster logs
docker logs <cluster-name>-control-plane
```

#### Network and Port Issues
```bash
# Check if API server port is listening
docker exec -it <cluster-name>-control-plane netstat -tlnp | grep :6443

# Check API server endpoint
docker exec -it <cluster-name>-control-plane curl -k https://localhost:6443/healthz
```

### Manual Configuration Alternative

If automated methods fail, manually edit the manifest:

```bash
# Create a clean working copy
cp /tmp/kube-apiserver.yaml.backup /tmp/manual-edit.yaml

# Edit the manifest with your preferred editor
vim /tmp/manual-edit.yaml

# Add these sections manually:
# 1. In 'command:' section, add:
#    - --audit-policy-file=/etc/kubernetes/audit-policy.yaml
#    - --audit-log-path=/var/log/kubernetes/audit.log
#    - --audit-log-maxsize=10
#
# 2. In 'volumeMounts:' section, add:
#    - mountPath: /etc/kubernetes/audit-policy.yaml
#      name: audit-policy
#      readOnly: true
#    - mountPath: /var/log/kubernetes
#      name: audit-logs
#
# 3. In 'volumes:' section, add:
#    - hostPath:
#        path: /etc/kubernetes/audit-policy.yaml
#        type: File
#      name: audit-policy
#    - hostPath:
#        path: /var/log/kubernetes
#        type: DirectoryOrCreate
#      name: audit-logs

# Validate before applying
python3 -c "import yaml; yaml.safe_load(open('/tmp/manual-edit.yaml'))" && echo "YAML is valid"

# Apply the changes
cp /tmp/manual-edit.yaml /etc/kubernetes/manifests/kube-apiserver.yaml
```

## Kind-specific Notes

- In kind, the API Server runs inside a Docker container, so all file paths are relative to the container filesystem
- Use `docker exec -it <cluster-name>-control-plane bash` to access the control plane container
- The advertise address will be the container's IP (typically in the 172.18.0.x range)
- Kind uses the `kindest/node` image which may have different versions than standard Kubernetes releases
- All modifications must be done inside the container, not on the host filesystem
