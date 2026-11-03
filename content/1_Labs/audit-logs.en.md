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
kind export kubeconfig --name $CLUSTER
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
# In the exam: ssh to the control plane node, then run the command without docker exec
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
**Very important for the CKS exam**: save a copy of the manifest **outside** `/etc/kubernetes/manifests`, e.g. in `/root`. The kubelet runs every file of this directory as a static pod: a backup copy there would start a second API server.
{{% /notice %}}

{{%expand "Solution" %}}
In the exam, edit the file with `vi`. Here, `sed` does the changes:

```bash
# In the exam: ssh to the control plane node, then run the command without docker exec
docker exec $CP cp /etc/kubernetes/manifests/kube-apiserver.yaml /root/kube-apiserver.yaml.before-audit
docker exec $CP sed -i \
  -e 's|^    - kube-apiserver$|&\n    - --audit-policy-file=/etc/kubernetes/audit/policy.yaml\n    - --audit-log-path=/var/log/kubernetes/audit/audit.log\n    - --audit-log-maxage=7\n    - --audit-log-maxbackup=2\n    - --audit-log-maxsize=10|' \
  -e 's|^    volumeMounts:$|&\n    - mountPath: /etc/kubernetes/audit\n      name: audit-policy\n      readOnly: true\n    - mountPath: /var/log/kubernetes/audit\n      name: audit-log|' \
  -e 's|^  volumes:$|&\n  - hostPath:\n      path: /etc/kubernetes/audit\n      type: DirectoryOrCreate\n    name: audit-policy\n  - hostPath:\n      path: /var/log/kubernetes/audit\n      type: DirectoryOrCreate\n    name: audit-log|' \
  /etc/kubernetes/manifests/kube-apiserver.yaml
# Check the changes against the backup
# diff exits with code 1 when the files differ, which is the expected case here:
# "|| true" prevents a script running with "set -e" (like the CI of this page) from stopping
docker exec $CP diff -u /root/kube-apiserver.yaml.before-audit /etc/kubernetes/manifests/kube-apiserver.yaml || true
```

The diff shows the additions: the flags, the two `volumeMounts` and the two `hostPath` volumes:

```diff
@@ -14,2 +14,7 @@
     - kube-apiserver
+    - --audit-policy-file=/etc/kubernetes/audit/policy.yaml
+    - --audit-log-path=/var/log/kubernetes/audit/audit.log
+    - --audit-log-maxage=7
+    - --audit-log-maxbackup=2
+    - --audit-log-maxsize=10
     - --advertise-address=172.18.0.5
@@ -82,2 +87,7 @@
     volumeMounts:
+    - mountPath: /etc/kubernetes/audit
+      name: audit-policy
+      readOnly: true
+    - mountPath: /var/log/kubernetes/audit
+      name: audit-log
     - mountPath: /etc/ssl/certs
@@ -104,3 +114,11 @@
   volumes:
   - hostPath:
+      path: /etc/kubernetes/audit
+      type: DirectoryOrCreate
+    name: audit-policy
+  - hostPath:
+      path: /var/log/kubernetes/audit
+      type: DirectoryOrCreate
+    name: audit-log
+  - hostPath:
       path: /etc/ssl/certs
```

The kubelet sees the change and re-creates the API server pod. Wait until the API server answers again:

```bash
sleep 10
until kubectl get --raw /readyz >/dev/null 2>&1; do sleep 5; done
# In the exam: ssh to the control plane node, then run the command without docker exec
docker exec $CP ls -l /var/log/kubernetes/audit/
```

If the API server does not come back, a typo in a flag or a policy which is not valid stops it. Read its logs, and restore the copy if needed:

<!-- ci-skip -->
```bash
# In the exam: ssh to the control plane node, then run the commands without docker exec
docker exec $CP sh -c 'crictl ps -a | grep kube-apiserver'
docker exec $CP crictl logs <container-id>
docker exec $CP cp /root/kube-apiserver.yaml.before-audit /etc/kubernetes/manifests/kube-apiserver.yaml
```
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

# In the exam: ssh to the control plane node, then run the command without docker exec
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

## Bonus: who runs `kubectl exec`?

Run `kubectl exec web -- whoami`. Is it in the audit log? Change the policy so that the `kubectl exec` commands are recorded at the `Metadata` level, then find in the log who ran which command in which pod.

{{% notice tip %}}
`kubectl exec` calls the **subresource** `pods/exec`: the rule on `pods` does not match it, and neither does it match `pods/log`, `pods/status` or `pods/binding`. The API server reads the policy at startup only.
{{% /notice %}}

{{%expand "Solution" %}}
```bash
kubectl wait --for=condition=Ready pod/web --timeout=120s
kubectl exec web -- whoami
sleep 5
# In the exam: ssh to the control plane node, then run the command without docker exec
docker exec $CP cat /var/log/kubernetes/audit/audit.log | jq -c 'select(.objectRef.subresource=="exec")' | grep -c . || echo "EXPECTED: no exec event"
# 0
```

Add a rule for `pods/exec`, before the last rule `level: None`:

