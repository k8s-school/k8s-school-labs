---
title: 'Hardening with CIS Benchmarks'
date: 2026-01-09T10:00:00+10:00
draft: false
weight: 30
tags: ["Kubernetes", "Security", "CKS", "CIS Benchmark", "Kube-bench", "Hardening"]
---

## Introduction to CIS Benchmarks

The [Center for Internet Security (CIS)](https://www.cisecurity.org/cis-benchmarks) provides best practices for securing Kubernetes. In this lab, we will use **kube-bench**, an open-source tool from Aqua Security, to check whether our cluster meets these security recommendations.

## Running kube-bench as a Job

In a CKS exam or production environment, you often run `kube-bench` as a Kubernetes Job to scan nodes without SSH access.

Instead of creating your own job manifest, use the official job configuration from Aqua Security: [job.yaml](https://github.com/aquasecurity/kube-bench/blob/main/job.yaml)

### Exercise: Run kube-bench on specific nodes

Create configurations to run kube-bench on both master and worker nodes using nodeSelector and tolerations.

{{%expand "Solution" %}}

**For Master Node:**

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: kube-bench-master
spec:
  template:
    spec:
      hostPID: true
      nodeSelector:
        node-role.kubernetes.io/control-plane: ""
      tolerations:
      - key: node-role.kubernetes.io/control-plane
        operator: Exists
        effect: NoSchedule
      - key: node-role.kubernetes.io/master
        operator: Exists
        effect: NoSchedule
      containers:
      - name: kube-bench
        image: aquasec/kube-bench:latest
        command: ["kube-bench", "run", "--targets", "master"]
        volumeMounts:
        - name: var-lib-etcd
          mountPath: /var/lib/etcd
          readOnly: true
        - name: var-lib-kubelet
          mountPath: /var/lib/kubelet
          readOnly: true
        - name: var-lib-kube-scheduler
          mountPath: /var/lib/kube-scheduler
          readOnly: true
        - name: var-lib-kube-controller-manager
          mountPath: /var/lib/kube-controller-manager
          readOnly: true
        - name: etc-systemd
          mountPath: /etc/systemd
          readOnly: true
        - name: lib-systemd
          mountPath: /lib/systemd/
          readOnly: true
        - name: etc-kubernetes
          mountPath: /etc/kubernetes
          readOnly: true
        - name: usr-bin
          mountPath: /usr/local/mount-from-host/bin
          readOnly: true
      restartPolicy: Never
      volumes:
      - name: var-lib-etcd
        hostPath:
          path: "/var/lib/etcd"
      - name: var-lib-kubelet
        hostPath:
          path: "/var/lib/kubelet"
      - name: var-lib-kube-scheduler
        hostPath:
          path: "/var/lib/kube-scheduler"
      - name: var-lib-kube-controller-manager
        hostPath:
          path: "/var/lib/kube-controller-manager"
      - name: etc-systemd
        hostPath:
          path: "/etc/systemd"
      - name: lib-systemd
        hostPath:
          path: "/lib/systemd"
      - name: etc-kubernetes
        hostPath:
          path: "/etc/kubernetes"
      - name: usr-bin
        hostPath:
          path: "/usr/bin"
```

**For Worker Node:**

First, identify a worker node:
```bash
kubectl get nodes --no-headers | grep -v control-plane | head -1
```

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: kube-bench-worker
spec:
  template:
    spec:
      hostPID: true
      nodeSelector:
        kubernetes.io/hostname: "WORKER_NODE_NAME"  # Replace with actual worker node name
      containers:
      - name: kube-bench
        image: aquasec/kube-bench:latest
        command: ["kube-bench", "run", "--targets", "node"]
        volumeMounts:
        - name: var-lib-kubelet
          mountPath: /var/lib/kubelet
          readOnly: true
        - name: var-lib-kube-proxy
          mountPath: /var/lib/kube-proxy
          readOnly: true
        - name: etc-systemd
          mountPath: /etc/systemd
          readOnly: true
        - name: lib-systemd
          mountPath: /lib/systemd/
          readOnly: true
        - name: etc-kubernetes
          mountPath: /etc/kubernetes
          readOnly: true
        - name: usr-bin
          mountPath: /usr/local/mount-from-host/bin
          readOnly: true
      restartPolicy: Never
      volumes:
      - name: var-lib-kubelet
        hostPath:
          path: "/var/lib/kubelet"
      - name: var-lib-kube-proxy
        hostPath:
          path: "/var/lib/kube-proxy"
      - name: etc-systemd
        hostPath:
          path: "/etc/systemd"
      - name: lib-systemd
        hostPath:
          path: "/lib/systemd"
      - name: etc-kubernetes
        hostPath:
          path: "/etc/kubernetes"
      - name: usr-bin
        hostPath:
          path: "/usr/bin"
```

**Apply and check:**

```bash
kubectl apply -f kube-bench-master.yaml
kubectl apply -f kube-bench-worker.yaml

# Wait for completion
kubectl get jobs
kubectl logs job/kube-bench-master
kubectl logs job/kube-bench-worker
```

{{% /expand%}}

Apply the job and check the logs:

```bash
kubectl apply -f kube-bench-job.yaml
# Wait for completion
kubectl get pods
kubectl logs <kube-bench-pod-name>

```

## Practical CKS Exercise Workflow

As a CKS candidate, you should practice the complete security hardening workflow manually. This section guides you through the key exercises step by step.

## Remediation Practice

Look for the check **1.4.1: Ensure that the --profiling argument is set to false**.

1. Check the current status of the Scheduler:

```bash
kubectl get pod -n kube-system -l component=kube-scheduler -o yaml | grep profiling

```

2. Fix the issue by editing the static pod manifest on the control plane node:

```bash
sudo vi /etc/kubernetes/manifests/kube-scheduler.yaml

```

Add the line `--profiling=false` under the `command` section.

{{% notice note %}}
Wait for the Scheduler to restart automatically. If you make a syntax error in the YAML file, the Scheduler will disappear from `kubectl get pods` and you will need to fix it directly on the node's disk.
{{% /notice %}}

3. Run `kube-bench` again. Is the check passing now?

## Hands-on CKS Exercises

Before moving to advanced topics, practice these essential CKS security validation skills:

### Exercise 1: Manual Security Baseline Assessment

**Objective**: Establish a security baseline and understand current cluster posture.

1. **Run initial scans and document findings**:

```bash
# Create a namespace for security tools
kubectl create namespace security-assessment

# Run master node scan with official job
kubectl apply -f https://raw.githubusercontent.com/aquasecurity/kube-bench/main/job-master.yaml

# Wait for completion and check results
kubectl get jobs -n default
kubectl logs job/kube-bench-master

# Count initial security findings
kubectl logs job/kube-bench-master | grep -E "(PASS|FAIL|WARN)"
```

2. **Analyze critical failures**:

```bash
# Focus on high-priority failures
kubectl logs job/kube-bench-master | grep "\[FAIL\]" | head -5

# Identify encryption-related warnings
kubectl logs job/kube-bench-master | grep -E "1.2.2[78]"

# Check scheduler security
kubectl logs job/kube-bench-master | grep "1.4.1"
```

### Exercise 2: Manual Secret Security Analysis

**Objective**: Understand how secrets are stored and verify encryption status.

1. **Create test secrets for security analysis**:

```bash
# Create test secrets with known values
kubectl create secret generic security-test-1 --from-literal=username=admin
kubectl create secret generic security-test-2 --from-literal=password=secret123

# Verify secrets exist
kubectl get secrets security-test-1 security-test-2
kubectl describe secret security-test-1
```

2. **Examine secret storage in etcd** (Advanced CKS skill):

```bash
# Get control plane pod name
CONTROL_PLANE_POD=$(kubectl get pods -n kube-system -l component=etcd -o name | cut -d/ -f2)

# Read secret from etcd directly (shows Kubernetes protobuf format)
kubectl exec $CONTROL_PLANE_POD -n kube-system -- etcdctl get \
  /registry/secrets/default/security-test-1 \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/peer.crt \
  --key=/etc/kubernetes/pki/etcd/peer.key
```

**Understanding the output**: The data shows Kubernetes protobuf format with secret metadata, but you can see plaintext values embedded in the binary data. Look for `admin` in the output.

3. **Decode secrets to see plaintext content**:

```bash
# Method 1: Direct kubectl decode (shows base64 decoded values)
kubectl get secret security-test-1 -o jsonpath='{.data.username}' | base64 -d
echo  # newline
kubectl get secret security-test-2 -o jsonpath='{.data.password}' | base64 -d
echo

# Method 2: Show all secret data in plaintext
kubectl get secret security-test-1 -o json | jq -r '.data | to_entries[] | "\(.key): \(.value | @base64d)"'
kubectl get secret security-test-2 -o json | jq -r '.data | to_entries[] | "\(.key): \(.value | @base64d)"'

# Method 3: Using kubectl for quick check
kubectl get secret security-test-1 security-test-2 -o yaml
```

**Critical Security Insight**: Without encryption at rest, these plaintext values are accessible to anyone with etcd access!

3. **Document current security status**:

```bash
# Check if encryption is configured
kubectl get pod -n kube-system -l component=kube-apiserver -o yaml | grep encryption-provider-config

# Result should be empty if no encryption is configured
```

### Exercise 3: Systematic Security Hardening

**Objective**: Practice the complete hardening workflow that CKS candidates must master.

1. **Address scheduler profiling (Check 1.4.1)**:

```bash
# Current status
kubectl get pod -n kube-system -l component=kube-scheduler -o yaml | grep profiling

# Edit the scheduler manifest
sudo vi /etc/kubernetes/manifests/kube-scheduler.yaml
# Add: --profiling=false

# Verify scheduler restarts
kubectl get pods -n kube-system -l component=kube-scheduler -w
```

2. **Implement and verify the fix**:

```bash
# Re-run kube-bench to verify fix
kubectl delete job kube-bench-master
kubectl apply -f https://raw.githubusercontent.com/aquasecurity/kube-bench/main/job-master.yaml
kubectl logs job/kube-bench-master | grep "1.4.1"

# Should show [PASS] now
```

## Advanced Remediation: Encryption at Rest

One of the most critical security configurations highlighted by kube-bench is encryption at rest (checks **1.2.27** and **1.2.28**). Even though these appear as **[WARN]** in the scan results, they represent the ultimate protection against etcd database theft.

### Understanding the Challenge

When etcd is compromised, all Kubernetes secrets are visible in plain text. Encryption at rest ensures that even with direct database access, secrets remain protected.

### Exercise: Configure Encryption at Rest

**Step 1: Generate an encryption key**

```bash
# Generate a 32-byte random key and encode it in base64
head -c 32 /dev/urandom | base64
```

**Step 2: Create the EncryptionConfiguration**

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

**Step 3: Configure the API Server**

Edit `/etc/kubernetes/manifests/kube-apiserver.yaml` and add:

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

**Step 4: Wait for API Server restart**

```bash
# Monitor the API server restart
kubectl get pods -n kube-system -l component=kube-apiserver -w
```

**Step 5: The Critical Step - Encrypt Existing Secrets**

⚠️ **Important**: Adding encryption configuration only encrypts NEW secrets. Existing secrets remain unencrypted!

```bash
# Force re-encryption of all existing secrets
kubectl get secrets --all-namespaces -o json | kubectl replace -f -

# Verify a secret is now encrypted in etcd
ETCDCTL_API=3 etcdctl get /registry/secrets/default/my-secret --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/healthcheck-client.crt \
  --key=/etc/kubernetes/pki/etcd/healthcheck-client.key
```

**Step 6: Verify the configuration**

Run kube-bench again to confirm the warnings are resolved:

```bash
./kube-bench run --targets master | grep -A 2 -B 2 "1.2.2[78]"
```

### Exercise 4: Manual Encryption Verification (Essential CKS Skill)

**Objective**: Verify that encryption at rest is working correctly by manually testing secret encryption.

**Step 1: Create test secrets AFTER encryption is configured**

```bash
# Create new secrets that should be encrypted
kubectl create secret generic post-encryption-test-1 --from-literal=data=sensitive-info-1
kubectl create secret generic post-encryption-test-2 --from-literal=data=sensitive-info-2

# Wait for secrets to be persisted
sleep 2
```

**Step 2: Compare encrypted vs unencrypted secrets in etcd**

```bash
# Check our OLD secrets from Exercise 2 (should still be plaintext until re-encrypted)
kubectl exec $CONTROL_PLANE_POD -n kube-system -- etcdctl get \
  /registry/secrets/default/security-test-1 \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/peer.crt \
  --key=/etc/kubernetes/pki/etcd/peer.key

# Check NEW secrets (should be encrypted - look for k8s:enc:aescbc:v1:key1: prefix)
kubectl exec $CONTROL_PLANE_POD -n kube-system -- etcdctl get \
  /registry/secrets/default/post-encryption-test-1 \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/peer.crt \
  --key=/etc/kubernetes/pki/etcd/peer.key
```

**Expected Results:**
- Old secret: Shows "admin" in plaintext within protobuf data
- New secret: Shows `k8s:enc:aescbc:v1:key1:` followed by encrypted binary data

**Step 3: Force re-encryption of existing secrets**

```bash
# Re-encrypt all existing secrets
kubectl get secrets --all-namespaces -o json | kubectl replace -f -

# Verify old secrets are now encrypted
kubectl exec $CONTROL_PLANE_POD -n kube-system -- etcdctl get \
  /registry/secrets/default/security-test-1 \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/peer.crt \
  --key=/etc/kubernetes/pki/etcd/peer.key

# Should now show k8s:enc:aescbc:v1:key1: prefix instead of plaintext
```

{{%expand "Complete Validation Checklist" %}}

**Validation Step 1: Verify encryption configuration is active**

```bash
# Check API server has encryption config
kubectl get pod -n kube-system -l component=kube-apiserver -o yaml | grep encryption-provider-config

# Should show: --encryption-provider-config=/etc/kubernetes/encryption-config.yaml
```

**Validation Step 2: Test secret encryption in practice**

```bash
# Create a validation secret with known content
kubectl create secret generic validation-test --from-literal=critical-data=TopSecretPassword123

# Check in etcd - should be encrypted (look for k8s:enc:aescbc:v1:key1: prefix)
kubectl exec $CONTROL_PLANE_POD -n kube-system -- etcdctl get \
  /registry/secrets/default/validation-test \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/peer.crt \
  --key=/etc/kubernetes/pki/etcd/peer.key

# Verify secret is still accessible via kubectl
kubectl get secret validation-test -o jsonpath='{.data.critical-data}' | base64 -d
echo

# Clean up
kubectl delete secret validation-test
```

**Validation Step 3: Confirm kube-bench checks pass**

```bash
# Re-run kube-bench master scan
kubectl delete job kube-bench-master --ignore-not-found
kubectl apply -f https://raw.githubusercontent.com/aquasecurity/kube-bench/main/job-master.yaml

# Check specific encryption checks
kubectl logs job/kube-bench-master | grep -E "1.2.2[78]"

# Both should show [PASS] now:
# [PASS] 1.2.27 Ensure that the --encryption-provider-config argument is set as appropriate
# [PASS] 1.2.28 Ensure that encryption providers are appropriately configured
```

**Expected final state:**
- ✅ All new secrets automatically encrypted in etcd
- ✅ Old secrets re-encrypted after kubectl replace
- ✅ CIS checks 1.2.27 and 1.2.28 show [PASS]
- ✅ Secrets still accessible normally via kubectl

{{% /expand%}}

{{% notice warning %}}
**Production Considerations:**
- Always backup etcd before enabling encryption
- Use a key management system (KMS) instead of static keys in production
- Implement key rotation procedures
- Monitor encryption performance impact
{{% /notice %}}

### Exercise 5: Post-Hardening Security Assessment

**Objective**: Validate that your security hardening efforts have improved the cluster's security posture.

**Step 1: Run comprehensive post-hardening scans**

```bash
# Clean up any previous jobs
kubectl delete job kube-bench-master kube-bench-worker --ignore-not-found

# Run master node security scan
kubectl apply -f https://raw.githubusercontent.com/aquasecurity/kube-bench/main/job-master.yaml

# Run worker node security scan
kubectl apply -f https://raw.githubusercontent.com/aquasecurity/kube-bench/main/job-node.yaml

# Wait for completion
kubectl get jobs -w
```

**Step 2: Analyze security improvements**

```bash
# Check scheduler profiling fix (should be [PASS] now)
kubectl logs job/kube-bench-master | grep "1.4.1"

# Check encryption at rest (should be [PASS] now)
kubectl logs job/kube-bench-master | grep -E "1.2.2[78]"

# Get overall security summary
kubectl logs job/kube-bench-master | grep "== Summary"
kubectl logs job/kube-bench-worker | grep "== Summary"
```

**Step 3: Document security improvements**

```bash
# Count improvements
echo "=== MASTER NODE SECURITY IMPROVEMENTS ==="
kubectl logs job/kube-bench-master | grep -c "\[PASS\]"
kubectl logs job/kube-bench-master | grep -c "\[FAIL\]"
kubectl logs job/kube-bench-master | grep -c "\[WARN\]"

echo "=== WORKER NODE SECURITY STATUS ==="
kubectl logs job/kube-bench-worker | grep -c "\[PASS\]"
kubectl logs job/kube-bench-worker | grep -c "\[FAIL\]"
kubectl logs job/kube-bench-worker | grep -c "\[WARN\]"
```

**Step 4: Clean up test resources**

```bash
# Remove test secrets created during exercises
kubectl delete secret security-test-1 security-test-2 --ignore-not-found
kubectl delete secret post-encryption-test-1 post-encryption-test-2 --ignore-not-found

# Remove kube-bench jobs
kubectl delete job kube-bench-master kube-bench-worker --ignore-not-found

# Remove security assessment namespace if created
kubectl delete namespace security-assessment --ignore-not-found
```

### Expected Improvements After Completing All Exercises

After completing all 5 exercises, you should see:

- **Check 1.4.1**: `[PASS]` - Scheduler profiling disabled ✅
- **Check 1.2.27**: `[PASS]` - Encryption provider config set ✅
- **Check 1.2.28**: `[PASS]` - Encryption providers configured ✅

**Before vs After comparison:**

{{%expand "Security Score Comparison" %}}

**Initial scan results:**
```
== Summary master ==
39 checks PASS
10 checks FAIL
11 checks WARN
```

**After hardening:**
```
== Summary master ==
42 checks PASS  (+3 improvements)
7 checks FAIL   (-3 failures fixed)
11 checks WARN  (unchanged)
```

**Key improvements:**
- ✅ Scheduler profiling disabled (1.4.1)
- ✅ Encryption at rest enabled (1.2.27, 1.2.28)
- ✅ Better overall security posture

{{% /expand%}}

{{% notice tip %}}
**Best Practice:** Always document your security improvements and maintain a baseline scan for comparison. Consider setting up automated scans to detect configuration drift.
{{% /notice %}}

## Automation and Continuous Compliance

Why is running `kube-bench` manually not enough for a production environment?

{{%expand "Answers" %}}

* **Configuration Drift**: A manual change or update could revert security settings.
* **New Benchmarks**: CIS updates its recommendations regularly.
* **Visibility**: Security teams need centralized reporting, not just CLI logs.
{{% /expand%}}

### Suggested improvement

Integrate `kube-bench` into a CronJob to run every week and send results to a security dashboard like Falco or a SIEM.

{{%expand "CronJob Solution" %}}

Here's a complete CronJob configuration that runs kube-bench weekly on all nodes:

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: kube-bench-cronjob
  namespace: default
spec:
  schedule: "0 2 * * 0"  # Every Sunday at 2 AM
  jobTemplate:
    spec:
      template:
        spec:
          hostPID: true
          nodeSelector:
            node-role.kubernetes.io/control-plane: ""
          tolerations:
          # Allow running on master nodes
          - key: node-role.kubernetes.io/control-plane
            operator: Exists
            effect: NoSchedule
          - key: node-role.kubernetes.io/master
            operator: Exists
            effect: NoSchedule
          containers:
          - name: kube-bench
            image: aquasec/kube-bench:latest
            command: ["kube-bench", "run", "--targets", "master,node"]
            volumeMounts:
            - name: var-lib-etcd
              mountPath: /var/lib/etcd
              readOnly: true
            - name: var-lib-kubelet
              mountPath: /var/lib/kubelet
              readOnly: true
            - name: var-lib-kube-scheduler
              mountPath: /var/lib/kube-scheduler
              readOnly: true
            - name: var-lib-kube-controller-manager
              mountPath: /var/lib/kube-controller-manager
              readOnly: true
            - name: etc-systemd
              mountPath: /etc/systemd
              readOnly: true
            - name: lib-systemd
              mountPath: /lib/systemd/
              readOnly: true
            - name: etc-kubernetes
              mountPath: /etc/kubernetes
              readOnly: true
            - name: usr-bin
              mountPath: /usr/local/mount-from-host/bin
              readOnly: true
          restartPolicy: OnFailure
          volumes:
          - name: var-lib-etcd
            hostPath:
              path: "/var/lib/etcd"
          - name: var-lib-kubelet
            hostPath:
              path: "/var/lib/kubelet"
          - name: var-lib-kube-scheduler
            hostPath:
              path: "/var/lib/kube-scheduler"
          - name: var-lib-kube-controller-manager
            hostPath:
              path: "/var/lib/kube-controller-manager"
          - name: etc-systemd
            hostPath:
              path: "/etc/systemd"
          - name: lib-systemd
            hostPath:
              path: "/lib/systemd"
          - name: etc-kubernetes
            hostPath:
              path: "/etc/kubernetes"
          - name: usr-bin
            hostPath:
              path: "/usr/bin"
```

**Apply the CronJob:**

```bash
kubectl apply -f kube-bench-cronjob.yaml

# Check CronJob status
kubectl get cronjobs

# Check job history
kubectl get jobs

# Check latest run logs
kubectl logs -l job-name=kube-bench-cronjob-<timestamp>
```

**Additional improvements for production:**

1. **Resource limits:**
   ```yaml
   resources:
     limits:
       memory: "512Mi"
       cpu: "500m"
     requests:
       memory: "256Mi"
       cpu: "100m"
   ```

2. **Dedicated namespace:**
   ```bash
   kubectl create namespace security-scans
   ```

3. **Log aggregation:** Configure log forwarding to send kube-bench results to your centralized logging system (ELK stack, Splunk, etc.)

{{% /expand%}}

---

Congratulations! You now know how to audit a cluster against industry standards and perform basic hardening 🛡️!

Would you like me to generate a specific remediation guide for Kubelet security settings (Section 4 of the CIS Benchmark)?

