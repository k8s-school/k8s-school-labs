---
title: 'Container Image Vulnerability Scanning with Trivy'
date: 2024-06-06T21:00:00+10:00
draft: false
weight: 105
tags: ["CKS", "Trivy", "Vulnerability", "Image Security", "Supply Chain"]
---

## Objectives
Learn to use Trivy for container image vulnerability scanning and policy enforcement. Trivy is an essential tool for securing container supply chains in Kubernetes environments.

## Quick Setup

Install Trivy locally for demonstration:

```bash
# Install Trivy (Linux)
curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin

# Verify installation
trivy version
```

## Basic Image Scanning

Scan container images for vulnerabilities:

```bash
# Scan a basic image
trivy image nginx:alpine

# Scan with specific severity
trivy image --severity HIGH,CRITICAL nginx:1.20

# Scan and save results
trivy image --format json --output results.json nginx:alpine
```

### Q1: What information does Trivy provide?

{{%expand "Answer" %}}
- **CVE details**: Common Vulnerabilities and Exposures
- **Severity levels**: LOW, MEDIUM, HIGH, CRITICAL
- **CVSS scores**: Industry standard vulnerability scoring
- **Fixed versions**: Which versions resolve the vulnerabilities
- **Package details**: Affected libraries and dependencies
{{% /expand%}}

## Trivy in Kubernetes

### Scan Running Containers

```bash
# List running containers
kubectl get pods

# Scan a running pod's image
kubectl get pod <pod-name> -o jsonpath='{.spec.containers[0].image}' | xargs trivy image

# Quick cluster scan
kubectl get pods --all-namespaces -o jsonpath='{.items[*].spec.containers[*].image}' | tr ' ' '\n' | sort -u | xargs -I {} trivy image --severity HIGH,CRITICAL {}
```

### Policy Enforcement

Block vulnerable images using admission webhooks:

```bash
# Example: Check image before deployment
if trivy image --exit-code 1 --severity CRITICAL nginx:1.14; then
  echo "✓ Image passed security check"
  kubectl apply -f deployment.yaml
else
  echo "✗ Image blocked - contains CRITICAL vulnerabilities"
fi
```

## Trivy Operator

Deploy Trivy Operator for continuous scanning:

```bash
# Install Trivy Operator
kubectl apply -f https://raw.githubusercontent.com/aquasecurity/trivy-operator/main/deploy/static/trivy-operator.yaml

# Wait for operator to start
kubectl wait --for=condition=Ready pod -l app.kubernetes.io/name=trivy-operator -n trivy-system --timeout=300s

# Check vulnerability reports
kubectl get vulnerabilityreports --all-namespaces
```

## Quick Security Workflow

### 1. Pre-deployment Scan

```bash
# Create a vulnerable test deployment
cat << 'EOF' > vulnerable-app.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: vulnerable-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: vulnerable-app
  template:
    metadata:
      labels:
        app: vulnerable-app
    spec:
      containers:
      - name: app
        image: nginx:1.14  # Older version with vulnerabilities
        ports:
        - containerPort: 80
EOF

# Scan before deployment
trivy image --severity HIGH,CRITICAL nginx:1.14

# Deploy only if scan passes policy
if trivy image --severity CRITICAL nginx:1.14 --exit-code 1; then
  echo "Image has critical vulnerabilities - blocking deployment"
else
  kubectl apply -f vulnerable-app.yaml
fi
```

### 2. Webhook Integration

Simple validation webhook concept:

```bash
# Pre-deployment validation hook
#!/bin/bash
IMAGE="$1"

# Scan image for vulnerabilities
CRITICAL_COUNT=$(trivy image --severity CRITICAL --quiet --format json "$IMAGE" | jq '.Results[].Vulnerabilities | length // 0')

if [ "$CRITICAL_COUNT" -gt 0 ]; then
  echo "REJECT: Image $IMAGE has $CRITICAL_COUNT critical vulnerabilities"
  exit 1
else
  echo "ALLOW: Image $IMAGE passed security scan"
  exit 0
fi
```

