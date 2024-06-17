```markdown
---
title: 'Setting Up the Training Platform'
date: 2024-05-22T14:15:26+10:00
draft: false
weight: 40
tags: ["kubernetes", "ktbx", "prerequisites"]
---

During the training, it is recommended to use the provided platform. This section describes how to reproduce it after the training to replay the labs.

## Prerequisites

### Local Machine Configuration

- Fedora is recommended
- 8 cores, 16 GB of RAM, 30 GB for the partition hosting Docker entities (images, volumes, containers, etc). Use the `df` command as shown below to find its size.
```bash
sudo df -sh /var/lib/docker # or /var/snap/docker/common/var-lib-docker/
```
- Internet access **without proxy**
- `sudo` access
- Install the dependencies below:
```shell
sudo dnf install curl docker git vim bash-completion

# then add the current user to the docker group
sudo usermod -a -G docker $USER
# or restart the gnome session
newgrp docker
```

Then, you can create the Kubernetes cluster in two lines by following the [ktbx] documentation.

### Creating an OpenShift Cluster with OpenShift Local

For creating an OpenShift cluster using [openshift-local], follow these steps:

1. Clone the `k8s-server` repository:
```shell
git clone https://github.com/k8s-school/k8s-server.git
cd k8s-server/bootstrap/fedora
```

2. Run the setup script to install OpenShift Local:
```shell
./crc-setup.sh
```

3. Start the OpenShift cluster:
```shell
./crc-start.sh
```

These scripts will handle the installation and startup of your OpenShift cluster, providing a local environment for practicing with OpenShift.

<!--links-->
[ktbx]: https://github.com/k8s-school/ktbx
[openshift-local]: https://developers.redhat.com/products/openshift-local/overview
```
