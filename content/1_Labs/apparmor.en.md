---
title: 'AppArmor Security Profiles'
date: 2024-06-06T20:00:00+10:00
draft: false
weight: 95
tags: ["CKS", "AppArmor", "Security", "Linux", "MAC"]
---

## Objectives
Learn how to use AppArmor (Application Armor) to enforce Mandatory Access Control (MAC) policies on Kubernetes pods. AppArmor is a Linux security module that provides fine-grained access control for applications.

## Prerequisites

### Understanding AppArmor
AppArmor is a Linux kernel security module that:

- **Mandatory Access Control**: Enforces policies that applications cannot override
- **Path-based**: Controls access to files, directories, and capabilities
- **Profile-based**: Uses text-based profiles to define allowed operations
- **Kubernetes integration**: Applied via pod annotations

### Q1: What are the main AppArmor profile modes?

{{%expand "Answer" %}}
1. **Enforce**: Actively denies operations that violate the profile
2. **Complain**: Logs violations but allows operations to proceed
3. **Unconfined**: No restrictions applied (default for most applications)
4. **Kill**: Terminates the process if it violates the profile
{{% /expand%}}

### Q2: How does AppArmor differ from seccomp?

{{%expand "Answer" %}}
- **AppArmor**: Controls access to files, network, capabilities (path-based)
- **Seccomp**: Controls which system calls can be made (syscall-based)
- **Complementary**: Often used together for defense in depth
- **Scope**: AppArmor is broader, seccomp is more granular
{{% /expand%}}

## Check AppArmor Support

First, verify that AppArmor is available and enabled:

```bash
# Check if AppArmor is enabled on the node
sudo aa-status

# List available profiles
sudo aa-enabled

# Check AppArmor filesystem
ls -la /sys/kernel/security/apparmor/

# Verify kubelet supports AppArmor
kubectl version --short
```

## Using Runtime Default Profile

The simplest approach is using the runtime's default AppArmor profile:

### Example Pod with Runtime Default

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: apparmor-runtime-default
  annotations:
    container.apparmor.security.beta.kubernetes.io/test-container: runtime/default
spec:
  containers:
  - name: test-container
    image: nginx:alpine
    command: ["/bin/sh"]
    args: ["-c", "while true; do sleep 30; done;"]
```

### Testing Default Restrictions

```bash
# Apply the pod
kubectl apply -f apparmor-pod.yaml

# Test basic operations (should work)
kubectl exec -it apparmor-runtime-default -- sh
ls -la
cat /etc/passwd
ps aux

# Test restricted operations (some may be blocked)
mount
chmod 777 /tmp
```

## Custom AppArmor Profiles

For specific security requirements, create custom AppArmor profiles:

### Step 1: Create Profile on Nodes

Create a custom AppArmor profile on all cluster nodes:

```bash
# Create custom profile directory
sudo mkdir -p /etc/apparmor.d/

# Create a restrictive profile
sudo tee /etc/apparmor.d/k8s-restricted-profile << 'EOF'
#include <tunables/global>