## SBOM Generation

Generate Software Bill of Materials:

```bash
# Generate SBOM for an image
trivy image --format spdx-json --output sbom.spdx.json nginx:alpine

# View SBOM summary
trivy sbom sbom.spdx.json

# Check SBOM for specific packages
jq '.packages[] | select(.name | contains("openssl"))' sbom.spdx.json
```

## CI/CD Integration

### GitLab CI Example

```yaml
# .gitlab-ci.yml snippet
image-scan:
  stage: security
  image: aquasec/trivy:latest
  script:
    - trivy image --exit-code 1 --severity CRITICAL $CI_REGISTRY_IMAGE:$CI_COMMIT_SHA
  allow_failure: false
```

### GitHub Actions Example

```yaml
# .github/workflows/security.yml snippet
- name: Run Trivy vulnerability scanner
  uses: aquasecurity/trivy-action@master
  with:
    image-ref: 'myapp:latest'
    format: 'sarif'
    output: 'trivy-results.sarif'
    severity: 'CRITICAL,HIGH'
```

## Quick Commands Reference

```bash
# Essential Trivy commands for CKS
trivy image nginx:alpine                           # Basic scan
trivy image --severity CRITICAL nginx:alpine       # High-priority only
trivy image --exit-code 1 nginx:alpine            # Fail on vulnerabilities
trivy fs .                                         # Scan filesystem/code
trivy k8s --report summary                         # Cluster overview
trivy repo https://github.com/user/repo            # Git repository scan
```

## Integration with Other Tools

### With Falco

```yaml
# Falco rule to detect vulnerable container starts
- rule: Vulnerable Container Started
  desc: Container with known vulnerabilities started
  condition: >
    container_started and
    container.image.repository contains "nginx" and
    container.image.tag="1.14"
  output: "Vulnerable container started (image=%container.image)"
  priority: WARNING
```

### With Custom Admission Webhook

```yaml
# Simple admission webhook deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: image-security-webhook
spec:
  replicas: 1
  selector:
    matchLabels:
      app: image-security-webhook
  template:
    metadata:
      labels:
        app: image-security-webhook
    spec:
      containers:
      - name: webhook
        image: your-registry/trivy-webhook:latest
        ports:
        - containerPort: 8443
        env:
        - name: TLS_CERT_FILE
          value: /etc/certs/tls.crt
        - name: TLS_PRIVATE_KEY_FILE
          value: /etc/certs/tls.key
        volumeMounts:
        - name: certs
          mountPath: /etc/certs
          readOnly: true
```

## Security Best Practices

1. **Scan early and often**: Integrate into CI/CD pipeline
2. **Policy-based enforcement**: Block deployment of vulnerable images
3. **Regular updates**: Keep Trivy database updated
4. **Baseline scanning**: Establish vulnerability thresholds
5. **SBOM tracking**: Maintain software inventory
6. **Combine with runtime security**: Use with Falco for complete coverage

## Quick Troubleshooting

```bash
# Update Trivy database
trivy image --download-db-only

# Check Trivy configuration
trivy --help

# Debug scanning issues
trivy image --debug nginx:alpine

# Check operator status
kubectl get pods -n trivy-system
kubectl logs -n trivy-system -l app.kubernetes.io/name=trivy-operator
```

---

## Summary

You've learned:
- ✅ Basic Trivy image vulnerability scanning
- ✅ Policy enforcement to block vulnerable images
- ✅ Trivy Operator for continuous cluster monitoring
- ✅ SBOM generation for supply chain transparency
- ✅ CI/CD integration patterns

Trivy provides essential vulnerability management for secure Kubernetes deployments.

## Next Steps

- Integrate Trivy into your deployment pipeline
- Set up automated scanning policies
- Configure alerts for new vulnerabilities
- Establish vulnerability SLAs and remediation processes