---
title: 'Kubernetes easy install with Kubeadm'
date: 2020-01-27T14:15:26+10:00
draft: false
tags: ["kubernetes", "kubeadm", "kubectl", "installation", "weave", "containerd", "ubuntu"] 
---

**Auteur:** Fabrice JAMMES ([LinkedIn](https://www.linkedin.com/in/fabrice-jammes-5b29b042/)). 
**Date:** Jan 27, 2020 · 10 min read


This article explains how to install Kubernetes with [kubeadm](https://kubernetes.io/docs/reference/setup-tools/kubeadm/kubeadm/), the **official Kubernetes installer**. It is inspired by the [official documentation](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/), while declining it for Ubuntu and simplifying it.

## Pre-requisites: Infrastructure 

- One or more machines running Ubuntu LTS, with administrator access ( sudo)
- 2 GB or more of RAM per machine
- 2 or more processors on the master node
- Full network connectivity between all machines in the cluster

## Pre-requisites: System

### Install containerd

`containerd` is a lightweight `runtime` for Linux containers. It is a reliable project, validated by the `Cloud-Native Computing Foundation`, as you can see on the [CNCF landscape web page](https://landscape.cncf.io/selected=containerd). The installation of containerd is required on all of your machines. Indeed, this is the basic brick that will allow Kubernetes to run and manage the containers. Copy and paste the code below in a script and to execute it on each machine.

```bash
#!/bin/bash

set -euxo pipefail

# Ensure iptables tooling does not use the nftables backend
sudo update-alternatives --set iptables /usr/sbin/iptables-legacy
sudo update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy
sudo update-alternatives --set arptables /usr/sbin/arptables-legacy
sudo update-alternatives --set ebtables /usr/sbin/ebtables-legacy

# Install containerd pre-requisites
cat > /etc/modules-load.d/containerd.conf <<EOF
overlay
br_netfilter
EOF

modprobe overlay
modprobe br_netfilter

# Setup required sysctl params, these persist across reboots.
cat > /etc/sysctl.d/99-kubernetes-cri.conf <<EOF
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF

sysctl --system

# Install containerd
## Set up the repository
### Install packages to allow apt to use a repository over HTTPS
apt-get update && apt-get install -y apt-transport-https ca-certificates curl software-properties-common

### Add Docker’s official GPG key
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -

### Add Docker apt repository.
add-apt-repository \
    "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
    $(lsb_release -cs) \
    stable"

## Install containerd
apt-get update && apt-get install -y containerd.io

# Configure containerd
mkdir -p /etc/containerd
containerd config default > /etc/containerd/config.toml

# Restart containerd
systemctl restart containerd
```

For more information regarding the installation of containerd, please check the [official documentation](https://kubernetes.io/docs/setup/production-environment/container-runtimes/#containerd).

### Install kubeadm and its friends: kubelet and kubectl

* `kubeadm` is the official Kubernetes installer, it must be run as `root` on every the nodes of your Kubernetes cluster.
* `kubelet` is the daemon in charge of running and managing the containers on every nodes controlled by Kubernetes. It must be available on all the nodes of the cluster, including the master nodes because it also manages the containers in charge of the Kubernetes system components. It uses the [CRI specification](https://developer.ibm.com/blogs/kube-cri-overview/) (Container Runtime Interface) to communicate with the local container execution engine, in our example `containerd`.
* `kubectl` is the Kubernetes client, install it on the machine that will allow you to control your Kubernetes cluster.
As seen aboce, we recommend that you copy and paste the code below into a script and execute it on each machine.

```bash
#!/bin/bash

set -euxo pipefail

sudo apt-get update && sudo apt-get install -y apt-transport-https curl
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
cat <<EOF | sudo tee /etc/apt/sources.list.d/kubernetes.list
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF
sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl
```

Please note that the script prevents updates to `kubeadm`, `kubectl`, and `kubelet` which could be caused by the installation of security updates with `apt-get` commands.

## Create the Kubernetes cluster

On your master node, run the following command:
```bash
sudo kubeadm init
```

Here is what will appear on your console, in the last lines of standard output:

```
Your Kubernetes control-plane has initialized successfully!

To start using your cluster, you need to run the following as a regular user:

  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config

You should now deploy a pod network to the cluster.
Run "kubectl apply -f [podnetwork].yaml" with one of the options listed at:
  /docs/concepts/cluster-administration/addons/

You can now join any number of machines by running the following on each node
as root:

  kubeadm join <control-plane-host>:<control-plane-port> --token <token> --discovery-token-ca-cert-hash sha256:<hash>
```

There are **three very important instructions** here:

- how to configure `kubectl`, the Kubernetes client. In our example we will use the Kubernetes master node as a client, on which we will therefore issue the commands below:
```bash
# Connect with your regular user account, and not with `root` account
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```
- installing a network plugin, here we choose the simplest one to install: `weave`. Just run the command below on your Kubernetes client, which we just configured. Note that in our example it is also the master Kubernetes:
```shell
kubectl apply -f "https://cloud.weave.works/k8s/net?k8s-version=$(kubectl version | base64 | tr -d '\n')"
```
- the command to execute on all your other nodes so that they join the Kubernetes cluster:
```shell
sudo kubeadm join <control-plane-host>:<control-plane-port> --token <token> --discovery-token-ca-cert-hash sha256:<hash>
```

`<control-plane-host>:<control-plane-port>` contains the DNS name or IP and port of the Kubernetes master. `<token>` is the token, whose lifetime is limited, which allows the current node to identify itself to the master. Finally, `<hash>` allows the current node to ensure the authenticity of the master.

## Check that everything works

The following command verifies that your Kubernetes cluster is operational:

```shell
kubectl cluster-info                                                                                                                                                        ✔  10376  09:19:37
Kubernetes master is running at https://127.0.0.1:32903
KubeDNS is running at https://127.0.0.1:32903/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy

To further debug and diagnose cluster problems, use 'kubectl cluster-info dump'.
```

The command below makes it possible to list all of your nodes:
```shell
kubectl get nodes
```

Finally, installing Kubernetes with `kubeadm` is rather simple, isn't it :-).

## Remove the cluster
The [official documentation](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/#tear-down) explains all the operations required to delete your cluster. If you have created your machines in a Cloud, an equivalent and much simpler solution is of course to delete all them, and then recreate them in their initial state.

## Automate installation

Here is a sample script to automate this process: https://github.com/k8s-school/k8s-advanced/tree/master/0_kubeadm . To learn more, you can contact us to register to one of our [training courses](https://k8s-school.fr/formations-kubernetes).
