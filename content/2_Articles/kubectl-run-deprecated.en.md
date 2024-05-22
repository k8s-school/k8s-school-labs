---
title: "Alternatives for deprecated 'kubectl run' commands"
date: 2019-09-30
draft: false
weight: 1
tags: ["kubernetes", "kubectl", "run", "deprecated"] 
---
**Written by:** Karim AMMOUS ([LinkedIn](https://www.linkedin.com/in/karim-ammous)). 
**Date:** Sept 30, 2019 · 5 min read

`kubectl run` command is a convenient and useful way to quickly create kubernetes resources without dealing with yaml files. Since kubernetes v1.12, creation acknowledgment ("object created") is preceded by a message noting that this creation command is deprecated and will no longer be available in future `kubectl` releases.

Indeed, we can create some "runnable" resources like Pods and Deployments ([the complete list](https://kubernetes.io/docs/reference/kubectl/conventions/#generators)) using `kubectl run` command by setting the `--generator` flag with the appropriate value. However, those generators have been deprecated since v1.12 except 'run-pod/v1' generator.

The above deprecation covers `--restart` flags as well. Like `--generator` flag, they are also used to set generator.

| Generated Resource        | Flag |
| ------                    | ----------- |
| Pod                       | `--restart=Never` |
| Deployment (deprecated)   | `--restart=Always` |
| Job (deprecated)          | `--restart=OnFailure` |
| Cron Job (deprecated)     | `--schedule=\<cron\>`   |



Source: [kubernetes.io](https://kubernetes.io/docs/reference/kubectl/conventions/#generators)

This post aims to list available alternatives in latest available kubernetes version at the time of writing which is **v1.15.4** for both client and server.

## Pod

There is no deprecation for Pod creation. We have two options to create a Pod. You can either use `--restart` or `--generator` flags.

``` 
kubectl run nginx --restart=Never --image=nginx 
```

**AND**

```
kubectl run nginx --generator=run-pod/v1 --image=nginx
```

## Deployment

Deprecated command:

```
kubectl run nginx --restart=Always --image=nginx
```
Returned message:

```
kubectl run --generator=deployment/apps.v1 is DEPRECATED and will be removed in a future version. Use kubectl run --generator=run-pod/v1 or kubectl create instead.
deployment.apps/nginx created
```

It talks about two alternatives. Only the `kubectl create` command works as expected and generates a Deployment resource.

**"Create" command alternative**

```
kubectl create deployment nginx --image=nginx 
```
Please note that by moving to `kubectl create` command, we are losing the ability to fully customize generated Deployment. For example, it is no longer possible to define replicas (`--replicas` option), resources (`--requests` and `--limits` options) or implicitly create an associated Service with `--expose` option.

## Job
Deprecated command:

```
kubectl run my-job --image=busybox --restart=OnFailure
```

Alternative command:

```
kubectl create job my-job --image=busybox -- date
```

## Cronjob
Deprecated command:
```
kubectl run pi --schedule="0/5 * * * ?" --image=perl --restart=OnFailure -- perl -Mbignum=bpi -wle 'print bpi(2000)'
```
Alternative command:

```
kubectl create cronjob pi --image=perl --schedule="0/5 * * * ?"  -- perl -Mbignum=bpi -wle 'print bpi(2000)'
```
