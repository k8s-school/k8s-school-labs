---
title: "Cosign: Container Image Signing & Verification"
description: "Learn to sign and verify container images using Cosign for supply chain security"
weight: 26
tags: ["CKS", "Cosign", "Image Signing", "Supply Chain", "Sigstore"]
---

**Author:** Fabrice JAMMES ([LinkedIn](https://www.linkedin.com/in/fabrice-jammes-5b29b042/)).

## Objective

- Sign a container image with [Cosign](https://docs.sigstore.dev/cosign/) and a key pair
- Verify the signature, and see why an image is signed by **digest**, not by tag

A signature proves who published an image and that it was not changed since: only the images signed by your CI should run in production.

The CKS curriculum lists "Secure your supply chain: permitted registries, sign and validate artifacts" in the *Supply chain security* domain.

## Prerequisites

`cosign` and `docker` are installed on the training server. The registry `localhost:5000` is shared by all the accounts of the server: each trainee pushes in a repository of their own.

```bash
cosign version | grep GitVersion
mkdir -p $HOME/cosign && cd $HOME/cosign
# Start the shared registry, if it does not run yet
if ! docker ps --format '{{.Names}}' | grep -qx registry; then
  docker start registry 2>/dev/null || docker run -d -p 5000:5000 --name registry registry:2
fi
for i in $(seq 30); do curl -sf localhost:5000/v2/ >/dev/null && break; sleep 1; done
IMAGE=localhost:5000/$(whoami)/nginx:signed
```

## Exercise 1: push an image and find its digest

Push the image `nginx:1.27-alpine` to the registry as `$IMAGE`. Find its digest: the `sha256` of its manifest.

{{%expand "Solution" %}}
```bash
docker pull nginx:1.27-alpine
docker tag nginx:1.27-alpine $IMAGE
docker push $IMAGE
DIGEST=$(docker inspect --format '{{range .RepoDigests}}{{println .}}{{end}}' $IMAGE | grep "^${IMAGE%:*}@")
echo $DIGEST
# localhost:5000/<user>/nginx@sha256:...
```

A tag (`signed`) is a name which can be moved to another image at any time. The digest is computed from the content of the image: another content gives another digest.
{{% /expand%}}

## Exercise 2: sign the image

Generate a key pair with the password `test123`, then sign the image **by digest** with the private key.

{{% notice note %}}
By default, Cosign also writes the signature in [Rekor](https://docs.sigstore.dev/logging/overview/), the public transparency log of Sigstore. The lab disables it (`--tlog-upload=false`) not to publish training signatures; the verification then needs `--insecure-ignore-tlog=true`.
{{% /notice %}}

{{%expand "Solution" %}}
```bash
# The password of the private key, read by cosign instead of a prompt
export COSIGN_PASSWORD=test123
cosign generate-key-pair
ls cosign.key cosign.pub
cosign sign --key cosign.key --tlog-upload=false --yes $DIGEST
# Pushing signature to: localhost:5000/<user>/nginx
```

The signature is stored in the registry, next to the image, as an OCI artifact whose tag is derived from the digest (`sha256-<digest>.sig`). `cosign.key` is encrypted with the password: in a CI, it is a secret of the pipeline, or a key of a KMS (`--key awskms://...`, `--key hashivault://...`).
{{% /expand%}}

## Exercise 3: verify the signature

1. Verify the signature of `$IMAGE` with the public key.
2. Verify it with the public key of another key pair.
3. Push `nginx:1.29-alpine` with the same tag `$IMAGE`, and verify `$IMAGE` again. Then verify `$DIGEST`.

{{%expand "Solution" %}}
```bash
cosign verify --key cosign.pub --insecure-ignore-tlog=true $IMAGE | jq '.[0].critical.image'
# { "docker-manifest-digest": "sha256:..." }

mkdir -p wrong-key && cd wrong-key
COSIGN_PASSWORD=wrong cosign generate-key-pair
cosign verify --key cosign.pub --insecure-ignore-tlog=true $IMAGE || echo "EXPECTED ERROR"
# Error: no matching signatures: invalid signature when validating ASN.1 encoded signature
cd ..

docker pull nginx:1.29-alpine
docker tag nginx:1.29-alpine $IMAGE
docker push $IMAGE
cosign verify --key cosign.pub --insecure-ignore-tlog=true $IMAGE || echo "EXPECTED ERROR"
# Error: no matching signatures
cosign verify --key cosign.pub --insecure-ignore-tlog=true $DIGEST > /dev/null && echo "the digest is still signed"
```

The tag now points to another image, which nobody signed: the verification fails. This is why the manifests of production should use digests (`image: registry/app@sha256:...`): a tag can be moved by anybody who can push to the registry, a digest cannot.
{{% /expand%}}

## Questions

1. How do you prevent the cluster from running an image which is not signed?
2. What is "keyless" signing?

{{%expand "Answers" %}}
1. With an admission controller which verifies the signatures before a pod is created: the [Sigstore policy-controller](https://docs.sigstore.dev/policy-controller/overview/), or Kyverno (`verifyImages` rules). The older `ImagePolicyWebhook` admission plugin sends each image to an external webhook, which can check signatures too. See also the [allowed registries lab]({{% ref "/1_Labs/allowed-registries" %}}).
2. `cosign sign` without `--key`: Cosign gets a short-lived certificate from Fulcio, the certificate authority of Sigstore, for the identity of the signer (an OIDC login, or the identity of the CI job), and writes the signature in Rekor. There is no private key to protect: the verification checks the identity (`--certificate-identity`, `--certificate-oidc-issuer`).
{{% /expand%}}

## Clean up

```bash
unset COSIGN_PASSWORD
cd $HOME && rm -rf $HOME/cosign
docker rmi $IMAGE
```

The [2-cosign.sh](https://github.com/k8s-school/k8s-advanced/blob/master/labs/7_supply_chain/2-cosign.sh) script of the k8s-advanced repository runs a similar scenario, and keyless signing.
