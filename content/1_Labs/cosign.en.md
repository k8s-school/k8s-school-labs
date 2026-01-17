---
title: "Cosign: Container Image Signing & Verification"
description: "Learn to sign and verify container images using Cosign for supply chain security"
weight: 26
tags: ["CKS", "Cosign", "Image Signing", "Supply Chain", "Sigstore"]
---

# Cosign: Container Image Signing & Verification Lab

## Overview

This lab demonstrates how to use Cosign to sign and verify container images, ensuring authenticity and integrity in your software supply chain using cryptographic signatures.

## Learning Objectives

By the end of this lab, you will be able to:
- Install and configure Cosign
- Generate cryptographic key pairs
- Sign container images with private keys
- Verify image signatures with public keys
- Understand keyless signing with OIDC
- Implement signature verification in deployment workflows

## Prerequisites

- Docker installed and running
- Internet connectivity for downloading tools
- Basic understanding of cryptographic signatures
- Knowledge of container registries

## Lab Exercises

### Exercise 1: Cosign Installation and Setup

#### Install Cosign

```bash
# Download and install Cosign
COSIGN_VERSION="v2.2.3"
curl -O -L "https://github.com/sigstore/cosign/releases/download/${COSIGN_VERSION}/cosign-linux-amd64"
sudo mv cosign-linux-amd64 /usr/local/bin/cosign
sudo chmod +x /usr/local/bin/cosign

# Verify installation
cosign version --short
```

#### Setup Local Container Registry

For this lab, we'll use a local registry to avoid external dependencies:

```bash
# Start local registry
docker run -d -p 5000:5000 --name registry registry:2

# Verify registry is running
docker ps | grep registry
```

### Exercise 2: Key Generation and Management

#### Generate Cosign Key Pair

```bash
# Generate private and public key pair
# Use 'test123' as password when prompted
echo "test123" | cosign generate-key-pair

# Verify keys are created
ls -la cosign.key cosign.pub

# View public key content
cat cosign.pub
```

**Key Files Created:**
- `cosign.key`: Private key (password-protected)
- `cosign.pub`: Public key for verification

### Exercise 3: Image Preparation and Signing

#### Prepare Container Image

```bash
# Pull base image
docker pull nginx:1.19

# Tag for local registry
docker tag nginx:1.19 localhost:5000/nginx:1.19-signed

# Push to local registry
docker push localhost:5000/nginx:1.19-signed
```

#### Sign Container Image

```bash
# Sign the image with private key
echo "test123" | cosign sign --key cosign.key localhost:5000/nginx:1.19-signed --yes

# Verify signature was created
cosign tree localhost:5000/nginx:1.19-signed
```

**What Happens During Signing:**
- Cosign creates a cryptographic signature of the image manifest
- The signature is stored as an OCI artifact in the same registry
- Signature metadata includes timestamp and signing identity

### Exercise 4: Signature Verification

#### Verify Image Signature

```bash
# Verify signature with public key
cosign verify --key cosign.pub localhost:5000/nginx:1.19-signed

# Get detailed signature information
cosign verify --key cosign.pub localhost:5000/nginx:1.19-signed --output json | jq '.[0].optional'
```

**Expected Output:**
- Verification success message
- Signature metadata including bundle information
- Certificate chain details

#### Demonstrate Verification Failure

```bash
# Generate a different key pair
mkdir /tmp/wrong-keys && cd /tmp/wrong-keys
echo "wrong123" | cosign generate-key-pair

# Try to verify with wrong public key (should fail)
cosign verify --key cosign.pub localhost:5000/nginx:1.19-signed
```

**Expected Result:** Verification fails because the signature doesn't match the public key.

## Key Takeaways

### Technical Insights

1. **Cryptographic Security**: Cosign provides strong cryptographic guarantees for image authenticity
2. **OCI Compliance**: Signatures are stored as OCI artifacts alongside images
3. **Attestation Support**: Supports rich metadata and compliance attestations
4. **Keyless Innovation**: Sigstore enables keyless signing using OIDC identity

### Operational Benefits

- **Supply Chain Security**: Prevent deployment of tampered or unauthorized images
- **Compliance**: Meet regulatory requirements for software provenance
- **Identity Verification**: Cryptographic proof of who signed what and when
- **Integration**: Seamless integration with existing CI/CD and Kubernetes workflows

## Next Steps

After completing this lab:
1. Implement Cosign in your CI/CD pipelines
2. Set up automated signature verification in deployment processes
3. Explore Sigstore Policy Controller for Kubernetes
4. Integrate with vulnerability scanning and SBOM generation workflows

## References

- [Cosign Documentation](https://docs.sigstore.dev/cosign/)
- [Sigstore Architecture](https://docs.sigstore.dev/)
- [SLSA Framework](https://slsa.dev/)
- [Supply Chain Security Best Practices](https://cloud.google.com/software-supply-chain-security)
