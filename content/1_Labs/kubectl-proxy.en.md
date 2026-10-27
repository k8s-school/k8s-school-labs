---
title: 'Kubectl proxy and curl'
date: 2025-02-26T14:15:26+10:00
draft: false
weight: 205
tags: ["kubernetes", "kubectl", "api server", "curl"]
---

**Author:** Fabrice JAMMES ([LinkedIn](https://www.linkedin.com/in/fabrice-jammes-5b29b042/)).

## Objective
Understand how a pod authenticates to the API server with the token of its service account, then learn how to use `kubectl proxy` and `curl` to list services in a specified Kubernetes namespace.

## Prerequisites
- A running Kubernetes cluster
- `kubectl` installed and configured
- `curl` installed

## Part 1: The token of a service account

The cluster is shared by the trainees: work in a namespace of your own.

```bash
NS=proxy-$(whoami)
kubectl create namespace $NS
kubectl config set-context --current --namespace=$NS
```

### Step 1: Create a service account and a pod

Create a service account named `api-reader`, then a pod named `client` which runs with this service account (image `curlimages/curl:8.11.1`, command `sleep infinity`).

{{%expand "Solution" %}}
```bash
kubectl create serviceaccount api-reader

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: client
spec:
  serviceAccountName: api-reader
  containers:
  - name: client
    image: curlimages/curl:8.11.1
    command: ["sleep", "infinity"]
EOF
kubectl wait --for=condition=Ready pod/client
```
{{% /expand%}}

### Step 2: Get the token from inside the pod

Where is the token mounted in the container? Display it.

{{%expand "Solution" %}}
```bash
kubectl get pod client -o jsonpath='{.spec.volumes[0]}{"\n"}'
kubectl exec client -- ls /var/run/secrets/kubernetes.io/serviceaccount
# ca.crt  namespace  token
kubectl exec client -- cat /var/run/secrets/kubernetes.io/serviceaccount/token; echo
```

The kubelet mounts a `projected` volume with three files: the token, the CA certificate of the API server, and the namespace of the pod.
{{% /expand%}}

### Step 3: Analyze the token on jwt.io

Copy the token and paste it in the debugger of [jwt.io](https://jwt.io/).

{{% notice warning %}}
A token is a credential: only paste the token of a lab cluster in a website, never a production one.
{{% /notice %}}

To decode the payload locally instead (a JWT is `header.payload.signature`, each part in base64url):

```bash
kubectl exec client -- cat /var/run/secrets/kubernetes.io/serviceaccount/token |
  jq -R 'split(".")[1] | gsub("-";"+") | gsub("_";"/") | @base64d | fromjson'
```

- Which identity does the API server see for this pod?
- Who issued the token, and for which audience?
- How long is the token valid?
- What happens to the token if the pod is deleted?

{{%expand "Answers" %}}
- `sub`: `system:serviceaccount:<namespace>:api-reader`, this is the user name the RBAC rules apply to. The pod also belongs to the groups `system:serviceaccounts` and `system:serviceaccounts:<namespace>`.
- `iss` is the issuer (the API server), `aud` the audience: the token is only accepted by the API server.
- The pod requests a one-hour token (`expirationSeconds: 3607` in the projected volume), and the kubelet renews the file before it expires. But `exp - iat` is one year: the API server extends the tokens mounted in pods (`--service-account-extend-token-expiration`, default `true`), so that old clients which never re-read the file keep working. `kubernetes.io.warnafter` is the real one-hour limit: after it, the API server still accepts the token but flags it as stale (audit annotation and metric).
- The `kubernetes.io` claim binds the token to the pod and to its node (name and `uid`), and to the service account: the token becomes invalid when the pod is deleted.
- The token is signed by the API server (`alg: RS256`), it is not encrypted: anybody can read it, nobody can modify it.
{{% /expand%}}

### Step 4: Call the API server with the token

From inside the pod, use the token to list the pods of your namespace. What is the answer? Why?

{{%expand "Solution" %}}
```bash
kubectl exec client -- sh -c '
SA=/var/run/secrets/kubernetes.io/serviceaccount
curl -s --cacert $SA/ca.crt -H "Authorization: Bearer $(cat $SA/token)" \
  https://kubernetes.default.svc/api/v1/namespaces/$(cat $SA/namespace)/pods'
```

The API server answers `403 Forbidden`: the token **authenticates** the pod as `system:serviceaccount:<namespace>:api-reader`, but no RBAC rule **authorizes** this identity to list pods. The next lab grants these permissions.
{{% /expand%}}

Delete the namespace:

```bash
kubectl delete namespace $NS
kubectl config set-context --current --namespace=default
```

## Part 2: kubectl proxy

### Step 1: Start `kubectl proxy`
Run the following command to start the `kubectl proxy`:

```sh
kubectl proxy &
```
{{% notice note %}}
In case of port conflict use the `--port`option
{{% /notice %}}

This command runs `kubectl proxy` in the background, allowing API requests to be sent to the Kubernetes API server via `localhost`.

### Step 2: List Services in a Namespace using `curl`
To list the services in a given namespace, use the following `curl` command:

{{%expand "Answer" %}}
```sh
curl http://localhost:8001/api/v1/namespaces/<namespace>/services
```

Replace `<namespace>` with the actual namespace you want to query. If you want to list services in the `default` namespace, use:

```sh
curl http://localhost:8001/api/v1/namespaces/default/services
```
{{% /expand%}}

## Expected Output
You should see a JSON output listing the services running in the specified namespace, including their metadata, specifications, and statuses.

## Cleanup
If you want to stop the `kubectl proxy`, find the process ID and terminate it:

```sh
ps aux | grep kubectl
kill <PID>
```

Alternatively, you can use:

```sh
pkill -f kubectl
```

## Conclusion
You have successfully queried Kubernetes services using `kubectl proxy` and `curl`. This method allows direct interaction with the Kubernetes API for retrieving resource information.

