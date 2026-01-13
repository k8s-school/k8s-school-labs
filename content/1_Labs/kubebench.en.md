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

### Run kube-bench on specific nodes

- Create configurations to run kube-bench on both master and worker nodes

use `nodeSelector` and `tolerations`.

{{%expand "Solution for Master Node" %}}

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

{{% /expand%}}

{{%expand "Solution for Worker Node" %}}

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

{{% /expand%}}

### Manual Security Baseline Assessment

**Objective**: Establish a security baseline and understand current cluster posture.

Create namespace `kube-bench` and run above job inside it.

{{%expand "Solution" %}}

```bash

# Create a namespace for security tools
kubectl create namespace kube-bench

kubectl apply -n kube-bench -f kube-bench-master.yaml
kubectl apply -n kube-bench -f kube-bench-worker.yaml

# Wait for completion
kubectl get -n kube-bench jobs
kubectl logs -n kube-bench job/kube-bench-master
kubectl logs -n kube-bench job/kube-bench-worker

# Focus on high-priority failures
kubectl logs job/kube-bench-master | grep "\[FAIL\]"
```

{{% /expand%}}

## Practical CKS Exercise Workflow

As a CKS candidate, you should practice the complete security hardening workflow manually. Next sections guides you through the key exercises step by step.

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

## Check Secrets encryption

**Objective**: Understand how secrets are stored and verify encryption status.

### Create test secrets for security analysis

```bash
# Create test secrets with known values
kubectl create secret generic security-test-1 --from-literal=username=admin
kubectl create secret generic security-test-2 --from-literal=password=secret123

# Verify secrets exist
kubectl get secrets security-test-1 security-test-2
kubectl describe secret security-test-1
```

### Examine secret storage in etcd (Advanced CKS skill)

```bash
# Get etcd pod name
ETCD_POD=$(kubectl get pods -n kube-system -l component=etcd -o jsonpath='{.items[0].metadata.name}')

# Read secret from etcd directly (shows Kubernetes protobuf format)
kubectl exec $ETCD_POD -n kube-system -- etcdctl get \
  /registry/secrets/default/security-test-1 \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/peer.crt \
  --key=/etc/kubernetes/pki/etcd/peer.key
```

{{% notice note %}}

**Understanding the output**: The data shows Kubernetes protobuf format with secret metadata, but you can see plaintext values embedded in the binary data. Look for `admin` in the output.

{{% /notice %}}

### Decode secrets to see plaintext content

Use `base64 -d` to decode unencrypted secrets.

{{%expand "Solution" %}}

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

{{% /expand %}}

{{% notice warning %}}

**Critical Security Insight**: without encryption at rest, Secrets are stored in etcd as plaintext. This means anyone with filesystem access to the etcd backups or direct access to the etcd API can bypass Kubernetes security entirely to read your sensitive data.

However, enabling encryption at rest only protects the data "on disk." When a user retrieves a Secret via kubectl or the API, the API server automatically decrypts it. To prevent unauthorized users from viewing these values, you must implement strict Role-Based Access Control (RBAC) to limit who can get or list Secret resources.

{{% /notice %}}

### Check current security status

```bash
# Check if encryption is configured
kubectl get pod -n kube-system -l component=kube-apiserver -o yaml | grep encryption-provider-config

# Result should be empty if no encryption is configured
```

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

## Automation and Continuous Compliance

Why is running `kube-bench` manually not enough for a production environment?

{{%expand "Answers" %}}

- **Configuration Drift**: A manual change or update could revert security settings.
- **New Benchmarks**: CIS updates its recommendations regularly.
- **Visibility**: Security teams need centralized reporting, not just CLI logs.
{{% /expand%}}

### Suggested improvement

Integrate `kube-bench` into a CronJob to run every week and send results to a security dashboard like Falco or a SIEM.

{{%expand "CronJob Solution" %}}

Here's a complete CronJob configuration that runs kube-bench weekly on all nodes:

```bash
cat << EOF > kube-bench-cronjob.yaml
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
EOF
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

- **Resource limits:**

   ```yaml
   resources:
     limits:
       memory: "512Mi"
       cpu: "500m"
     requests:
       memory: "256Mi"
       cpu: "100m"
   ```

- **Dedicated namespace:**

   ```bash
   kubectl create namespace security-scans
   ```

- **Log aggregation:** Configure log forwarding to send kube-bench results to your centralized logging system (ELK stack, Splunk, etc.)

{{% /expand%}}

---

Congratulations! You now know how to audit a cluster against industry standards and perform basic hardening 🛡️!
