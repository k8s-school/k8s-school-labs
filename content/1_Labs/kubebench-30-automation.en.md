---
title: 'Hardening with CIS Benchmarks - Automation and Continuous Compliance'
date: 2026-01-09T10:00:00+10:00
draft: false
weight: 130
tags: ["Kubernetes", "Security", "CKS", "CIS Benchmark", "Kube-bench", "Automation", "CronJob"]
---

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

Congratulations! You now know how to audit a cluster against industry standards, perform security remediations, and implement automated continuous compliance monitoring 🛡️!

## Summary

In this three-part series, you learned:

1. **[Part 1 - Jobs](kubebench-10-jobs.en.md)**: How to run kube-bench as Kubernetes Jobs and understand security baseline assessment
2. **[Part 2 - Remediations](kubebench-20-remediations.en.md)**: How to fix critical security issues like scheduler profiling and implement encryption at rest
3. **[Part 3 - Automation](kubebench-30-automation.en.md)**: How to automate compliance monitoring with CronJobs and integrate with monitoring systems

**Key achievements:**
- ✅ Established security baseline with CIS benchmarks
- ✅ Implemented critical security remediations
- ✅ Set up automated continuous compliance monitoring
- ✅ Integrated with monitoring and alerting systems
- ✅ Applied policy-as-code principles

**Next steps:**
- Implement additional CIS benchmark remediations
- Set up centralized security dashboard
- Configure automated remediation pipelines
- Integrate with your organization's SIEM/SOAR platforms