profile k8s-restricted-profile flags=(attach_disconnected) {
  #include <abstractions/base>

  # Allow basic operations
  capability net_bind_service,
  capability setuid,
  capability setgid,

  # File access restrictions
  /usr/bin/** mr,
  /bin/** mr,
  /lib/** mr,
  /lib64/** mr,
  /etc/** r,
  /tmp/** rw,
  /var/tmp/** rw,

  # Deny dangerous operations
  deny /proc/sys/** w,
  deny /sys/** w,
  deny mount,
  deny umount,
  deny capability sys_admin,
  deny capability sys_module,

  # Network restrictions
  network inet tcp,
  network inet udp,
  deny network inet raw,

  # Process restrictions
  deny ptrace,
  deny signal,

  # Deny access to sensitive files
  deny /etc/shadow r,
  deny /etc/sudoers r,
  deny /root/** rw,
}
EOF

# Load the profile
sudo apparmor_parser -r /etc/apparmor.d/k8s-restricted-profile

# Verify profile is loaded
sudo aa-status | grep k8s-restricted-profile
```

### Step 2: Use Custom Profile in Pod

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: apparmor-custom-profile
  annotations:
    container.apparmor.security.beta.kubernetes.io/restricted-container: localhost/k8s-restricted-profile
spec:
  containers:
  - name: restricted-container
    image: nginx:alpine
    command: ["/bin/sh"]
    args: ["-c", "while true; do sleep 30; done;"]
```

### Step 3: Test Custom Restrictions

```bash
# Apply the pod
kubectl apply -f custom-apparmor-pod.yaml

# Test allowed operations
kubectl exec -it apparmor-custom-profile -- sh
ls /tmp
echo "test" > /tmp/testfile
cat /tmp/testfile

# Test denied operations (should fail)
cat /etc/shadow          # Should be denied
mount                    # Should be denied
chmod 777 /etc/passwd    # Should be denied
```

## AppArmor Profile Development

### Generate Profile from Application Behavior

Use AppArmor tools to create profiles based on actual application behavior:

```bash
# Install AppArmor utilities (on Ubuntu/Debian)
sudo apt-get install apparmor-utils

# Create a profile in learning mode
sudo aa-genprof /usr/bin/nginx

# Run the application and exercise its functionality
# In another terminal:
kubectl exec -it test-pod -- nginx -t
kubectl exec -it test-pod -- nginx -s reload

# Finish learning and create profile
sudo aa-logprof
```

### Complain Mode for Testing

Use complain mode to test profiles without blocking operations:

```bash
# Set profile to complain mode
sudo aa-complain /etc/apparmor.d/k8s-restricted-profile

# Check profile status
sudo aa-status | grep k8s-restricted-profile
# Should show: k8s-restricted-profile (complain)

# Test with pod - operations will be logged but not blocked
# Check logs:
sudo tail -f /var/log/kern.log | grep ALLOWED
```

## Multi-Container Pod Configuration

Apply different AppArmor profiles to different containers:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: multi-container-apparmor
  annotations:
    # Different profiles for different containers
    container.apparmor.security.beta.kubernetes.io/web-server: runtime/default
    container.apparmor.security.beta.kubernetes.io/database: localhost/k8s-restricted-profile
spec:
  containers:
  - name: web-server
    image: nginx:alpine
    ports:
    - containerPort: 80
  - name: database
    image: postgres:alpine
    env:
    - name: POSTGRES_PASSWORD
      value: "secretpassword"
    command: ["/bin/sh"]
    args: ["-c", "while true; do sleep 30; done;"]
```

## Integration with Pod Security Standards

AppArmor works alongside Pod Security Standards:

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: apparmor-restricted
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
---
apiVersion: v1
kind: Pod
metadata:
  name: fully-secured-pod
  namespace: apparmor-restricted
  annotations:
    container.apparmor.security.beta.kubernetes.io/app: runtime/default
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1001
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: app
    image: nginx:alpine
    securityContext:
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      runAsNonRoot: true
      runAsUser: 1001
      capabilities:
        drop:
        - ALL
```

## Web Application Profile Example

Specific profile for web applications:

```bash
sudo tee /etc/apparmor.d/k8s-web-app-profile << 'EOF'
#include <tunables/global>

profile k8s-web-app-profile flags=(attach_disconnected) {
  #include <abstractions/base>
  #include <abstractions/nameservice>

  # Web server capabilities
  capability net_bind_service,
  capability setuid,
  capability setgid,
  capability chown,
  capability fowner,

  # File access for web applications
  /usr/bin/** mr,
  /bin/** mr,
  /lib/** mr,
  /lib64/** mr,
  /etc/** r,
  /var/www/** r,
  /tmp/** rw,
  /var/tmp/** rw,
  /var/log/** rw,

  # Web server specific
  /run/** rw,
  /var/run/** rw,

  # Network access
  network inet tcp,
  network inet udp,
  network inet6 tcp,
  network inet6 udp,

  # Deny dangerous operations
  deny /etc/shadow r,
  deny /etc/sudoers r,
  deny /root/** rw,
  deny capability sys_admin,
  deny capability sys_module,
  deny mount,
  deny umount,
  deny ptrace,

  # Allow signal handling for graceful shutdown
  signal receive set=(term, kill, usr1, usr2),
}
EOF

sudo apparmor_parser -r /etc/apparmor.d/k8s-web-app-profile
```

## Troubleshooting AppArmor

### Common Issues

1. **Profile not found**: Ensure profile exists on all nodes where pod might run
2. **Profile syntax errors**: Use `apparmor_parser` to validate
3. **Permission denied**: Check AppArmor logs for denied operations
4. **Pod fails to start**: Verify annotation syntax and profile names

### Debugging Steps

```bash
# Check AppArmor status
sudo aa-status

# Validate profile syntax
sudo apparmor_parser -Q /etc/apparmor.d/profile-name

# Check AppArmor logs
sudo tail -f /var/log/kern.log | grep -i apparmor
sudo journalctl -f | grep -i apparmor

# Test profile manually
sudo aa-exec -p profile-name -- /bin/bash

# Check pod annotation
kubectl get pod <pod-name> -o yaml | grep apparmor
```

### Profile Debugging

```bash
# Enable verbose logging
echo 'Y' | sudo tee /sys/module/apparmor/parameters/debug

# Set profile to complain mode for debugging
sudo aa-complain /etc/apparmor.d/profile-name

# View profile violations
sudo aa-logprof

# Return to enforce mode
sudo aa-enforce /etc/apparmor.d/profile-name
```

## Security Best Practices

1. **Start with runtime/default**: Use default profiles before creating custom ones
2. **Use complain mode**: Test custom profiles in complain mode first
3. **Principle of least privilege**: Grant only necessary permissions
4. **Regular updates**: Keep profiles updated with application changes
5. **Monitoring**: Monitor AppArmor violations and adjust profiles
6. **Documentation**: Document profile requirements and rationale

## Node Preparation Automation

For production deployments, automate AppArmor profile distribution:

```bash
#!/bin/bash
# deploy-apparmor-profiles.sh

NODES=$(kubectl get nodes -o name | cut -d/ -f2)

for node in $NODES; do
  echo "Deploying AppArmor profiles to node: $node"

  # Copy profiles to node
  scp /etc/apparmor.d/k8s-* "ubuntu@$node:/tmp/"

  # Load profiles on node
  ssh "ubuntu@$node" 'sudo mv /tmp/k8s-* /etc/apparmor.d/ && sudo apparmor_parser -r /etc/apparmor.d/k8s-*'
done
```

## Profile Templates

### Database Profile

```bash
sudo tee /etc/apparmor.d/k8s-database-profile << 'EOF'
profile k8s-database-profile flags=(attach_disconnected) {
  #include <abstractions/base>
  #include <abstractions/nameservice>

  capability setuid,
  capability setgid,
  capability fowner,
  capability chown,

  # Database file access
  /var/lib/postgresql/** rwk,
  /tmp/** rw,
  /run/postgresql/** rw,

  # Execution
  /usr/lib/postgresql/** mr,
  /bin/** mr,
  /usr/bin/** mr,

  # Network for client connections
  network inet tcp,
  network inet6 tcp,

  # Deny dangerous operations
  deny mount,
  deny capability sys_admin,
  deny /etc/shadow r,
}
EOF
```

---

## Summary

You've learned:
- ✅ How to apply AppArmor profiles to Kubernetes pods
- ✅ Creating custom AppArmor profiles for specific applications
- ✅ Integration with Pod Security Standards
- ✅ Debugging and troubleshooting AppArmor issues
- ✅ Best practices for profile development and deployment

AppArmor provides fine-grained access control that complements other Kubernetes security mechanisms.

## Next Steps

- Automate profile distribution across cluster nodes
- Integrate AppArmor with CI/CD pipeline
- Monitor AppArmor violations in production
- Create application-specific profiles for your workloads
- Combine with seccomp and other security features