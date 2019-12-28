---
title: 'Installer Kubernetes simplement avec Kubeadm'
date: 2019-12-27T14:15:26+10:00
draft: false
tags: ["kubernetes", "kubeadm", "kubectl", "installation", "weave", "containerd", "ubuntu"] 
---

**Auteur:** Fabrice JAMMES ([LinkedIn](https://www.linkedin.com/in/fabrice-jammes-5b29b042/)). 
**Date:** Dec 27, 2019 · 10 min de lecture


Cet article explique comment installer Kubernetes avec [kubeadm](https://kubernetes.io/docs/reference/setup-tools/kubeadm/kubeadm/), **l'installeur officiel de Kubernetes**, en quelques lignes.
Il s'inspire de la [documentation officielle](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/), tout en la déclinant pour Ubuntu et en la simplifiant.

## Pré-requis côté infrastructure

- Une ou plusieurs machines sous Ubuntu LTS, avec accès administrateur (`sudo`)
- 2 Go ou plus de RAM par machine
- 2 processeurs ou plus sur le noeud maître
- Connectivité réseau complète entre toutes les machines du cluster

## Pré-requis côté système

### Installer containerd 

Pour information, `containerd` est un `runtime` léger pour conteneurs Linux, c'est un projet fiable et validé par la `Cloud-Native Computing Foundation`: https://landscape.cncf.io/selected=containerd.
L'installation de `containerd` est à réaliser sur l'ensemble de vos machines. L'idéal est de copier-coller le code ci-dessous dans un script et de l'exécuter sur chaque machine.

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

Pour plus d'informations concernant l'installation de `containerd`, tous les détails sont dans la [documentation officielle](https://kubernetes.io/docs/setup/production-environment/container-runtimes/#containerd).

### Installer kubeadm

Comme précédemment, nous vous recommandons de copier-coller le code ci-dessous dans un script et de l'exécuter sur chacune des machines.

```shell
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

## Créer le cluster Kubernetes


Sur votre noeud maître, lancer la commande suivante:
```shell
sudo kubeadm init
```

Voici ce que vous devriez voir apparaître sur votre console, dans les dernières lignes de la sortie standard de la commande:
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

**Trois instructions très importantes** sont présentes ici:

- la manière de configurer `kubectl`, le client Kubernetes. Dans notre exemple nous utiliserons comme machine cliente le noeud maître Kubernetes, sur lequel nous lancerons donc les commandes ci-dessous:
```shell
# Ici vous devez être connecté avec votre compte utilisateur et non pas en tant que `root`
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```
- l'installation d'un plugin réseau, nous choisirons ici le plus simple à installer: `weave`. Il suffit de lancer la commande ci-dessous sur votre client Kubernetes, que nous venons de configurer. A noter que dans notre exemple c'est également le maître Kubernetes:
```shell
kubectl apply -f "https://cloud.weave.works/k8s/net?k8s-version=$(kubectl version | base64 | tr -d '\n')"
```
- la commande à exécuter sur tous vos autres noeuds afin qu'ils rejoignent le cluster Kubernetes:
```shell
sudo kubeadm join <control-plane-host>:<control-plane-port> --token <token> --discovery-token-ca-cert-hash sha256:<hash>
```

## Vérifier que tout fonctionne

La commande suivante permet de vérifier que votre cluster Kubernetes est opérationnel:

```shell
kubectl cluster-info                                                                                                                                                        ✔  10376  09:19:37
Kubernetes master is running at https://127.0.0.1:32903
KubeDNS is running at https://127.0.0.1:32903/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy

To further debug and diagnose cluster problems, use 'kubectl cluster-info dump'.
```

La commande ci-dessous permet de lister l'ensemble de vos noeuds:
```shell
kubectl get nodes
```

Finalement, l'installation de Kubernetes avec `kubeadm` est plutôt simple, n'est-ce pas :-).

## Supprimer le cluster

La [documentation officielle](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/#tear-down) détaille toutes les opérations nécessaires pour supprimer votre cluster.
Si vous avez créé vos machines dans un Cloud, une solution équivalente et beaucoup plus simple est bien entendu de les supprimer, puis des les recréer dans leur état initial.

## Automatiser l'installation

Voici un exemple de script permettant d'automatiser ce processus: https://github.com/k8s-school/k8s-advanced/tree/master/0_kubeadm.