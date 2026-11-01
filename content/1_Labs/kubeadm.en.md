---
title: 'Kubernetes easy install with Kubeadm'
date: 2020-01-27T14:15:26+10:00
draft: false
weight: 50
tags: ["kubernetes", "kubeadm", "kubectl", "installation", "cilium", "containerd", "ubuntu", "CKA", "CKS"]
---

**Author:** Fabrice JAMMES ([LinkedIn](https://www.linkedin.com/in/fabrice-jammes-5b29b042/)).

This lab installs a two-node Kubernetes cluster with [kubeadm](https://kubernetes.io/docs/reference/setup-tools/kubeadm/), the **official Kubernetes installer**. It follows the [official documentation](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/), simplified for Ubuntu.

It installs Kubernetes 1.36: the [next lab]({{% ref "/1_Labs/kubeadm-upgrade" %}}) upgrades the cluster to 1.37.

## Pre-requisites: Infrastructure

- Two or more machines running Ubuntu LTS, with administrator access (`sudo`)
- 2 GB or more of RAM per machine, 2 or more CPUs on the master
- Full network connectivity between all machines in the cluster

{{% notice info %}}
**Attending the training?** Two Ubuntu 24.04 machines are already provisioned for you: `<account>-1` is the master, `<account>-2` the worker, where `<account>` is your training account, e.g. `student3-1` and `student3-2`. Reach them from the training server with `ssh`: the ssh configuration and the key are already in your account.
{{% /notice %}}

On the training server, name your two nodes:

```bash
MASTER=$USER-1
WORKER=$USER-2
```

Then open one terminal on each node, with `ssh $MASTER` and `ssh $WORKER`: the commands below run on the nodes.

## Pre-requisites: System

### Install containerd

`containerd` is a lightweight runtime for Linux containers, a graduated project of the [CNCF](https://landscape.cncf.io/?selected=containerd). Kubernetes runs the containers with it, so it is required on every node.

On **both nodes**:

<!-- ci-host: all -->
```bash
# Kernel modules for the container network
cat <<EOF | sudo tee /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOF
sudo modprobe overlay
sudo modprobe br_netfilter

# Sysctl parameters, persistent across reboots
cat <<EOF | sudo tee /etc/sysctl.d/99-kubernetes-cri.conf
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF
sudo sysctl --system

# containerd, from the Docker apt repository
sudo apt-get update
sudo apt-get install -y ca-certificates curl gpg
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --batch --yes --dearmor -o /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list
sudo apt-get update
sudo apt-get install -y containerd.io

# Default configuration, with the systemd cgroup driver
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml >/dev/null
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
sudo systemctl restart containerd
```

The kubelet and containerd must use the same cgroup driver: `systemd` on a systemd distribution. See the [official documentation](https://kubernetes.io/docs/setup/production-environment/container-runtimes/#containerd).

### Install kubeadm, kubelet and kubectl

- `kubeadm` is the installer: it runs as `root` on each node of the cluster.
- `kubelet` is the agent which runs the containers of the pods on each node, including the master, where it runs the control plane as [static pods]({{% ref "/1_Labs/staticpod" %}}). It talks to `containerd` through the CRI (Container Runtime Interface).
- `kubectl` is the client.

On **both nodes**:

<!-- ci-host: all -->
```bash
# The apt repository of one minor version of Kubernetes
K8S_VERSION="v1.36"
curl -fsSL https://pkgs.k8s.io/core:/stable:/$K8S_VERSION/deb/Release.key | sudo gpg --batch --yes --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/$K8S_VERSION/deb/ /" \
  | sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

# crictl, the CRI client, talks to containerd
cat <<EOF | sudo tee /etc/crictl.yaml
runtime-endpoint: unix:///run/containerd/containerd.sock
image-endpoint: unix:///run/containerd/containerd.sock
EOF
```

`apt-mark hold` prevents an `apt-get upgrade`, for security updates, from upgrading `kubeadm`, `kubelet` and `kubectl`: upgrading a cluster follows a procedure of its own, see the [next lab]({{% ref "/1_Labs/kubeadm-upgrade" %}}).

## Create the Kubernetes cluster

On the **master**:

<!-- ci-host: master -->
```bash
sudo kubeadm init
```

The last lines of its output:

```
Your Kubernetes control-plane has initialized successfully!

To start using your cluster, you need to run the following as a regular user:

  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config

You should now deploy a pod network to the cluster.
Run "kubectl apply -f [podnetwork].yaml" with one of the options listed at:
  /docs/concepts/cluster-administration/addons/

Then you can join any number of worker nodes by running the following on each as root:

kubeadm join <control-plane-host>:<control-plane-port> --token <token> \
	--discovery-token-ca-cert-hash sha256:<hash>
```

It gives **three very important instructions**.

### 1. Configure kubectl

The master is also our client. On the **master**, with your regular account, not `root`:

<!-- ci-host: master -->
```bash
mkdir -p $HOME/.kube
sudo cp -f /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
kubectl get nodes
# NAME         STATUS     ROLES           AGE   VERSION
# student3-1   NotReady   control-plane   1m    v1.36.x
```

### 2. Install a network plugin

The node stays `NotReady` until a network plugin (CNI) runs. Install [Cilium](https://cilium.io/) on the **master**:

<!-- ci-host: master -->
```bash
# Latest versions:
# curl -s https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt
# curl -s https://raw.githubusercontent.com/cilium/cilium/main/stable.txt
CILIUM_CLI_VERSION="v0.20.2"
CILIUM_VERSION="1.20.4"

# Cilium CLI
CLI_ARCH=amd64
cd /tmp
curl -L --fail --remote-name-all https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}
sha256sum --check cilium-linux-${CLI_ARCH}.tar.gz.sha256sum
sudo tar xzvfC cilium-linux-${CLI_ARCH}.tar.gz /usr/local/bin
rm cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}
cd -

# Cilium
cilium install --version ${CILIUM_VERSION}
kubectl rollout status -n kube-system --timeout=600s daemonset/cilium
kubectl wait --for=condition=Ready node --all --timeout=300s
```

### 3. Join the worker

`kubeadm init` printed the command which joins a node to the cluster. Run it on the **worker**, with `sudo`:

<!-- ci-skip -->
```bash
sudo kubeadm join <control-plane-host>:<control-plane-port> --token <token> --discovery-token-ca-cert-hash sha256:<hash>
```

<!-- ci-exec
JOIN_CMD=$(echo 'sudo kubeadm token create --print-join-command' | mdlab_remote master)
echo "sudo $JOIN_CMD" | mdlab_remote worker
-->

- `<control-plane-host>:<control-plane-port>` is the address of the API server, on the master.
- `<token>` authenticates the node to the master. It expires after 24 hours: print a new join command on the master with `sudo kubeadm token create --print-join-command`.
- `<hash>` is the hash of the CA certificate of the cluster: the node checks that it talks to the right master.

{{% notice note %}}
kubeadm taints the master with `node-role.kubernetes.io/control-plane:NoSchedule`: the pods of the applications run on the workers, not next to the control plane.
{{% /notice %}}

## Check that everything works

On the **master**:

<!-- ci-host: master -->
```bash
kubectl wait --for=condition=Ready node --all --timeout=300s
kubectl get nodes -o wide
kubectl cluster-info
kubectl get pods -n kube-system -o wide
```

Installing Kubernetes with `kubeadm` is rather simple, isn't it :-)

## Questions

1. Why are the nodes `NotReady` before the installation of Cilium?
2. Which containers make up the control plane, and where are their manifests on the master?
3. Why does the master run a `kubelet`, when no application runs there?

{{%expand "Answers" %}}
1. The kubelet reports the node `Ready` only when the network of the pods works, so when a CNI plugin is installed.
2. `kube-apiserver`, `kube-controller-manager`, `kube-scheduler` and `etcd`: static pods, whose manifests are in `/etc/kubernetes/manifests`. The kubelet of the master reads this directory and runs them.
3. To run the control plane itself, as static pods, and the DaemonSets (Cilium, kube-proxy).
{{% /expand%}}

## Remove the cluster

The [official documentation](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/#tear-down) describes how to delete the cluster: `sudo kubeadm reset` on each node. On cloud machines, destroying and recreating them is simpler.
