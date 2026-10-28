---
title: 'Hardening with CIS Benchmarks - Security Remediations'
date: 2026-01-09T10:00:00+10:00
draft: false
weight: 125
tags: ["Kubernetes", "Security", "CKS", "CIS Benchmark", "Kube-bench", "Hardening", "Remediations"]
---

**Author:** Fabrice JAMMES ([LinkedIn](https://www.linkedin.com/in/fabrice-jammes-5b29b042/)).

## Objective

Fix failed checks of the [kube-bench report]({{% ref "/1_Labs/kubebench-10-jobs" %}}) by editing the static pod manifests of the control plane, then check the fix with a new scan. It is the typical CKS task: "fix the issues reported by kube-bench on the control plane".

## Prerequisites

The control plane components restart during the lab: use a kind cluster of your own, never a shared one.

```bash
# On the CKS training server, use your own cluster ($CLUSTER_NAME),
# elsewhere create a cluster for the lab
CLUSTER=${CLUSTER_NAME:-kube-bench-$(whoami)}
kind get clusters | grep -qx $CLUSTER || kind create cluster --name $CLUSTER
kind export kubeconfig --name $CLUSTER
CP=$CLUSTER-control-plane
kubectl create namespace kube-bench
kubectl config set-context --current --namespace=kube-bench
mkdir -p $HOME/kube-bench && cd $HOME/kube-bench
```

<!-- ci-exec
# A new cluster: wait for the service account of the namespace
until kubectl get serviceaccount default >/dev/null 2>&1; do sleep 2; done
-->

The Job of the [previous lab]({{% ref "/1_Labs/kubebench-10-jobs" %}}), which scans the control plane, and a function which runs it again and displays the result of some checks:

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

# Usage: scan <check id>...
scan() {
  kubectl delete job kube-bench-master --ignore-not-found >/dev/null
  kubectl apply -f kube-bench-master.yaml >/dev/null
  kubectl wait --for=condition=complete job/kube-bench-master --timeout=300s >/dev/null
  for check in "$@"; do
    kubectl logs job/kube-bench-master | grep "^\[[A-Z]*\] $check "
  done
}
scan 1.4.1 1.3.2
# [FAIL] 1.4.1 Ensure that the --profiling argument is set to false (Automated)
# [FAIL] 1.3.2 Ensure that the --profiling argument is set to false (Automated)
```

## Exercise 1: the profiling of the scheduler

Check `1.4.1`: the scheduler serves profiling data (`/debug/pprof`), which shows details on the internals of the cluster and can be used to overload it.

1. Which is the default value of `--profiling` for the scheduler? Is the flag set in its manifest?
2. Set `--profiling=false` in the manifest of the scheduler, on the control plane node. Save a copy of the manifest first, **outside** `/etc/kubernetes/manifests`.
3. Scan again.

{{%expand "Solution" %}}
```bash
kubectl exec -n kube-system kube-scheduler-$CP -- kube-scheduler --help | grep -A1 -- "--profiling"
#       --profiling                 DEPRECATED: enable profiling via web interface host:port/debug/pprof/ ... (default true)
docker exec $CP grep -c profiling /etc/kubernetes/manifests/kube-scheduler.yaml || echo "not set"
# not set
```

In the exam, edit the manifest with `vi`, on the control plane node:

<!-- ci-skip -->
```bash
docker exec -it $CP bash
# In the node
cp /etc/kubernetes/manifests/kube-scheduler.yaml /root/kube-scheduler.yaml.orig
apt-get update && apt-get install -y vim
vi /etc/kubernetes/manifests/kube-scheduler.yaml
# Add the line "    - --profiling=false" after "    - kube-scheduler"
```

Or with `sed`, from the server:

```bash
docker exec $CP cp /etc/kubernetes/manifests/kube-scheduler.yaml /root/kube-scheduler.yaml.orig
docker exec $CP sed -i 's|^    - kube-scheduler$|&\n    - --profiling=false|' /etc/kubernetes/manifests/kube-scheduler.yaml
docker exec $CP grep -A2 "^    - kube-scheduler$" /etc/kubernetes/manifests/kube-scheduler.yaml
```

The kubelet re-creates the scheduler pod: wait until the new pod runs with the flag, then scan again.

```bash
until kubectl get pod -n kube-system kube-scheduler-$CP -o jsonpath='{.spec.containers[0].command}' 2>/dev/null | grep -q profiling=false; do sleep 5; done
kubectl wait -n kube-system --for=condition=Ready pod/kube-scheduler-$CP --timeout=120s
scan 1.4.1
# [PASS] 1.4.1 Ensure that the --profiling argument is set to false (Automated)
```

If the scheduler does not come back, the YAML is not valid: `docker exec $CP sh -c 'crictl ps -a | grep scheduler'`, read its logs with `crictl logs`, or restore the copy.
{{% /expand%}}

## Exercise 2: the controller manager

Fix the check `1.3.2` alone: the same flag, for the controller manager.

{{%expand "Solution" %}}
```bash
docker exec $CP cp /etc/kubernetes/manifests/kube-controller-manager.yaml /root/kube-controller-manager.yaml.orig
docker exec $CP sed -i 's|^    - kube-controller-manager$|&\n    - --profiling=false|' /etc/kubernetes/manifests/kube-controller-manager.yaml
until kubectl get pod -n kube-system kube-controller-manager-$CP -o jsonpath='{.spec.containers[0].command}' 2>/dev/null | grep -q profiling=false; do sleep 5; done
kubectl wait -n kube-system --for=condition=Ready pod/kube-controller-manager-$CP --timeout=120s
scan 1.3.2
# [PASS] 1.3.2 Ensure that the --profiling argument is set to false (Automated)
```

The same method fixes `1.2.15` for the API server. For the audit log checks (`1.2.16` to `1.2.19`), see the [audit logs lab]({{% ref "/1_Labs/audit-logs" %}}), and for the encryption of the Secrets (`1.2.27`, `1.2.28`), the [etcd encryption lab]({{% ref "/1_Labs/etcd-encryption" %}}).
{{% /expand%}}

## Questions

1. Why save the copy of a manifest outside `/etc/kubernetes/manifests`?
2. The fix of a kubelet check (target `node`) is in which file?

{{%expand "Answers" %}}
1. The kubelet runs every file of this directory as a static pod: a copy there would start a second scheduler, or fail on a duplicate name. See the [static pods lab]({{% ref "/1_Labs/staticpod" %}}).
2. In the configuration file of the kubelet, `/var/lib/kubelet/config.yaml` on kubeadm clusters (its path is given by `--config` in the command line of the kubelet), or in its flags (`/etc/systemd/system/kubelet.service.d/`). The kubelet is not a static pod: restart it with `systemctl restart kubelet`.
{{% /expand%}}

## Clean up

```bash
docker exec $CP cp /root/kube-scheduler.yaml.orig /etc/kubernetes/manifests/kube-scheduler.yaml
docker exec $CP cp /root/kube-controller-manager.yaml.orig /etc/kubernetes/manifests/kube-controller-manager.yaml
kubectl delete namespace kube-bench
kubectl config set-context --current --namespace=default
cd $HOME && rm -rf $HOME/kube-bench
# Delete the cluster only if it was created for the lab
if [ -z "${CLUSTER_NAME:-}" ]; then kind delete cluster --name $CLUSTER; fi
```

Next: [Hardening with CIS Benchmarks - Automation and Continuous Compliance]({{% ref "/1_Labs/kubebench-30-automation" %}}).
