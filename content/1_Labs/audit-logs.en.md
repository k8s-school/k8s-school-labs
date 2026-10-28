---
title: 'Audit Logs & API Server'
date: 2024-06-06T15:00:00+10:00
draft: false
weight: 100
tags: ["CKS", "Security", "Audit", "API-server", "Kubernetes", "Control-plane"]
---

**Author:** Fabrice JAMMES ([LinkedIn](https://www.linkedin.com/in/fabrice-jammes-5b29b042/)).

## Objective

- Write an [audit policy](https://kubernetes.io/docs/tasks/debug/debug-cluster/audit/), which chooses what the API server records
- Enable the audit log in the API server, a static pod
- Find in the log who did what

The CKS curriculum lists "Perform deep analytical investigation and identification of malicious activity" and "Use Audit Logs to monitor access" in the *Monitoring, logging and runtime security* domain.

Each request to the API server is recorded at the level of the **first** rule of the policy which matches it:

| Level | Recorded |
|---|---|
| `None` | Nothing |
| `Metadata` | Who, when, which verb on which resource: no body |
| `Request` | Metadata and the body of the request |
| `RequestResponse` | Metadata, and the bodies of the request and of the response |

## Prerequisites

The API server restarts during the lab: use a kind cluster of your own, never a shared one.

```bash
# On the CKS training server, use your own cluster ($CLUSTER_NAME),
# elsewhere create a cluster for the lab
CLUSTER=${CLUSTER_NAME:-audit-$(whoami)}
kind get clusters | grep -qx $CLUSTER || kind create cluster --name $CLUSTER
kubectx kind-$CLUSTER
CP=$CLUSTER-control-plane
```

<!-- ci-exec
# A new cluster: wait for the service account controller
until kubectl get serviceaccount default -n default >/dev/null 2>&1; do sleep 2; done
-->

`$CP` is the control plane node: kind runs it as a docker container, open a shell in it with `docker exec -it $CP bash`. The API server is a static pod: its manifest is `/etc/kubernetes/manifests/kube-apiserver.yaml` on this node (see the [static pods lab]({{% ref "/1_Labs/staticpod" %}})).

## Exercise 1: the audit policy

On the control plane node, write the policy `/etc/kubernetes/audit/policy.yaml`, which:

- does not record the `RequestReceived` stage
- records the requests on `secrets` at the `Metadata` level
- records the requests on `pods` at the `RequestResponse` level
- records nothing else

{{%expand "Solution" %}}
```bash
docker exec $CP mkdir -p /etc/kubernetes/audit
cat <<EOF | docker exec -i $CP tee /etc/kubernetes/audit/policy.yaml
apiVersion: audit.k8s.io/v1
kind: Policy
# One event per request instead of two: skip the event written when the request is received
omitStages:
- RequestReceived
rules:
# Never RequestResponse for the Secrets: the log would contain their values
- level: Metadata
  resources:
  - group: ""
    resources: ["secrets"]
- level: RequestResponse
  resources:
  - group: ""
    resources: ["pods"]
# Everything else: nothing
- level: None
EOF
```

The order matters: the first matching rule wins. A first rule `level: None` would record nothing at all. A request matched by no rule is not recorded: the last rule `level: None` makes it explicit.
{{% /expand%}}

## Exercise 2: enable the audit log

Configure the API server, in its manifest on the control plane node, to:

- use the policy, with `--audit-policy-file`
- write the log in `/var/log/kubernetes/audit/audit.log`, with `--audit-log-path`
- keep the log files 7 days, at most 2 old files of at most 10 MB: `--audit-log-maxage`, `--audit-log-maxbackup`, `--audit-log-maxsize`
- mount the directories of the policy (read-only) and of the log, with `hostPath` volumes

{{% notice warning %}}
Save a copy of the manifest **outside** `/etc/kubernetes/manifests`: the kubelet runs every file of this directory as a static pod.
{{% /notice %}}

{{%expand "Solution" %}}
In the exam, edit the file with `vi`. Here, `sed` does the changes:

```bash
docker exec $CP cp /etc/kubernetes/manifests/kube-apiserver.yaml /root/kube-apiserver.yaml.before-audit
docker exec $CP sed -i \
  -e 's|^    - kube-apiserver$|&\n    - --audit-policy-file=/etc/kubernetes/audit/policy.yaml\n    - --audit-log-path=/var/log/kubernetes/audit/audit.log\n    - --audit-log-maxage=7\n    - --audit-log-maxbackup=2\n    - --audit-log-maxsize=10|' \
  -e 's|^    volumeMounts:$|&\n    - mountPath: /etc/kubernetes/audit\n      name: audit-policy\n      readOnly: true\n    - mountPath: /var/log/kubernetes/audit\n      name: audit-log|' \
  -e 's|^  volumes:$|&\n  - hostPath:\n      path: /etc/kubernetes/audit\n      type: DirectoryOrCreate\n    name: audit-policy\n  - hostPath:\n      path: /var/log/kubernetes/audit\n      type: DirectoryOrCreate\n    name: audit-log|' \
  /etc/kubernetes/manifests/kube-apiserver.yaml
docker exec $CP grep -n "audit" /etc/kubernetes/manifests/kube-apiserver.yaml
```

The kubelet sees the change and re-creates the API server pod. Wait until the API server answers again:

```bash
sleep 10
until kubectl get --raw /readyz >/dev/null 2>&1; do sleep 5; done
docker exec $CP ls -l /var/log/kubernetes/audit/
```

If the API server does not come back: `docker exec $CP sh -c 'crictl ps -a | grep kube-apiserver'`, then `docker exec $CP crictl logs <container-id>`. A typo in a flag, or a policy which is not valid, stops it. Restore the copy if needed: `docker exec $CP cp /root/kube-apiserver.yaml.before-audit /etc/kubernetes/manifests/kube-apiserver.yaml`.
{{% /expand%}}

## Exercise 3: investigate

Create a Secret `db-password` with the value `s3cr3t`, read it, delete it, and run a pod `web` (image `nginx:1.27`). Then find in the audit log:

1. who deleted the Secret, and when
2. whether the value of the Secret is in the log
3. the image of the pod `web`, from the log only

{{% notice tip %}}
The log has one JSON event per line: filter it with `jq 'select(...)'` on `.verb`, `.objectRef.resource`, `.objectRef.name`, `.user.username`.
{{% /notice %}}

{{%expand "Solution" %}}
```bash
kubectl create secret generic db-password --from-literal=password=s3cr3t
kubectl get secret db-password -o yaml >/dev/null
kubectl delete secret db-password
kubectl run web --image=nginx:1.27
sleep 5

docker exec $CP cat /var/log/kubernetes/audit/audit.log > audit.log
jq -c 'select(.objectRef.resource=="secrets" and .objectRef.name=="db-password")
  | {verb, user: .user.username, time: .requestReceivedTimestamp}' audit.log
# {"verb":"create","user":"kubernetes-admin","time":"..."}
# {"verb":"get","user":"kubernetes-admin","time":"..."}
# {"verb":"delete","user":"kubernetes-admin","time":"..."}
# {"verb":"get","user":"kubernetes-admin","time":"..."}  <- kubectl delete waits until the Secret is gone

grep -c s3cr3t audit.log || echo "EXPECTED: the value is not in the log"
# 0

jq -r 'select(.objectRef.resource=="pods" and .objectRef.name=="web" and .verb=="create")
  | .requestObject.spec.containers[].image' audit.log
# nginx:1.27
```

At the `Metadata` level, the log says who read or deleted a Secret, never its value. At the `RequestResponse` level, it contains the full objects: the pod spec, and also its environment variables.

`kubernetes-admin` is the user of your kubeconfig, authenticated by its client certificate. For a pod, the user is `system:serviceaccount:<namespace>:<name>`: the log shows which application used its token.
{{% /expand%}}

## Questions

1. Why is `RequestResponse` on `secrets` a security problem?
2. An attacker is root on the control plane node. What can they do with the audit log?

{{%expand "Answers" %}}
1. The response of `get secret` contains its value: the audit log would hold all the Secrets of the cluster, readable by anybody who reads the log files or the log collector.
2. Change the policy or delete the log files to hide their actions. Send the log to an external system as soon as it is written (`--audit-webhook-config-file`, or a log collector on the node), where the attackers of the cluster have no access.
{{% /expand%}}

## Clean up

```bash
kubectl delete pod web
rm -f audit.log
# Disable the audit log: restore the manifest
docker exec $CP cp /root/kube-apiserver.yaml.before-audit /etc/kubernetes/manifests/kube-apiserver.yaml
sleep 10
until kubectl get --raw /readyz >/dev/null 2>&1; do sleep 5; done
# Delete the cluster only if it was created for the lab
if [ -z "${CLUSTER_NAME:-}" ]; then kind delete cluster --name $CLUSTER; fi
```

The [apiserver-auditlogs.sh](https://github.com/k8s-school/k8s-advanced/blob/master/labs/1_internals/apiserver-auditlogs.sh) script of the k8s-advanced repository runs a similar scenario.
