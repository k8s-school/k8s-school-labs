---
title: 'Secrets Encryption at Rest'
date: 2024-06-06T18:00:00+10:00
draft: false
weight: 60
tags: ["CKS", "Secrets", "etcd"]
---

## Objectifs
Vérifier que les secrets sont stockés en clair dans etcd et activer le chiffrement AES-CBC.

## Prerequisites
```bash
# Générer une clé de 32 octets encodée en base64
head -c 32 /dev/urandom | base64

```

## Configurer le chiffrement

Créez `/etc/kubernetes/enc.yaml`.

{{%expand "Solution" %}}

```yaml
apiVersion: apiserver.config.k8s.io/v1
kind: EncryptionConfiguration
resources:
  - resources:
      - secrets
    providers:
      - aescbc:
          keys:
            - name: key1
              secret: <VOTRE_CLE_BASE64>
      - identity: {}

```

{{% /expand%}}

## Activation

Ajoutez le flag `--encryption-provider-config=/etc/kubernetes/enc.yaml` au manifeste de l'API Server.

