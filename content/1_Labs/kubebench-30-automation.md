---
title: 'Hardening with CIS Benchmarks - Automation and Continuous Compliance'
date: 2026-01-09T10:00:00+10:00
draft: false
weight: 62
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

## Advanced Automation Patterns

### 1. Automated Remediation Pipeline

{{%expand "Automated Remediation Example" %}}

Create a pipeline that automatically applies common CIS benchmark fixes:

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: kube-bench-with-remediation
  namespace: security-scans
spec:
  schedule: "0 3 * * 0"  # Every Sunday at 3 AM
  jobTemplate:
    spec:
      template:
        spec:
          serviceAccountName: kube-bench-remediator
          containers:
          - name: kube-bench-remediation
            image: custom/kube-bench-remediation:latest
            command: ["/bin/bash"]
            args:
            - -c
            - |
              # Run kube-bench
              kube-bench run --targets master > /tmp/results.txt

              # Parse results and apply safe remediations
              if grep -q "1.4.1.*FAIL" /tmp/results.txt; then
                echo "Applying scheduler profiling remediation..."
                # Apply remediation script
              fi

              # Send results to monitoring system
              curl -X POST $WEBHOOK_URL -d @/tmp/results.txt
            env:
            - name: WEBHOOK_URL
              valueFrom:
                secretKeyRef:
                  name: monitoring-webhooks
                  key: slack-webhook
```

{{% /expand%}}

### 2. Security Dashboard Integration

{{%expand "Dashboard Integration Example" %}}

Integration with popular security dashboards:

**Grafana Dashboard:**

```json
{
  "dashboard": {
    "title": "Kubernetes CIS Compliance",
    "panels": [
      {
        "title": "CIS Benchmark Score",
        "type": "stat",
        "targets": [
          {
            "expr": "kube_bench_pass_count / (kube_bench_pass_count + kube_bench_fail_count) * 100"
          }
        ]
      }
    ]
  }
}
```

**Prometheus Metrics Export:**

```bash
# Add to kube-bench job to export metrics
echo "kube_bench_pass_count $(grep -c PASS /tmp/results.txt)" | curl -X POST http://pushgateway:9091/metrics/job/kube-bench
echo "kube_bench_fail_count $(grep -c FAIL /tmp/results.txt)" | curl -X POST http://pushgateway:9091/metrics/job/kube-bench
```

{{% /expand%}}

### 3. Policy as Code with OPA

{{%expand "OPA Gatekeeper Integration" %}}

Prevent non-compliant configurations using OPA Gatekeeper:

```yaml
apiVersion: templates.gatekeeper.sh/v1beta1
kind: ConstraintTemplate
metadata:
  name: k8srequiredsecuritycontext
spec:
  crd:
    spec:
      names:
        kind: K8sRequiredSecurityContext
      validation:
        type: object
        properties:
          runAsNonRoot:
            type: boolean
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package k8srequiredsecuritycontext

        violation[{"msg": msg}] {
          container := input.review.object.spec.containers[_]
          not container.securityContext.runAsNonRoot
          msg := "Container must run as non-root user"
        }
```

{{% /expand%}}

## Monitoring and Alerting

### 4. Compliance Monitoring Setup

{{%expand "Complete Monitoring Solution" %}}

**1. Metrics Collection:**

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: kube-bench-exporter
data:
  script.sh: |
    #!/bin/bash
    while true; do
      # Run kube-bench and parse results
      RESULTS=$(kube-bench run --targets master --json)
      PASS=$(echo $RESULTS | jq '.Controls[].Groups[].Checks[] | select(.state=="PASS") | 1' | wc -l)
      FAIL=$(echo $RESULTS | jq '.Controls[].Groups[].Checks[] | select(.state=="FAIL") | 1' | wc -l)

      # Export to Prometheus
      cat <<EOF | curl -X POST http://pushgateway:9091/metrics/job/kube-bench/instance/$HOSTNAME
    kube_bench_checks_pass $PASS
    kube_bench_checks_fail $FAIL
    kube_bench_compliance_score $(echo "scale=2; $PASS/($PASS+$FAIL)*100" | bc)
    EOF

      sleep 3600  # Run every hour
    done
```

**2. Alerting Rules:**

```yaml
groups:
- name: kubernetes-security
  rules:
  - alert: CISComplianceDropped
    expr: kube_bench_compliance_score < 80
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "Kubernetes CIS compliance score dropped below 80%"

  - alert: CriticalSecurityFinding
    expr: increase(kube_bench_checks_fail[1h]) > 0
    for: 0m
    labels:
      severity: critical
    annotations:
      summary: "New critical security findings detected"
```

{{% /expand%}}

## Best Practices for Production

### 5. Deployment Recommendations

{{%expand "Production Deployment Guide" %}}

**1. Resource Management:**

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: security-scans-quota
  namespace: security-scans
spec:
  hard:
    requests.cpu: "2"
    requests.memory: 4Gi
    limits.cpu: "4"
    limits.memory: 8Gi
    persistentvolumeclaims: "2"
```

**2. Network Policies:**

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: kube-bench-netpol
  namespace: security-scans
spec:
  podSelector:
    matchLabels:
      app: kube-bench
  policyTypes:
  - Egress
  egress:
  - to: []
    ports:
    - protocol: TCP
      port: 443  # For webhook notifications
```

**3. RBAC Configuration:**

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: kube-bench
  namespace: security-scans
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: kube-bench
rules:
- apiGroups: [""]
  resources: ["pods", "nodes"]
  verbs: ["get", "list"]
- apiGroups: ["apps"]
  resources: ["deployments", "daemonsets"]
  verbs: ["get", "list"]
```

{{% /expand%}}

---

Congratulations! You now know how to audit a cluster against industry standards, perform security remediations, and implement automated continuous compliance monitoring 🛡️!

## Summary

In this three-part series, you learned:

1. **[Part 1 - Jobs](../kubebench-10-jobs/)**: How to run kube-bench as Kubernetes Jobs and understand security baseline assessment
2. **[Part 2 - Remediations](../kubebench-20-remediations/)**: How to fix critical security issues like scheduler profiling and implement encryption at rest
3. **[Part 3 - Automation](../kubebench-30-automation/)**: How to automate compliance monitoring with CronJobs and integrate with monitoring systems

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