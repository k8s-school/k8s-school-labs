---
title: 'Easily run a multinode Kubernetes cluster on your CI'
date: 2019-10-14T15:15:26+10:00
image: '/services/default.png'
featured: true
draft: false
tags: ["kubernetes", "continuous integration", "kind"]
---

**Written by:** Fabrice JAMMES ([LinkedIn](https://www.linkedin.com/in/fabrice-jammes-5b29b042/)). 
**Date:** Oct 14, 2019 · 10 min read

This tutorial shows how to **automate the tests of a Cloud-Native application**. It will make your life much more easier by allowing you to automatically run and test your Kubernetes applications inside a CI server. 

## Pre-requisites

Example below is based on `Github` and `Travis-CI`, but you can easily use any SCM and CI server that are able to spawn a virtual machine for each commit.

* Your Kubernetes application will be stored inside a [Github](https://github.com) project, which may be used freely. You need to create a `Github` account.
* The continuous integration server will rely on [Travis-CI](https://travis-ci.org), which may be used freely. You need to create a `Travis-CI` account.
* Connect the `Github` project to `Travis-CI`, by going to url ```https://travis-ci.org/<GITHUB_USER>/<PROJECT_NAME>``` and activate the project inside `Travis-CI` web interface. `Travis-CI` will then launch a new virtual machine for each new `Github` commit.

## Kind: what is that thing?

[kind](https://kind.sigs.k8s.io/) is a tool for running local Kubernetes clusters using Docker container “nodes”. It is very helpful for developers who want to test their cloud-native applications on their workstation and for system administrators aiming at providing Kubernetes clusters for CI or development.
 
![Kind architecture](kind.svg?class=shadow)

## Install Kind inside Travis-CI

`Travis-CI` now launches a new virtual machine for each new `Github` commit in your project.
Our goal is to run kind inside this `Travis-CI` virtual machine, so that we can test that our project runs correctly inside a Kubernetes cluster.

![Goal](ci.svg?class=shadow)

- Luckily, `K8s-school` provides an example project in order to do this. It is available [here](https://github.com/k8s-school/ci-example.git).

So, let's clone our `Github` project. In the following lines, we will use `ci-example` as our example project, but you should use your own `Github` project.

```shell
git clone https://github.com/k8s-school/ci-example.git
cd ci-example
ls -l .travis.yml
-rw-rw-r-- 1 user group 571 Oct 14 11:56 .travis.yml
```

The hidden file `.travis.yml` explains to `Travis-CI` what to do during the build.

```yaml
sudo: required
dist: xenial

before_script:
  - git clone --depth 1 -b "v0.5.1" --single-branch https://github.com/k8s-school/kind-travis-ci.git
  - ./kind-travis-ci/kind/k8s-create.sh
  - export KUBECONFIG="$(kind get kubeconfig-path --name="kind")"

script:
  - ./build.sh
  - ./deploy.sh
  - ./wait-app-ready.sh 
  - kubectl get all,endpoints,cm,pvc,pv -o wide
  - ./run-integration-tests.sh

```

The `before_script` section will clone [kind-travis-ci](https://github.com/k8s-school/kind-travis-ci.git) inside the `Travis-CI` virtual machine, and then launch the embedded script `k8s-create.sh`. This script creates a 3 nodes `Kubernetes` cluster using `Kind` and install the `kubectl` client. The `KUBECONFIG` variable will then allow `kubectl` and other `Kubernetes` clients to talk to the `Kind` cluster. 

All you have to do now is enabling the `script` section to build containers for your application, deploy them to kind using `kubectl` or any other `Kubernetes` clients, wait for your application to be up and running and then launch the integration tests.

Pretty easy and lightweight, isn't it?

<!---
## Install the application 

- redis operator or mongodb?
- launch the test
- push the new version of the container to the container registry

-->