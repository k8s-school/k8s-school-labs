---
title: "Trivy: Container Vulnerability Scanning"
description: "Learn to scan container images for vulnerabilities and generate Software Bills of Materials (SBOM) using Trivy"
weight: 25
tags: ["CKS", "Trivy", "Vulnerability", "Image Security", "Supply Chain"]
---

## Overview

This lab demonstrates how to use Trivy, an open-source vulnerability scanner, to analyze container images for security issues and generate Software Bills of Materials (SBOM) for supply chain security.

## Learning Objectives

By the end of this lab, you will be able to:
- Install and configure Trivy
- Scan container images for vulnerabilities
- Filter results by severity levels
- Generate and analyze SBOM files
- Compare security postures between different images

## Prerequisites

- Docker installed and running
- Internet connectivity for downloading images
- Basic understanding of container security concepts

## Lab Exercises

### Exercise 1: Trivy Installation

Trivy can be installed on various Linux distributions. The installation process is automated in the lab script.

#### Installation Methods

For detailed installation instructions, please refer to the [official Trivy installation guide](https://trivy.dev/docs/latest/getting-started/installation/#installing-trivy).

**Verify Installation:**
```bash
trivy --version
```

### Exercise 2: Basic Vulnerability Scanning

#### Scan for Critical Vulnerabilities

Start by scanning an older, vulnerable image for critical security issues:

```bash
# Scan for CRITICAL vulnerabilities only
trivy image --severity CRITICAL nginx:1.19
```

#### Scan for High and Critical Vulnerabilities

Expand the scan to include high-severity vulnerabilities:

```bash
# Scan for HIGH and CRITICAL vulnerabilities
trivy image --severity HIGH,CRITICAL nginx:1.19
```

**Expected Output:**
- List of vulnerabilities with CVE IDs
- Severity levels and CVSS scores
- Description of security issues
- Fixed versions when available

### Exercise 3: SBOM Generation

Software Bill of Materials (SBOM) provides transparency into software components and dependencies.

#### Generate SBOM for Vulnerable Image

```bash
# Generate SBOM in CycloneDX format
trivy image --format cyclonedx --output nginx-1.19-sbom.json nginx:1.19

# View SBOM file structure
cat nginx-1.19-sbom.json | jq '.components[0:3]'
```

#### Analyze SBOM with Trivy

```bash
# Analyze the generated SBOM
trivy sbom nginx-1.19-sbom.json
```

### Exercise 4: Security Comparison

Compare vulnerability counts between different image versions to demonstrate the importance of keeping images updated.

#### Scan Secure Alternative Image

```bash
# Scan more secure alpine-based image
trivy image --severity HIGH,CRITICAL nginx:alpine

# Generate SBOM for comparison
trivy image --format cyclonedx --output nginx-alpine-sbom.json nginx:alpine
```

#### Automated Vulnerability Comparison

The lab script includes automated comparison using JSON output:

```bash
# Get vulnerability counts programmatically
VULN_OLD=$(trivy image --format json --quiet nginx:1.19 2>/dev/null | \
  jq '[.Results[]?.Vulnerabilities[]? | select(.Severity == "CRITICAL" or .Severity == "HIGH")] | length')

VULN_NEW=$(trivy image --format json --quiet nginx:alpine 2>/dev/null | \
  jq '[.Results[]?.Vulnerabilities[]? | select(.Severity == "CRITICAL" or .Severity == "HIGH")] | length')

echo "nginx:1.19: $VULN_OLD HIGH/CRITICAL vulnerabilities"
echo "nginx:alpine: $VULN_NEW HIGH/CRITICAL vulnerabilities"
```

### Exercise 5: Advanced Scanning Options

#### Scan Specific Vulnerability Types

```bash
# Scan for specific package managers
trivy image --scanners vuln,secret nginx:1.19

# Include configuration scanning
trivy image --scanners vuln,config,secret nginx:1.19
```

#### Output Formats

```bash
# Generate report in different formats
trivy image --format table nginx:alpine          # Human-readable table
trivy image --format json nginx:alpine           # Machine-readable JSON
trivy image --format sarif nginx:alpine          # SARIF format for CI/CD
trivy image --format spdx-json nginx:alpine      # SPDX SBOM format
```

## Key Takeaways

### Security Insights

1. **Image Age Matters**: Older images like `nginx:1.19` contain significantly more vulnerabilities than recent versions
2. **Base Image Selection**: Alpine-based images often have smaller attack surfaces
3. **Regular Updates**: Keeping base images updated is crucial for security
4. **SBOM Importance**: Software Bills of Materials provide transparency for compliance and security reviews

### Best Practices

- **Automate Scanning**: Integrate Trivy into CI/CD pipelines
- **Set Thresholds**: Fail builds when critical vulnerabilities are detected
- **Monitor Regularly**: Scan running containers, not just during build time
- **Use SBOM**: Generate and maintain SBOM files for supply chain transparency

### Integration Examples

#### CI/CD Integration

```bash
# Fail build if critical vulnerabilities found
trivy image --exit-code 1 --severity CRITICAL myapp:latest

# Generate SBOM for release
trivy image --format spdx-json --output release-sbom.json myapp:latest
```

#### Kubernetes Integration

Consider using the [Trivy Operator](https://github.com/aquasecurity/trivy-operator) for automated scanning of running workloads in Kubernetes clusters. The Trivy Operator continuously scans container images, workloads, and cluster configurations for vulnerabilities and security issues, providing native Kubernetes CRDs for vulnerability reports and compliance results.

## Troubleshooting

### Common Issues

1. **Network Connectivity**: Ensure internet access for vulnerability database updates
2. **Storage Space**: Trivy downloads vulnerability databases (several GB)
3. **Rate Limits**: Docker Hub rate limits may affect image pulling

### Useful Commands

```bash
# Clear Trivy cache
trivy clean --all

# Update vulnerability database
trivy image --download-db-only

# Show database info
trivy version
```

## Next Steps

After completing this lab:
1. Explore Trivy Operator for Kubernetes integration
2. [Learn about container image signing with Cosign](cosign.en.md)
3. Implement ImagePolicyWebhook for admission control
4. Set up automated vulnerability monitoring

## References

- [Trivy Official Documentation](https://aquasecurity.github.io/trivy/)
- [Container Security Best Practices](https://kubernetes.io/docs/concepts/security/)
- [NIST SSDF Guidelines](https://csrc.nist.gov/Projects/ssdf)