---
title: 'Hardening with CIS Benchmarks - Security Remediations'
date: 2026-01-09T10:00:00+10:00
draft: false
weight: 61
tags: ["Kubernetes", "Security", "CKS", "CIS Benchmark", "Kube-bench", "Hardening", "Remediations"]
---

## Practical CKS Exercise Workflow

As a CKS candidate, you should practice the complete security hardening workflow manually. This section guides you through the key exercises step by step to remediate security issues found by kube-bench.

## Remove the  `--profiling` argument for the scheduler

Look for the check **1.4.1: Ensure that the --profiling argument is set to false**.

- Check the current status of the Scheduler:

{{%expand "Solution" %}}

```bash
# Correctly assign the pod name using a subshell $() and -o name
SCHEDULER_POD=$(kubectl get pod -n kube-system -l component=kube-scheduler -o jsonpath='{.items[0].metadata.name}')

# Execute the help command on that pod
kubectl exec -n kube-system $SCHEDULER_POD -- kube-scheduler --help | grep profiling
```

{{% /expand%}}

- Fix the issue by editing the `kube-scheduler` static pod manifest on the control plane node:

{{%expand "Solution" %}}

```bash
# Access the Kubernetes control-plane node (which runs as a Docker container because of Kind)
docker exec -it cks-control-plane bash

# BACKUP: Copy the manifest to your HOME directory before editing
# Crucial: If the YAML is invalid, the pod will disappear; this allows for quick recovery
cp /etc/kubernetes/manifests/kube-scheduler.yaml $HOME/kube-scheduler.yaml.orig

# Environment Prep: Update package lists and install Vim (Kind images are minimal)
apt update && apt install vim -y

# Edit the static pod manifest (e.g., to disable profiling or change arguments)
# Add the line `--profiling=false` under the `command` section.
vi /etc/kubernetes/manifests/kube-scheduler.yaml

# Low-level check: Verify container status via the Container Runtime Interface (CRI)
crictl ps
```

{{% /expand%}}

{{% notice tip %}}

### ⚠️ Critical: Perform a Backup First

Before modifying any Control Plane component, create a backup outside of the manifests directory:

```bash
cp /etc/kubernetes/manifests/kube-scheduler.yaml $HOME/kube-scheduler.yaml.bak
```

Why? If the YAML contains a syntax error, the Scheduler will disappear from `kubectl get pods`. Additionally, never store backups inside `/etc/kubernetes/manifests/`, as the Kubelet will attempt to run every YAML file it finds there, causing unexpected behavior.

{{% /notice %}}

{{% notice note %}}

### 🔄 Automatic Restart & Validation

The Kubelet continuously monitors the /etc/kubernetes/manifests/ directory.

Saving Changes: Once you save the file, the Kubelet automatically kills the old pod and recreates it.

Wait Time: This process usually takes 30–60 seconds.

Verification: If the pod does not reappear, check the node's container runtime directly to find the error:

```bash
crictl ps | grep kube-scheduler
```

{{% /notice %}}

- Run `kube-bench` again on master. Is the check passing now?

## Advanced Remediation: Encryption at Rest

One of the most critical security configurations highlighted by `kube-bench` is encryption at rest (checks **1.2.27** and **1.2.28**). Even though these appear as **[WARN]** in the scan results, they represent the ultimate protection against etcd database theft.

