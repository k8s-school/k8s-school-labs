---
title: 'Secrets Encryption at Rest'
date: 2024-06-06T18:00:00+10:00
draft: false
weight: 60
tags: ["CKS", "Secrets", "etcd", "Encryption", "Security"]
---

## Objectives
Learn how to configure encryption at rest for Kubernetes secrets stored in etcd. By default, secrets are stored in plain text in etcd, which poses a security risk if the etcd database is compromised.

## Prerequisites

### Understanding the Problem
First, let's understand why encryption at rest is important:

```bash
# Create a test secret
kubectl create secret generic test-secret --from-literal=password=mysecretpassword

# Access etcd directly to see how secrets are stored
# (This requires access to the control plane node)
```

### Q1: Why is encryption at rest important?

{{%expand "Answer" %}}
- **Default behavior**: Kubernetes stores secrets in etcd as base64-encoded text (not encrypted)
- **Security risk**: If someone gains access to etcd backups or the etcd database, they can easily decode all secrets
- **Compliance**: Many security frameworks (SOC2, PCI-DSS) require encryption at rest
- **Defense in depth**: Even if other security controls fail, encrypted data remains protected
{{% /expand%}}

## Generate Encryption Key

Generate a strong 32-byte encryption key:

```bash
# Generate a random 32-byte key and encode it in base64
head -c 32 /dev/urandom | base64
```

Save this key securely - you'll need it for the encryption configuration.

## Configure Encryption

### Step 1: Create Encryption Configuration

Create the encryption configuration file `/etc/kubernetes/enc.yaml`:

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
              secret: <YOUR_BASE64_KEY_HERE>
      - identity: {}
```

{{%expand "Complete Example" %}}

```bash
# Generate the key
ENCRYPTION_KEY=$(head -c 32 /dev/urandom | base64)
echo "Generated key: $ENCRYPTION_KEY"

# Create the encryption configuration
cat > /etc/kubernetes/enc.yaml <<EOF
apiVersion: apiserver.config.k8s.io/v1
kind: EncryptionConfiguration
resources:
  - resources:
      - secrets
    providers:
      - aescbc:
          keys:
            - name: key1
              secret: $ENCRYPTION_KEY
      - identity: {}
EOF
```

{{% /expand%}}

### Step 2: Update API Server Configuration

Modify the API Server static pod manifest at `/etc/kubernetes/manifests/kube-apiserver.yaml`:

**Add to command flags:**
```yaml
- --encryption-provider-config=/etc/kubernetes/enc.yaml
```

**Add to volumeMounts:**
```yaml
- mountPath: /etc/kubernetes/enc.yaml
  name: encryption-config
  readOnly: true
```

**Add to volumes:**
```yaml
- hostPath:
    path: /etc/kubernetes/enc.yaml
    type: File
  name: encryption-config
```

## Activation and Testing

### Step 3: Restart API Server

After modifying the manifest, the kubelet will automatically restart the API Server. Monitor the restart:

```bash
# Watch for the API server to restart
kubectl get pods -n kube-system -w -l component=kube-apiserver

# Verify the API server is running with encryption
kubectl get nodes
```

### Step 4: Encrypt Existing Secrets

When encryption is first enabled, existing secrets remain unencrypted. You must actively encrypt them:

```bash
# Encrypt all existing secrets in all namespaces
kubectl get secrets --all-namespaces -o json | kubectl replace -f -

# Or encrypt secrets in a specific namespace
kubectl get secrets -n default -o json | kubectl replace -f -
```

## Verification

### Test New Secrets

Create a new secret and verify it's encrypted:

```bash
# Create a new secret (this should be encrypted)
kubectl create secret generic encrypted-secret --from-literal=token=verysecrettoken

# Verify the secret works normally
kubectl get secret encrypted-secret -o yaml
echo $(kubectl get secret encrypted-secret -o jsonpath='{.data.token}') | base64 -d
```

### Verify Encryption in etcd

{{%expand "etcd Verification Commands" %}}

```bash
# Access the control plane node
# For Kind clusters:
docker exec -it <cluster-name>-control-plane bash

# Check etcd directly (this should show encrypted data)
ETCDCTL_API=3 etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/healthcheck-client.crt \
  --key=/etc/kubernetes/pki/etcd/healthcheck-client.key \
  get /registry/secrets/default/encrypted-secret

# The output should show encrypted content, not plain text
```

{{% /expand%}}

## Key Rotation

For production environments, regular key rotation is essential:

### Step 1: Add New Key

Update `/etc/kubernetes/enc.yaml` to add a new key as the first provider:

```yaml
apiVersion: apiserver.config.k8s.io/v1
kind: EncryptionConfiguration
resources:
  - resources:
      - secrets
    providers:
      - aescbc:
          keys:
            - name: key2  # New key
              secret: <NEW_BASE64_KEY>
            - name: key1  # Old key (for decryption)
              secret: <OLD_BASE64_KEY>
      - identity: {}
```

### Step 2: Re-encrypt Secrets

```bash
# Re-encrypt all secrets with the new key
kubectl get secrets --all-namespaces -o json | kubectl replace -f -
```

### Step 3: Remove Old Key

After all secrets are re-encrypted, remove the old key from the configuration.

## Troubleshooting

### API Server Won't Start

If the API server fails to start after enabling encryption:

```bash
# Check kubelet logs
journalctl -u kubelet | tail -20

# Common issues:
# 1. Invalid YAML syntax in enc.yaml
# 2. Incorrect file permissions
# 3. Invalid base64 key format

# Fix file permissions
chmod 600 /etc/kubernetes/enc.yaml
chown root:root /etc/kubernetes/enc.yaml
```

### Secrets Not Encrypted

If new secrets aren't being encrypted:

```bash
# Verify encryption configuration is loaded
kubectl get pods -n kube-system -l component=kube-apiserver -o yaml | grep encryption-provider-config

# Check API server logs
kubectl logs -n kube-system <kube-apiserver-pod-name>
```

## Security Best Practices

1. **Key Management**: Store encryption keys securely, separate from etcd backups
2. **Regular Rotation**: Rotate encryption keys periodically
3. **Backup Strategy**: Ensure backups include both data and keys (stored separately)
4. **Access Control**: Limit access to encryption configuration files
5. **Monitoring**: Monitor for unauthorized access to encryption configurations

## External Key Management

For enhanced security, consider external key management systems:

- **AWS KMS**: Use AWS Key Management Service
- **Azure Key Vault**: Integrate with Azure's key management
- **Google Cloud KMS**: Use Google Cloud's key management
- **HashiCorp Vault**: Enterprise key management solution

These require additional configuration but provide better key security and compliance.

---

## Summary

You've successfully:
- ✅ Configured encryption at rest for Kubernetes secrets
- ✅ Generated strong encryption keys
- ✅ Updated API server configuration
- ✅ Verified encryption is working
- ✅ Learned about key rotation procedures

This is a critical security control for production Kubernetes clusters, especially for compliance requirements.

## Next Steps

- Implement regular key rotation procedures
- Consider external key management systems for enhanced security
- Extend encryption to other sensitive resources (ConfigMaps, etc.)
- Integrate with your backup and disaster recovery processes