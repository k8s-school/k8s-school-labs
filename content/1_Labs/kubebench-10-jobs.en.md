---
title: 'Hardening with CIS Benchmarks - Running kube-bench Jobs'
date: 2026-01-09T10:00:00+10:00
draft: false
weight: 120
tags: ["Kubernetes", "Security", "CKS", "CIS Benchmark", "Kube-bench", "Jobs"]
---

**Author:** Fabrice JAMMES ([LinkedIn](https://www.linkedin.com/in/fabrice-jammes-5b29b042/)).

## Objective

The [Center for Internet Security (CIS)](https://www.cisecurity.org/benchmark/kubernetes) publishes a benchmark of security recommendations for Kubernetes. [kube-bench](https://github.com/aquasecurity/kube-bench), from Aqua Security, checks a node against it.

In this lab, you run kube-bench as Kubernetes Jobs, on the control plane and on a worker, and read its report. The [next lab]({{% ref "/1_Labs/kubebench-20-remediations" %}}) fixes some of the failed checks.

The CKS curriculum lists "Use CIS benchmark to review the security configuration of Kubernetes components" in the *Cluster setup* domain.

## Prerequisites

The Jobs only read the files of the nodes: the lab works on the shared cluster, in a namespace of your own.

```bash
# The shared kind cluster (on the CKS training server: kind export kubeconfig, then kubectx kind-kind)
kubectx kind-kind
NS=kube-bench-$(whoami)
kubectl create namespace $NS
kubectl config set-context --current --namespace=$NS
mkdir -p $HOME/kube-bench && cd $HOME/kube-bench
```

## Exercise 1: scan the control plane

kube-bench must run on the node it checks, with the PID namespace of the node (to see the processes of the control plane) and the configuration directories of the node mounted read-only. Aqua Security publishes a [job.yaml](https://github.com/aquasecurity/kube-bench/blob/main/job.yaml).

Write a Job `kube-bench-master`, which runs `kube-bench run --targets master` (image `docker.io/aquasec/kube-bench:v0.14.1`) on the control plane node. Run it, and display the summary of the report.

{{% notice tip %}}
The control plane node has the label `node-role.kubernetes.io/control-plane` and a taint with the same key: use a `nodeSelector` and a `toleration`.
{{% /notice %}}

{{%expand "Solution" %}}
```bash
cat <<EOF > kube-bench-master.yaml
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
      containers:
      - name: kube-bench
        image: docker.io/aquasec/kube-bench:v0.14.1
        command: ["kube-bench", "run", "--targets", "master"]
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
kubectl apply -f kube-bench-master.yaml
kubectl wait --for=condition=complete job/kube-bench-master --timeout=300s
kubectl logs job/kube-bench-master > master.txt
grep -A3 "== Summary master ==" master.txt
# == Summary master ==
# 39 checks PASS
# 10 checks FAIL
# 11 checks WARN
```

`hostPID: true` lets kube-bench see the command lines of the control plane processes (`kube-apiserver --profiling=...`): it checks their flags there, and the files of the manifests in `/etc/kubernetes`.
{{% /expand%}}

## Exercise 2: read the report

List the failed checks. For each one, the report gives a remediation: display the one of check `1.4.1`. Which failed checks are covered by other labs of the training?

{{%expand "Solution" %}}
```bash
grep "^\[FAIL\]" master.txt
# [FAIL] 1.1.12 Ensure that the etcd data directory ownership is set to etcd:etcd (Automated)
# [FAIL] 1.2.5 Ensure that the --kubelet-certificate-authority argument is set as appropriate (Automated)
# [FAIL] 1.2.15 Ensure that the --profiling argument is set to false (Automated)
# [FAIL] 1.2.16 Ensure that the --audit-log-path argument is set (Automated)
# [FAIL] 1.2.17 Ensure that the --audit-log-maxage argument is set to 30 or as appropriate (Automated)
# [FAIL] 1.2.18 Ensure that the --audit-log-maxbackup argument is set to 10 or as appropriate (Automated)
# [FAIL] 1.2.19 Ensure that the --audit-log-maxsize argument is set to 100 or as appropriate (Automated)
# [FAIL] 1.2.30 Ensure that the --service-account-extend-token-expiration parameter is set to false (Automated)
# [FAIL] 1.3.2 Ensure that the --profiling argument is set to false (Automated)
# [FAIL] 1.4.1 Ensure that the --profiling argument is set to false (Automated)
grep -A4 "^1.4.1 " master.txt
# 1.4.1 Edit the Scheduler pod specification file /etc/kubernetes/manifests/kube-scheduler.yaml file
# on the control plane node and set the below parameter.
# --profiling=false
```

- `1.2.16` to `1.2.19`: the audit log of the API server, see the [audit logs lab]({{% ref "/1_Labs/audit-logs" %}}).
- `1.2.30`: the service account tokens valid for one year, see the [Service Account Token lab]({{% ref "/1_Labs/service-account" %}}).
- `1.2.15`, `1.3.2`, `1.4.1`: the profiling endpoints of the API server, the controller manager and the scheduler, see the [next lab]({{% ref "/1_Labs/kubebench-20-remediations" %}}).
- The `WARN` checks are manual: for example `1.2.27` and `1.2.28`, the encryption of the Secrets at rest, see the [etcd encryption lab]({{% ref "/1_Labs/etcd-encryption" %}}).

A benchmark is a list of recommendations, not of bugs: some checks do not apply to every cluster (`1.1.12`: kind runs etcd without an `etcd` user). Fix what applies, and document the others.
{{% /expand%}}

## Exercise 3: scan a worker node

Write a Job `kube-bench-node`, which runs `kube-bench run --targets node`. Which components does it check?

{{%expand "Solution" %}}
```bash
sed -e 's/kube-bench-master/kube-bench-node/' -e 's/"--targets", "master"/"--targets", "node"/' \
  -e '/nodeSelector:/,/node-role.kubernetes.io\/control-plane: ""/d' \
  kube-bench-master.yaml > kube-bench-node.yaml
kubectl apply -f kube-bench-node.yaml
kubectl wait --for=condition=complete job/kube-bench-node --timeout=300s
kubectl logs job/kube-bench-node > node.txt
grep "^\[INFO\] 4" node.txt
# [INFO] 4 Worker Node Security Configuration
# [INFO] 4.1 Worker Node Configuration Files
# [INFO] 4.2 Kubelet
# [INFO] 4.3 kube-proxy
grep -A3 "== Summary node ==" node.txt
```

Without `nodeSelector`, the scheduler puts the Job on any node, a worker on a cluster with workers. The `node` target checks the kubelet (its configuration file and flags) and kube-proxy: the components of every node.
{{% /expand%}}

## Clean up

```bash
kubectl delete namespace $NS
kubectl config set-context --current --namespace=default
cd $HOME && rm -rf $HOME/kube-bench
```