[Official documentation](https://kubernetes.io/docs/tasks/administer-cluster/encrypt-data/)

### Understanding the Challenge

When `etcd` is compromised, all Kubernetes secrets are visible in plain text. Encryption at rest ensures that even with direct database access, secrets remain protected.

### Configure Encryption at Rest

- Generate an encryption key

```bash
# Generate a 32-byte random key and encode it in base64
head -c 32 /dev/urandom | base64
```

- Create the EncryptionConfiguration**

Create `/etc/kubernetes/encryption-config.yaml` on the control plane:

```yaml
apiVersion: apiserver.config.k8s.io/v1
kind: EncryptionConfiguration
resources:
  - resources:
    - secrets
    providers:
    - aescbc:
        keys:
        - name: key1
          secret: <YOUR_BASE64_KEY_HERE>
    - identity: {}
```

- Configure the API Server

Perform a backup of `/etc/kubernetes/manifests/kube-apiserver.yaml` and then add:

```yaml
spec:
  containers:
  - command:
    - kube-apiserver
    - --encryption-provider-config=/etc/kubernetes/encryption-config.yaml
    # ... other flags
    volumeMounts:
    - name: encryption-config
      mountPath: /etc/kubernetes/encryption-config.yaml
      readOnly: true
    # ... other mounts
  volumes:
  - name: encryption-config
    hostPath:
      path: /etc/kubernetes/encryption-config.yaml
      type: File
  # ... other volumes
```

- Wait for API Server restart

```bash
# Monitor the API server restart
kubectl get pods -n kube-system -l component=kube-apiserver -w
```

- The Critical Step - Encrypt Existing Secrets

{{% notice note %}}

⚠️ **Important**: Adding encryption configuration only encrypts NEW secrets. Existing secrets remain unencrypted!

{{% /notice %}}

```bash
# Force re-encryption of all existing secrets
kubectl get secrets --all-namespaces -o json | kubectl replace -f -

# Verify a secret is now encrypted in etcd
ETCDCTL_API=3 etcdctl get /registry/secrets/default/my-secret --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/healthcheck-client.crt \
  --key=/etc/kubernetes/pki/etcd/healthcheck-client.key
```

### Manual Encryption Verification

**Objective**: Verify that encryption at rest is working correctly by manually testing secret encryption.

- Create test secrets AFTER encryption is configured

```bash
# Create new secrets that should be encrypted
kubectl create secret generic post-encryption-test-1 --from-literal=data=sensitive-info-1
kubectl create secret generic post-encryption-test-2 --from-literal=data=sensitive-info-2
```

- Compare encrypted vs unencrypted secrets in etcd

{{%expand Solution %}}

```bash
# Get etcd pod name
ETCD_POD=$(kubectl get pods -n kube-system -l component=etcd -o jsonpath='{.items[0].metadata.name}')

# Check our OLD secrets from Exercise 2 (should still be plaintext until re-encrypted)
kubectl exec $ETCD_POD -n kube-system -- etcdctl get \
  /registry/secrets/default/security-test-1 \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/peer.crt \
  --key=/etc/kubernetes/pki/etcd/peer.key

# Check NEW secrets (should be encrypted - look for k8s:enc:aescbc:v1:key1: prefix)
kubectl exec $ETCD_POD -n kube-system -- etcdctl get \
  /registry/secrets/default/post-encryption-test-1 \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/peer.crt \
  --key=/etc/kubernetes/pki/etcd/peer.key
```

**Expected Results:**

- Old secret: Shows "admin" in plaintext within protobuf data
- New secret: Shows `k8s:enc:aescbc:v1:key1:` followed by encrypted binary data

{{% /expand %}}

- Force re-encryption of existing secrets

{{%expand Solution %}}

```bash
# Re-encrypt all existing secrets
kubectl get secrets --all-namespaces -o json | kubectl replace -f -

# Verify old secrets are now encrypted
kubectl exec $ETCD_POD -n kube-system -- etcdctl get \
  /registry/secrets/default/security-test-1 \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/peer.crt \
  --key=/etc/kubernetes/pki/etcd/peer.key

# Should now show k8s:enc:aescbc:v1:key1: prefix instead of plaintext
```

{{% /expand %}}

### Confirm kube-bench checks pass

Run `kube-bench` again to confirm the warnings are resolved:

{{%expand Solution %}}

```bash
# Re-run kube-bench master scan
kubectl delete job kube-bench-master --ignore-not-found
kubectl apply -f kube-bench-master.yaml

# Check specific encryption checks
kubectl logs job/kube-bench-master | grep -E "1.2.2[78]"

# Both should show [PASS] now:
# [PASS] 1.2.27 Ensure that the --encryption-provider-config argument is set as appropriate
# [PASS] 1.2.28 Ensure that encryption providers are appropriately configured
```

{{% /expand %}}

**Expected final state:**

- ✅ All new secrets automatically encrypted in etcd
- ✅ Old secrets re-encrypted after kubectl replace
- ✅ CIS checks 1.2.27 and 1.2.28 show [PASS]
- ✅ Secrets still accessible normally via kubectl

{{% notice note %}}
**Production Considerations:**

- Always backup etcd before enabling encryption
- Use a key management system (KMS) instead of static keys in production
- Implement key rotation procedures
- Monitor encryption performance impact
{{% /notice %}}

## Post-Hardening Security Assessment

**Objective**: Validate that your security hardening efforts have improved the cluster's security posture.

{{%expand "Security Score Comparison" %}}

Compare security score summaries before and after hardening.

**Key improvements:**

- ✅ Scheduler profiling disabled (1.4.1)
- ✅ Encryption at rest enabled (1.2.27, 1.2.28)
- ✅ Better overall security posture

{{% /expand%}}

{{% notice tip %}}
**Best Practice:** Always document your security improvements and maintain a baseline scan for comparison. Consider setting up automated scans to detect configuration drift.
{{% /notice %}}

---

**Next:** Continue with [Hardening with CIS Benchmarks - Automation](../kubebench-30-automation/) to learn how to automate security compliance monitoring.