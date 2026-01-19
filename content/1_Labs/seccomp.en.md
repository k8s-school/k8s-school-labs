---
title: 'Seccomp Security Profiles'
date: 2024-06-06T19:00:00+10:00
draft: false
weight: 90
tags: ["CKS", "Seccomp", "Security", "Linux", "Syscalls"]
---

## Objectives

Learn how to use seccomp (secure computing mode) to restrict system calls in Kubernetes pods. Seccomp is a Linux kernel feature that limits which system calls a process can make, providing an additional security layer.

## Prerequisites

### Understanding Seccomp

Seccomp is a security mechanism that filters system calls:

- **Default behavior**: Containers can make any system call
- **Security risk**: Malicious code can exploit kernel vulnerabilities
- **Seccomp solution**: Whitelist only necessary system calls
- **Kubernetes integration**: Apply seccomp profiles to pods

### Q1: What are the main seccomp profile types in Kubernetes?

{{%expand "Answer" %}}

| Type | Profile Location | When to Use |
|------|-----------------|-------------|
| **Unconfined** | Nowhere (disabled) | Never (security vulnerability) |
| **RuntimeDefault** | Built into runtime (Containerd/Docker) | Standard "one-size-fits-all" protection |
| **Localhost** | On worker node disk | For custom ultra-secure profiles |

{{% /expand%}}

## Official Kubernetes Seccomp Tutorial

For practical hands-on experience with seccomp profiles, use the official Kubernetes tutorial:

🔗 **[Official Seccomp Tutorial](https://kubernetes.io/docs/tutorials/security/seccomp/)**

To set up a Kubernetes cluster with operational seccomp profiles for testing, run:

```bash
# WARNING: run this outside of k8s-toolbox
git clone https://github.com/k8s-school/k8s-school-labs.git
./k8s-advanced/labs/6_security_hardening/seccomp.sh
```

This script creates a properly configured cluster where you can experiment with:

- RuntimeDefault profiles
- Custom seccomp profiles
- System call restrictions
- Profile testing and validation

## Troubleshooting

### Common Issues

1. **Profile not found**: Ensure profile exists on all nodes
2. **Permission denied**: Check file permissions and paths
3. **Application crashes**: Profile may be too restrictive

### Debugging Steps

```bash
# View real-time Seccomp violations
sudo journalctl -kf | grep "type=1326"

# Search for audit events in rsyslog
sudo grep "audit" /var/log/syslog | tail -n 20

# Search specifically for runtime errors (dmesg) before they are logged
sudo dmesg | grep -i "seccomp"

# Verify profile syntax
cat /var/lib/kubelet/seccomp/profiles/custom-profile.json | jq .
```

## Security Best Practices

1. **Start with RuntimeDefault**: Use runtime's default profile as baseline
2. **Test thoroughly**: Validate applications work with seccomp enabled
3. **Principle of least privilege**: Allow only necessary system calls
4. **Monitor violations**: Log and alert on seccomp violations
5. **Gradual rollout**: Apply seccomp profiles incrementally
6. **Profile versioning**: Version control your custom profiles

## Integration with Other Security Features


### Default Seccomp in Cluster

Enable seccomp by default using admission controllers or Pod Security Standards:

```yaml
# Enforce RuntimeDefault for entire namespace
apiVersion: v1
kind: Namespace
metadata:
  name: secure-namespace
  labels:
    pod-security.kubernetes.io/enforce: baseline
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
```

## Advanced Tools and Operators

### Security Profiles Operator

For production environments, consider using the [Security Profiles Operator](https://github.com/kubernetes-sigs/security-profiles-operator) which automates seccomp profile management:

- Automatic profile distribution across nodes
- Profile validation and testing
- Integration with Pod Security Standards
- Profile lifecycle management


**Note:** This operator is likely not part of the CKS exam scope, but it's useful for real-world deployments where manual profile management becomes complex.

---

## Summary

You've learned:
- ✅ How to apply seccomp profiles to Kubernetes pods
- ✅ Difference between RuntimeDefault and custom profiles
- ✅ Integration with Pod Security Standards
- ✅ Testing and validation techniques
- ✅ Troubleshooting common issues

Seccomp provides fine-grained control over system calls, significantly reducing the attack surface of containerized applications.

## Next Steps

- Create application-specific seccomp profiles
- Integrate seccomp with your CI/CD pipeline
- Monitor seccomp violations in production
- Combine with other security mechanisms (AppArmor, SELinux)
- Consider using tools like Tracee or Falco for runtime monitoring