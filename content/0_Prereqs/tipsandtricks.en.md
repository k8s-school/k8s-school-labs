---
title: 'Tips and tricks'
date: 2024-05-22T14:15:26+10:00
draft: false
weight: 30
tags: ["kubernetes", "training", "labs", "pre-requisites", "linux"]
---

## Copy a file in Linux console

```shell
cat > my-file.sh
# paste the content and use Ctrl-D
```

## Enable ssh persistent session with Byobu

```shell
ssh k8s<ID>@<server-ip>
byobu
# F2: create new tab
# F3/F4: switch to left/right tab
```

If the session crashes, reconnect and launch byobu to recover it

## Create a SSH Tunnel

```shell
ssh k8s<ID>@<server-ip> -L 808<ID>:localhost:808<ID> -N
```

### With Putty

```shell
plink -ssh -L 8088:localhost:8088 -P 22 k8s<ID>@<server-ip>
```

## CKA tips

### Pre Setup
Once you've gained access to your terminal it might be wise to spend ~1 minute to setup your environment. You could set these:

```shell
alias k=kubectl   # will already be pre-configured

export do="--dry-run=client -o yaml"
# k get pod x $do

export now="--force --grace-period 0"
# k delete pod x $now
```

### Vim

To make vim use 2 spaces for a tab edit ~/.vimrc to contain:

```shell
set tabstop=2
set expandtab
set shiftwidth=2
```
