---
title: 'Kubectl proxy and curl'
date: 2025-02-26T14:15:26+10:00
draft: false
weight: 20
tags: ["kubernetes", "kubectl", "api server", "curl"]
---

**Author:** Fabrice JAMMES ([LinkedIn](https://www.linkedin.com/in/fabrice-jammes-5b29b042/)).

## Objective
Learn how to use `kubectl proxy` and `curl` to list services in a specified Kubernetes namespace.

## Prerequisites
- A running Kubernetes cluster
- `kubectl` installed and configured
- `curl` installed

## Steps

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
```

