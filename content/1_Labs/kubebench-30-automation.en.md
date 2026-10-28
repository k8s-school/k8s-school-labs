---
title: 'Hardening with CIS Benchmarks - Automation and Continuous Compliance'
date: 2026-01-09T10:00:00+10:00
draft: false
weight: 130
tags: ["Kubernetes", "Security", "CKS", "CIS Benchmark", "Kube-bench", "Automation", "CronJob"]
---

**Author:** Fabrice JAMMES ([LinkedIn](https://www.linkedin.com/in/fabrice-jammes-5b29b042/)).

## Objective

Run kube-bench every week with a `CronJob`, to detect when a security setting of the cluster changes.

Why is running `kube-bench` by hand not enough in production?

{{%expand "Answers" %}}
- **Configuration drift**: an upgrade or a manual change can revert a security setting.
- **New benchmarks**: the CIS updates its recommendations, and kube-bench its checks.
- **Visibility**: the security team needs the results in a central place, not in a terminal.
{{% /expand%}}

## Prerequisites

The Jobs only read the files of the nodes: the lab works on the shared cluster, in a namespace of your own.

```bash
# The shared kind cluster (on the CKS training server: kind export kubeconfig, then kubectx kind-kind)
kubectx kind-kind
NS=kube-bench-cron-$(whoami)
kubectl create namespace $NS
kubectl config set-context --current --namespace=$NS
mkdir -p $HOME/kube-bench-cron && cd $HOME/kube-bench-cron
```

## Exercise 1: a weekly scan

Create a `CronJob` `kube-bench`, which runs the scan of the control plane of the [first lab]({{% ref "/1_Labs/kubebench-10-jobs" %}}) every Sunday at 2 AM. Keep the last 3 successful Jobs.

{{%expand "Solution" %}}
```bash
cat << EOF > kube-bench-cronjob.yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: kube-bench
spec:
  schedule: "0 2 * * 0"  # Every Sunday at 2 AM
  successfulJobsHistoryLimit: 3
  jobTemplate:
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
          containers:
          - name: kube-bench
            image: docker.io/aquasec/kube-bench:v0.14.1
            command: ["kube-bench", "run", "--targets", "master"]
            resources:
              requests: {cpu: 100m, memory: 128Mi}
              limits: {memory: 512Mi}
            volumeMounts:
            - {name: var-lib-etcd, mountPath: /var/lib/etcd, readOnly: true}
            - {name: var-lib-kubelet, mountPath: /var/lib/kubelet, readOnly: true}
            - {name: etc-systemd, mountPath: /etc/systemd, readOnly: true}
            - {name: lib-systemd, mountPath: /lib/systemd/, readOnly: true}
            - {name: etc-kubernetes, mountPath: /etc/kubernetes, readOnly: true}
            - {name: usr-bin, mountPath: /usr/local/mount-from-host/bin, readOnly: true}
          restartPolicy: Never
          volumes:
          - {name: var-lib-etcd, hostPath: {path: /var/lib/etcd}}
          - {name: var-lib-kubelet, hostPath: {path: /var/lib/kubelet}}
          - {name: etc-systemd, hostPath: {path: /etc/systemd}}
          - {name: lib-systemd, hostPath: {path: /lib/systemd}}
          - {name: etc-kubernetes, hostPath: {path: /etc/kubernetes}}
          - {name: usr-bin, hostPath: {path: /usr/bin}}
EOF
kubectl apply -f kube-bench-cronjob.yaml
kubectl get cronjob kube-bench
# NAME         SCHEDULE    TIMEZONE   SUSPEND   ACTIVE   LAST SCHEDULE   AGE
# kube-bench   0 2 * * 0   <none>     False     0        <none>          1s
```
{{% /expand%}}

## Exercise 2: run it now

Do not wait for Sunday: start a Job from the CronJob, and display the summary of its report.

{{%expand "Solution" %}}
```bash
kubectl create job kube-bench-manual --from=cronjob/kube-bench
kubectl wait --for=condition=complete job/kube-bench-manual --timeout=300s
kubectl logs job/kube-bench-manual | grep -A3 "== Summary master =="
# == Summary master ==
# 39 checks PASS
# 10 checks FAIL
# 11 checks WARN
```

`kubectl create job --from=cronjob/<name>` is the way to test a CronJob, or to run it out of its schedule.
{{% /expand%}}

## Exercise 3: detect a change

How would you be alerted when the number of failed checks increases?

{{%expand "Answer" %}}
- kube-bench writes a JSON report with `--json` (or `--outputfile`): a small script compares it with the previous one, and sends an alert.
- The [Trivy Operator](https://github.com/aquasecurity/trivy-operator) runs the CIS benchmark itself and stores the results in `ClusterComplianceReport` objects, which a monitoring system can watch.
- The logs of the Jobs go to the central log system of the cluster (Loki, ELK...), where an alert rule watches the `checks FAIL` line.
{{% /expand%}}

## Summary

1. [Running kube-bench Jobs]({{% ref "/1_Labs/kubebench-10-jobs" %}}): scan the nodes and read the report.
2. [Security remediations]({{% ref "/1_Labs/kubebench-20-remediations" %}}): fix failed checks in the static pod manifests, and check them with a new scan.
3. Automation: run the scan regularly, and watch its results.

## Clean up

```bash
kubectl delete namespace $NS
kubectl config set-context --current --namespace=default
cd $HOME && rm -rf $HOME/kube-bench-cron
```
