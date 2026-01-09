---
title: 'Hardening with CIS Benchmarks'
date: 2026-01-09T10:00:00+10:00
draft: false
weight: 30
tags: ["Kubernetes", "Security", "CKS", "CIS Benchmark", "Kube-bench", "Hardening"]
---

## Introduction to CIS Benchmarks

The Center for Internet Security (CIS) provides best practices for securing Kubernetes. In this lab, we will use **kube-bench**, an open-source tool from Aqua Security, to check whether our cluster meets these security recommendations.

## Manual Installation and Discovery

First, let's explore the CIS rules by installing the tool directly on a control-plane node.

Connect to your control-plane node and download the latest binary:

```bash
VERSION=0.9.2
wget https://github.com/aquasecurity/kube-bench/releases/download/v${VERSION}/kube-bench_${VERSION}_linux_amd64.tar.gz
tar -xvf kube-bench_${VERSION}_linux_amd64.tar.gz

```

Run a scan for the control plane:

```bash
./kube-bench run --targets master

```

Analyze the output. What are the three possible statuses for a check?

{{%expand "Answers" %}}

* **[PASS]**: The check succeeded.
* **[FAIL]**: The check failed; an immediate action is usually required.
* **[WARN]**: Manual inspection is needed.
{{% /expand%}}

## Running kube-bench as a Job

In a CKS exam or production environment, you often run `kube-bench` as a Kubernetes Job to scan nodes without SSH access.

Create a file named `kube-bench-job.yaml`:

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: kube-bench
spec:
  template:
    spec:
      hostPID: true
      containers:
        - name: kube-bench
          image: aquasec/kube-bench:latest
          command: ["kube-bench", "run", "--targets", "node"]
          volumeMounts:
            - name: var-lib-kubelet
              mountPath: /var/lib/kubelet
              readOnly: true
            - name: etc-systemd
              mountPath: /etc/systemd
              readOnly: true
            - name: etc-kubernetes
              mountPath: /etc/kubernetes
              readOnly: true
      restartPolicy: Never
      volumes:
        - name: var-lib-kubelet
          hostPath:
            path: /var/lib/kubelet
        - name: etc-systemd
          hostPath:
            path: /etc/systemd
        - name: etc-kubernetes
          hostPath:
            path: /etc/kubernetes

```

Apply the job and check the logs:

```bash
kubectl apply -f kube-bench-job.yaml
# Wait for completion
kubectl get pods
kubectl logs <kube-bench-pod-name>

```

## Remediation Practice

Look for the check **1.2.20: Ensure that the --profiling argument is set to false**.

1. Check the current status of the API Server:

```bash
kubectl get pod -n kube-system -l component=kube-apiserver -o yaml | grep profiling

```

2. Fix the issue by editing the static pod manifest on the control plane node:

```bash
sudo vi /etc/kubernetes/manifests/kube-apiserver.yaml

```

Add the line `--profiling=false` under the `command` section.

{{% notice note %}}
Wait for the API Server to restart automatically. If you make a syntax error in the YAML file, the API Server will disappear from `kubectl get pods` and you will need to fix it directly on the node's disk.
{{% /notice %}}

3. Run `kube-bench` again. Is the check passing now?

## Automation and Continuous Compliance

Why is running `kube-bench` manually not enough for a production environment?

{{%expand "Answers" %}}

* **Configuration Drift**: A manual change or update could revert security settings.
* **New Benchmarks**: CIS updates its recommendations regularly.
* **Visibility**: Security teams need centralized reporting, not just CLI logs.
{{% /expand%}}

### Suggested improvement

Integrate `kube-bench` into a CronJob to run every week and send results to a security dashboard like Falco or a SIEM.

---

Congratulations! You now know how to audit a cluster against industry standards and perform basic hardening 🛡️!

Would you like me to generate a specific remediation guide for Kubelet security settings (Section 4 of the CIS Benchmark)?