```bash
# In the exam: ssh to the control plane node, then run the command without docker exec
cat <<EOF | docker exec -i $CP tee /etc/kubernetes/audit/policy.yaml
apiVersion: audit.k8s.io/v1
kind: Policy
omitStages:
- RequestReceived
rules:
- level: Metadata
  resources:
  - group: ""
    resources: ["secrets"]
# kubectl exec and attach: who, in which pod, which command (in the URI)
- level: Metadata
  resources:
  - group: ""
    resources: ["pods/exec", "pods/attach"]
- level: RequestResponse
  resources:
  - group: ""
    resources: ["pods"]
- level: None
EOF
```

Restart the API server, so that it reads the new policy: stop its container, the kubelet starts it again with the same manifest.

```bash
# In the exam: ssh to the control plane node, then run the command without docker exec
docker exec $CP sh -c 'crictl stop $(crictl ps --name kube-apiserver -q)'
sleep 10
until kubectl get --raw /readyz >/dev/null 2>&1; do sleep 5; done

kubectl exec web -- whoami
sleep 5
docker exec $CP cat /var/log/kubernetes/audit/audit.log \
  | jq -c 'select(.objectRef.subresource=="exec") | {stage, user: .user.username, pod: .objectRef.name, verb, uri: .requestURI}'
# {"stage":"ResponseStarted","user":"kubernetes-admin","pod":"web","verb":"get","uri":"/api/v1/namespaces/default/pods/web/exec?command=whoami&container=web&stderr=true&stdout=true"}
# {"stage":"ResponseComplete","user":"kubernetes-admin","pod":"web","verb":"get","uri":"/api/v1/namespaces/default/pods/web/exec?command=whoami&container=web&stderr=true&stdout=true"}
```

Two events for one command: `exec` is a long-running request, recorded when the stream starts (`ResponseStarted`) and when it ends (`ResponseComplete`).

The command is in the `command` parameters of the URI: here `whoami`. With a shell (`kubectl exec -it web -- sh`), the log shows `command=sh`, not the commands typed in the shell: they never reach the API server. [Falco]({{% ref "/1_Labs/falco" %}}) sees them, on the node.

The verb is `get` with a recent `kubectl` (WebSocket), `create` with an older one (SPDY): do not filter on it.
{{% /expand%}}

## Bonus: stream the audit log to a log backend

The audit log of this lab stays on the control plane node. How do you send it to a log backend (Loki, Elasticsearch, Splunk...)? No exercise here, read the two options.

{{%expand "Answer" %}}
**1. Log file + collector agent (the most common).** Keep the `log` backend of this lab, and run a collector (Fluent Bit, Vector, Grafana Alloy) as a DaemonSet on the control plane nodes: it tails `/var/log/kubernetes/audit/audit.log` (read-only `hostPath`, toleration for the control plane taint) and ships the events.

```ini
# Fluent Bit, excerpt
[INPUT]
    Name   tail
    Path   /var/log/kubernetes/audit/audit.log
    Parser json
    Tag    k8s-audit
[OUTPUT]
    Name   loki
    Match  k8s-audit
    Host   loki.monitoring.svc
```

The file is a buffer: when the backend is down, nothing is lost, and the API server never waits for the network. Keep the rotation flags (`--audit-log-maxsize`, `--audit-log-maxbackup`, `--audit-log-maxage`).

**2. Webhook backend.** The API server itself POSTs the events to an HTTP receiver (Fluent Bit or Logstash HTTP input, Vector, the `k8saudit` plugin of Falco):

```text
--audit-policy-file=/etc/kubernetes/audit/policy.yaml
--audit-webhook-config-file=/etc/kubernetes/audit/webhook.yaml
--audit-webhook-mode=batch        # batch (default), blocking, blocking-strict
```

```yaml
# webhook.yaml: a kubeconfig, whose "cluster" is the receiver
apiVersion: v1
kind: Config
clusters:
- name: audit-sink
  cluster:
    server: https://audit-sink.example.com/k8s-audit
    certificate-authority: /etc/kubernetes/audit/audit-sink-ca.crt
contexts:
- name: default
  context:
    cluster: audit-sink
    user: ""
current-context: default
users: []
```

Real time and no agent on the nodes, but a trade-off: in `batch` mode, the buffered events are lost when the receiver stays down; in `blocking` mode, the API server slows down with it. As for the log backend, the files the API server reads (`webhook.yaml`, the CA) must be mounted in its static pod.

Both backends can be enabled together: the file as a reliable local trail, the webhook as the real-time stream. On a managed cluster, there is no API server flag: enable the option of the provider (EKS control plane logs to CloudWatch, GKE Cloud Audit Logs, AKS diagnostic settings).

Reference: [Auditing, backends](https://kubernetes.io/docs/tasks/debug/debug-cluster/audit/#audit-backends).
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
# In the exam: ssh to the control plane node, then run the command without docker exec
docker exec $CP cp /root/kube-apiserver.yaml.before-audit /etc/kubernetes/manifests/kube-apiserver.yaml
sleep 10
until kubectl get --raw /readyz >/dev/null 2>&1; do sleep 5; done
# Delete the cluster only if it was created for the lab
if [ -z "${CLUSTER_NAME:-}" ]; then kind delete cluster --name $CLUSTER; fi
```

The [apiserver-auditlogs.sh](https://github.com/k8s-school/k8s-advanced/blob/master/labs/1_internals/apiserver-auditlogs.sh) script of the k8s-advanced repository runs a similar scenario.
