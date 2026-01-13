---
title: 'Hardening with CIS Benchmarks - Running kube-bench Jobs'
date: 2026-01-09T10:00:00+10:00
draft: false
weight: 120
tags: ["Kubernetes", "Security", "CKS", "CIS Benchmark", "Kube-bench", "Jobs"]
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

---

**Next:** Continue with [Hardening with CIS Benchmarks - Remediations](kubebench-20-remediations.en.md) to learn how to fix the security issues found by kube-bench.