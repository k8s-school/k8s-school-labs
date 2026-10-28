---
title: "Trivy: Container Vulnerability Scanning"
description: "Learn to scan container images for vulnerabilities and generate Software Bills of Materials (SBOM) using Trivy"
weight: 25
tags: ["CKS", "Trivy", "Vulnerability", "Image Security", "Supply Chain"]
---

**Author:** Fabrice JAMMES ([LinkedIn](https://www.linkedin.com/in/fabrice-jammes-5b29b042/)).

## Objective

- Scan container images for known vulnerabilities (CVE) with [Trivy](https://trivy.dev/)
- Find and remove the running pods whose images have critical vulnerabilities: a classic CKS task
- Generate a Software Bill of Materials (SBOM), and scan it

The CKS curriculum lists "Perform static analysis of user workloads and container images" and "Understand your supply chain (SBOM, CI/CD, artifact repositories)" in the *Supply chain security* domain.

## Prerequisites

`trivy` is installed on the training server. The lab works on the shared cluster, in a namespace of your own.

```bash
trivy --version
# The shared kind cluster (on the CKS training server: kind export kubeconfig, then kubectx kind-kind)
kubectx kind-kind
NS=trivy-$(whoami)
kubectl create namespace $NS
kubectl config set-context --current --namespace=$NS
mkdir -p $HOME/trivy && cd $HOME/trivy
```

## Exercise 1: scan an image

Scan the image `nginx:1.19` and display only its `CRITICAL` vulnerabilities. Then count the `CRITICAL` vulnerabilities of `nginx:1.19` and of `nginx:1.29-alpine`.

{{%expand "Solution" %}}
```bash
trivy image --severity CRITICAL nginx:1.19

count() {
  trivy image --quiet --format json --severity CRITICAL $1 | jq '[.Results[]?.Vulnerabilities[]?] | length'
}
echo "nginx:1.19: $(count nginx:1.19) CRITICAL"
echo "nginx:1.29-alpine: $(count nginx:1.29-alpine) CRITICAL"
# nginx:1.19: 42 CRITICAL
# nginx:1.29-alpine: 0 CRITICAL
```

The first scan downloads the vulnerability database of Trivy. The numbers change every day: new CVEs are published, and the images with a floating tag are rebuilt. An old image based on a full distribution has many more vulnerabilities than a recent image based on Alpine, which has fewer packages.
{{% /expand%}}

## Exercise 2: remove the vulnerable pods

Run three pods in your namespace: `web-old` (`nginx:1.19`), `web-new` (`nginx:1.29-alpine`) and `pause` (`registry.k8s.io/pause:3.10`).

Then, as in the exam: **find the images of the running pods of the namespace, scan them, and delete the pods whose image has `CRITICAL` vulnerabilities**.

{{% notice tip %}}
`trivy image --exit-code 1 --severity CRITICAL` returns `1` if it finds a critical vulnerability: use it in a `if`.
{{% /notice %}}

{{%expand "Solution" %}}
```bash
kubectl run web-old --image=nginx:1.19
kubectl run web-new --image=nginx:1.29-alpine
kubectl run pause --image=registry.k8s.io/pause:3.10
kubectl wait --for=condition=Ready pod --all --timeout=120s

kubectl get pods -o custom-columns=POD:.metadata.name,IMAGE:.spec.containers[*].image
for pod in $(kubectl get pods -o jsonpath='{.items[*].metadata.name}'); do
  image=$(kubectl get pod $pod -o jsonpath='{.spec.containers[0].image}')
  if ! trivy image --quiet --exit-code 1 --severity CRITICAL $image >/dev/null; then
    echo "$pod ($image): CRITICAL vulnerabilities, delete"
    kubectl delete pod $pod
  fi
done
# web-old (nginx:1.19): CRITICAL vulnerabilities, delete
kubectl get pods
```

In the exam, the pods may have several containers and init containers: list all their images with `-o jsonpath='{.items[*].spec.containers[*].image}'`, and check the `initContainers` too.
{{% /expand%}}

## Exercise 3: SBOM

Generate the SBOM of `nginx:1.29-alpine` in the CycloneDX format. Which packages does the image contain? Then scan the SBOM instead of the image.

{{%expand "Solution" %}}
```bash
trivy image --quiet --format cyclonedx --output nginx-sbom.json nginx:1.29-alpine
jq -r '.components[] | "\(.name) \(.version)"' nginx-sbom.json | head
jq '.components | length' nginx-sbom.json
trivy sbom --quiet --severity HIGH,CRITICAL nginx-sbom.json
```

The SBOM lists all the packages and libraries of the image, with their versions. Publish it with each image version: when a new CVE is published, scanning the SBOMs tells which images are affected, without pulling them. `--format spdx-json` gives the other standard format, SPDX.
{{% /expand%}}

## Exercise 4: a gate in the CI

How do you stop a CI pipeline when an image has `CRITICAL` vulnerabilities which have a fix?

{{%expand "Solution" %}}
```bash
trivy image --quiet --exit-code 1 --severity CRITICAL --ignore-unfixed nginx:1.19 >/dev/null || echo "EXPECTED: the pipeline stops"
trivy image --quiet --exit-code 1 --severity CRITICAL --ignore-unfixed nginx:1.29-alpine >/dev/null && echo "the pipeline continues"
```

`--ignore-unfixed` skips the vulnerabilities which have no fixed version yet: the developers cannot fix them by updating a package. The pipeline then publishes the image and its SBOM, and signs them, see the [cosign lab]({{% ref "/1_Labs/cosign" %}}).
{{% /expand%}}

## Questions

1. An image was scanned without vulnerability when it was built. Is it still safe 6 months later?
2. How do you scan continuously the images running in a cluster?

{{%expand "Answers" %}}
1. Not necessarily: new CVEs are published every day for the packages it contains. Scan the images again regularly, or their SBOMs.
2. The [Trivy Operator](https://github.com/aquasecurity/trivy-operator) scans the workloads of the cluster and stores the results in `VulnerabilityReport` objects. Combined with an admission policy (see the [allowed registries lab]({{% ref "/1_Labs/allowed-registries" %}})), only the images of a trusted registry, scanned by the CI, can run.
{{% /expand%}}

## Clean up

```bash
kubectl delete namespace $NS
kubectl config set-context --current --namespace=default
cd $HOME && rm -rf $HOME/trivy
```

The [1-trivy.sh](https://github.com/k8s-school/k8s-advanced/blob/master/labs/7_supply_chain/1-trivy.sh) script of the k8s-advanced repository runs similar scans.
