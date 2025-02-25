---
title: 'Essential kubectl Commands'
date: 2024-06-11T14:15:26+10:00
draft: false
weight: 1
tags: ["kubernetes", "kubectl"]
---

**Duration:** 5 min read

## Official documentation for kubectl

[kubectl quick reference](https://kubernetes.io/docs/reference/kubectl/quick-reference/)

## List a Resource from the API Server
To retrieve details of a specific resource in Kubernetes, use the following command:

```sh
kubectl get <resource-name> <obj-name> [-o yaml/json]
```

## Describe a Resource from the API Server
To get a detailed description of a specific resource, use:

```sh
kubectl describe <resource-name> <obj-name>
```

## Create or Update Resources from a File
To create or update resources from a YAML file, use:

```sh
kubectl apply -f obj.yaml
```

## Delete Resources from a File
To delete resources defined in a YAML file, use:

```sh
kubectl delete -f obj.yaml
# or to destroy the resource by its name
kubectl delete <resource-name> <obj-name>
```

## Edit a Resource in the Kubernetes Database (i.e., etcd)
To edit a resource directly in the Kubernetes database, use:

```sh
kubectl edit <resource-name> <obj-name>
```
> [Learn more about best practices for microservices](https://12factor.net/codebase)

## Display Inline Documentation (and Provide Useful Examples)
To display help and usage examples for a specific command, use:

```sh
kubectl create job --help
# or
kubectl help create job
```

## Describe YAML Specification
To get a description of the YAML specification for a specific resource type, use:

```sh
kubectl explain pods.spec [--recursive]
```

## Display Logs for a Container (i.e., stdout/stderr)
To display logs from a specific container, use:

```sh
kubectl logs <pod-name> [ -c <container-name> ]
```
> [Learn more about log management](https://12factor.net/logs)

## Open an Interactive Shell Inside a Container
To open an interactive shell inside a container, use:

```sh
kubectl exec -it <pod-name> -- bash
```

## Provide Network Access to a Pod
To listen on port 8080 locally and forward data to/from port 80 in the pod, use:

```sh
# Listen on port 8080 locally, forwarding data to/from port 80 in the pod
kubectl port-forward pod/mypod 8080:80 &

# Access the pod with an HTTP client
curl http://localhost:8080
```

## Quickly Generate a YAML Specification

The `--dry-run=client -o yaml` options allow you to generate YAML without creating the resource in Kubernetes. They are very useful for quickly generating YAML files that can serve as a working base. Here is an example of its usage:

```sh
kubectl create service clusterip my-service --tcp=5678:8080 --dry-run=client -o yaml
```

## See List of Resources in Use

This command requires the installation of 'kubernetes-sigs/metrics-server'. To display metrics for nodes and pods, use:

```sh
kubectl top nodes
kubectl top pods
```

## Copy Files To and From a Container
To copy files to and from a container, use:

```sh
kubectl cp <pod-name:/path/to/remote/file> </path/to/local/file>
```
