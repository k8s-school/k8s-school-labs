---
title: 'Troubleshooting an application from A to Z'
date: 2026-10-21T08:00:00+02:00
draft: false
weight: 154
tags: ["kubernetes", "troubleshooting", "K9s", "OpenShift", "SCC"]
---

## Objective

An application has been deployed, and it does not answer. It hides one fault per layer: each fault only shows up once the previous one is fixed, as in real life. In this lab you will:

- Follow a method, from the pod scheduling up to the Service
- Read the pod status, the events and the logs, including the logs of a crashed container
- Check the Service from inside the cluster
- On OpenShift, diagnose a crash caused by the SCC, and reproduce it with `oc debug`

Complete this lab in 60 minutes.

## Prerequisites

- A Kubernetes cluster (kind is fine) with `kubectl`, and optionally [K9s](https://k9scli.io/) (`ktbx install k9s`)
- For the last exercise: an OpenShift cluster with `oc`
- The labs [Deployments: rolling update, rollback and canary]({{% ref "/1_Labs/rollout" %}}) and [OpenShift Security Context Constraints]({{% ref "/1_Labs/openshift-scc" %}})

## The method

Start from the pods, and go up one layer at a time:

| Symptom | Layer | Commands |
|---|---|---|
| `Pending` | Scheduling: resources, taints, affinity, PVC | `kubectl describe pod`, `kubectl get events` |
| `ErrImagePull`, `ImagePullBackOff` | Image: name, tag, registry, pull secret | `kubectl describe pod` |
| `CreateContainerConfigError` | Configuration: ConfigMap, Secret | `kubectl describe pod` |
| `CrashLoopBackOff`, `Error` | Application: the container starts then exits | `kubectl logs --previous` |
| `Running` but `0/1` ready | Readiness probe | `kubectl describe pod` |
| Pods ready, Service does not answer | Service: selector, ports | `kubectl get endpointslices`, `curl` from a pod |

{{% notice tip %}}
In K9s, the same steps are keyboard shortcuts on the pods view (`:pods`): `d` describe, `l` logs, `p` previous logs, `s` shell, `y` YAML. `:events` lists the events of the namespace.
{{% /notice %}}

## Setup

```bash
ID=$(whoami)
NS=troubleshoot-$ID
kubectl create namespace $NS
kubectl config set-context --current --namespace=$NS

# A client pod, to test the application from inside the cluster
kubectl run client --image=curlimages/curl:8.10.1 -- sleep infinity
```

Deploy the application. Do not read the manifest to find the faults: diagnose them from the cluster.

```bash
mkdir -p $HOME/tmp
cat <<'EOF' > $HOME/tmp/web.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: web-config
data:
  default.conf: |
    server {
      listen 8080;
      location = / {
        return 200 "Hello from $hostname\n";
      }
      location = /healthz {
        return 200 "ok\n"
      }
    }
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
spec:
  replicas: 2
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      containers:
      - name: nginx
        image: nginx:1.27-alpne
        ports:
        - containerPort: 8080
        env:
        - name: WELCOME_MESSAGE
          valueFrom:
            configMapKeyRef:
              name: web-config
              key: message
        resources:
          requests:
            memory: 64Gi
        readinessProbe:
          httpGet:
            path: /health
            port: 8080
        volumeMounts:
        - name: config
          mountPath: /etc/nginx/conf.d
      volumes:
      - name: config
        configMap:
          name: web-config
---
apiVersion: v1
kind: Service
metadata:
  name: web
spec:
  selector:
    app: web-app
  ports:
  - port: 80
    targetPort: 80
EOF
kubectl apply -f $HOME/tmp/web.yaml
```

The goal: `kubectl exec client -- curl -sS http://web` answers `Hello from web-...`.

{{% notice note %}}
Each fix creates a new ReplicaSet. The pods of the previous, broken ReplicaSets can stay around until the rollout completes: always look at the newest pods (`kubectl get pods --sort-by=.metadata.creationTimestamp`).
{{% /notice %}}

## Exercise 1: the pods are Pending

Why are the pods not scheduled? Fix the Deployment.

{{%expand "Solution" %}}
```bash
kubectl get pods
kubectl describe pod -l app=web | grep -A3 Events
# Warning  FailedScheduling  default-scheduler  0/4 nodes are available: 1 node(s) had untolerated taint(s),
#   3 Insufficient memory. preemption: 0/4 nodes are available: 4 Preemption is not helpful for scheduling.
```

The pods request 64Gi of memory: no node can host them. The scheduler only considers the requests, not the actual usage. The control-plane node is excluded by its taint.

```bash
kubectl set resources deployment web --requests=memory=64Mi
```
{{% /expand%}}

## Exercise 2: the image

{{%expand "Solution" %}}
```bash
kubectl get pods --sort-by=.metadata.creationTimestamp
# web-79cfc88b6d-rf4kp   0/1     ImagePullBackOff   0          15s
kubectl describe pod web-79cfc88b6d-rf4kp | grep Failed
# Failed to pull image "nginx:1.27-alpne": ... docker.io/library/nginx:1.27-alpne: not found
```

`ErrImagePull` is the first failure, `ImagePullBackOff` means the kubelet waits longer and longer between retries. `not found` is a typo in the tag. A missing pull secret or a private registry gives `unauthorized` or `access denied` instead.

```bash
kubectl set image deployment web nginx=nginx:1.27-alpine
```
{{% /expand%}}

## Exercise 3: CreateContainerConfigError

{{%expand "Solution" %}}
```bash
kubectl describe pod -l app=web | grep Error:
# Error: couldn't find key message in ConfigMap troubleshoot-<id>/web-config
```

The image is pulled, but the kubelet cannot build the container environment: the ConfigMap `web-config` has no key `message`. A missing ConfigMap or Secret gives the same status. The kubelet retries by itself: no restart is needed once the key exists.

```bash
kubectl patch configmap web-config --type=merge -p '{"data":{"message":"Welcome"}}'
```
{{% /expand%}}

## Exercise 4: CrashLoopBackOff

{{%expand "Solution" %}}
```bash
kubectl get pods --sort-by=.metadata.creationTimestamp
# web-554f8678d7-zt57d   0/1     CrashLoopBackOff   2 (7s ago)   49s
kubectl logs web-554f8678d7-zt57d
kubectl logs web-554f8678d7-zt57d --previous
# nginx: [emerg] unexpected "}" in /etc/nginx/conf.d/default.conf:8
```

The container starts, then exits: the logs of the **previous** container explain why. Here the nginx configuration, mounted from the ConfigMap, lacks a `;` line 7.

Fix the ConfigMap, then restart the pods: the kubelet updates a mounted ConfigMap after up to a minute, and nginx only reads its configuration at startup.

```bash
kubectl edit configmap web-config
# return 200 "ok\n";
kubectl rollout restart deployment web
```
{{% /expand%}}

## Exercise 5: Running, but not ready

{{%expand "Solution" %}}
```bash
kubectl get pods
# web-67547c8b6f-qj4tl   0/1     Running   0          30s
kubectl describe pod -l app=web | grep Unhealthy
# Warning  Unhealthy  kubelet  Readiness probe failed: HTTP probe failed with statuscode: 404
```

The application runs, but the readiness probe calls `/health` instead of `/healthz`. A pod which is not ready is not added to the Service endpoints, and the rollout does not progress. A failing **liveness** probe would restart the container instead.

`connection refused` in the probe events right after the start is normal: nginx is not listening yet.

```bash
kubectl patch deployment web --type=json \
  -p '[{"op":"replace","path":"/spec/template/spec/containers/0/readinessProbe/httpGet/path","value":"/healthz"}]'
kubectl rollout status deployment web
```
{{% /expand%}}

## Exercise 6: the Service does not answer

The pods are ready. Call the Service from the client pod, and fix it.

{{%expand "Solution" %}}
```bash
kubectl exec client -- curl -sS -m 5 http://web
# curl: (7) Failed to connect to web port 80 after 0 ms: Could not connect to server
kubectl get endpointslices -l kubernetes.io/service-name=web
# NAME        ADDRESSTYPE   PORTS     ENDPOINTS   AGE
# web-nb6qx   IPv4          <unset>   <unset>     69s
```

No endpoint: the Service selector `app=web-app` matches no pod.

```bash
kubectl get pods --show-labels
kubectl patch service web -p '{"spec":{"selector":{"app":"web"}}}'
kubectl get endpointslices -l kubernetes.io/service-name=web
# web-nb6qx   IPv4          80      10.244.1.7,10.244.3.10   69s
kubectl exec client -- curl -sS -m 5 http://web
# curl: (7) Failed to connect to web port 80 after 0 ms: Could not connect to server
```

Same symptom, different cause. Call a pod directly, to split the problem in two:

```bash
POD_IP=$(kubectl get pod -l app=web -o jsonpath='{.items[0].status.podIP}')
kubectl exec client -- curl -sS -m 5 http://$POD_IP:8080
# Hello from web-cf9c98b97-gbfrv
kubectl get service web -o jsonpath='{.spec.ports}'
# [{"port":80,"protocol":"TCP","targetPort":80}]
```

The pod answers on port 8080, but the Service sends the traffic to port 80 of the pods:

```bash
kubectl patch service web --type=json -p '[{"op":"replace","path":"/spec/ports/0/targetPort","value":8080}]'
kubectl exec client -- curl -sS -m 5 http://web
# Hello from web-cf9c98b97-tfcqc
```

kube-proxy needs a few seconds to update the node rules: retry if the first call fails.
{{% /expand%}}

## Exercise 7: on OpenShift

Deploy the application on OpenShift, with the fixes of exercises 1 to 6:

```bash
oc new-project troubleshoot-$ID
oc run client --image=curlimages/curl:8.10.1 -- sleep infinity
sed -e 's/1.27-alpne/1.27-alpine/; s/64Gi/64Mi/; s|path: /health$|path: /healthz|; s/app: web-app/app: web/' \
  -e 's/targetPort: 80$/targetPort: 8080/; s/return 200 "ok\\n"$/return 200 "ok\\n";/; s/^data:$/data:\n  message: Welcome/' \
  $HOME/tmp/web.yaml > $HOME/tmp/web-fixed.yaml
oc apply -f $HOME/tmp/web-fixed.yaml
```

The pods crash. Diagnose why, and fix the Deployment **without** granting a new SCC.

{{%expand "Solution" %}}
```bash
oc get pods
# web-649b7d686c-nfpvl   0/1     CrashLoopBackOff   2 (19s ago)   40s
oc logs web-649b7d686c-nfpvl --previous
# nginx: [warn] the "user" directive makes sense only if the master process runs with super-user privileges, ignored ...
# nginx: [emerg] mkdir() "/var/cache/nginx/client_temp" failed (13: Permission denied)
oc get pod web-649b7d686c-nfpvl -o jsonpath='{.metadata.annotations.openshift\.io/scc}'
# restricted-v2
```

The pod is admitted by the SCC `restricted-v2`: it runs with a random UID of the project range, and the root group. The official `nginx` image expects to start as root, and its directories belong to root.

Reproduce the problem in a debug pod, a copy of the pod with a shell. As cluster-admin, `oc debug` runs as root by default, and the problem disappears: force the UID of the project.

```bash
UID_START=$(oc get project troubleshoot-$ID -o jsonpath='{.metadata.annotations.openshift\.io/sa\.scc\.uid-range}' | cut -d/ -f1)
oc debug deployment/web --as-user=$UID_START -- id
# uid=1000760000(1000760000) gid=0(root) groups=0(root)
oc debug deployment/web --as-user=$UID_START -- mkdir /var/cache/nginx/client_temp
# mkdir: can't create directory '/var/cache/nginx/client_temp': Permission denied
```

Use an image built for an arbitrary UID: its writable directories belong to the group 0.

```bash
oc set image deployment web nginx=nginxinc/nginx-unprivileged:1.27-alpine
oc rollout status deployment web
oc exec client -- curl -sS http://web
# Hello from web-5ccc95955-ljr2f
```

Granting the SCC `anyuid` to the service account would also work, but the container would run as root: prefer fixing the image.
{{% /expand%}}

## Going further

- [Debug a running pod with an ephemeral container](https://kubernetes.io/docs/tasks/debug/debug-application/debug-running-pod/#ephemeral-container): `kubectl debug -it <pod> --image=busybox --target=<container>`, for images without a shell
- Debug a node: `kubectl debug node/<node> -it --image=busybox`, or `oc debug node/<node>` then `chroot /host` on OpenShift
- On OpenShift, collect the cluster state for the support: `oc adm must-gather`

## Clean up

```bash
kubectl delete namespace $NS
oc delete project troubleshoot-$ID
```
