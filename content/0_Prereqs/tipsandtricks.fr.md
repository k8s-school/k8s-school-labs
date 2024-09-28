---
title: 'Trucs et astuces'
date: 2024-05-22T14:15:26+10:00
draft: false
weight: 30
tags: ["kubernetes", "formation", "labs", "pre-requis", "linux"]
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
