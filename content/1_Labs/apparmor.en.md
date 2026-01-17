---
title: 'AppArmor Security Profiles'
date: 2024-06-06T16:00:00+10:00
draft: false
weight: 120
tags: ["CKS", "AppArmor", "Security", "Profiles"]
---

## Objectives
Learn to implement AppArmor security profiles in Kubernetes to enforce mandatory access control and restrict container capabilities.

## Prerequisites

### Understanding AppArmor

AppArmor (Application Armor) is a Linux kernel security module that implements mandatory access control (MAC) by confining programs to a limited set of resources through security profiles.

### Q1: How does AppArmor work?

{{%expand "Answer" %}}
AppArmor works by:
- **Path-based security**: Controls access based on file and directory paths
- **Profile enforcement**: Each program can have a specific security profile
- **MAC implementation**: Enforces policies regardless of user privileges
- **Capability restriction**: Limits what system capabilities programs can use

AppArmor profiles define what resources a program can access, including files, network sockets, and system capabilities.
{{% /expand%}}

### Q2: How does AppArmor integrate with Kubernetes?

{{%expand "Answer" %}}
AppArmor integration in Kubernetes:
- **Node-level profiles**: Profiles must be loaded on all nodes where pods might run
- **Pod annotations**: Apply profiles using `container.apparmor.security.beta.kubernetes.io/<container-name>`
- **Profile distribution**: Profiles must exist on every node before pod scheduling
- **Runtime enforcement**: Container runtime applies the profile when starting containers

The kubelet checks for profile availability before allowing pod creation.
{{% /expand%}}

## Create AppArmor Profile

### Step 1: Create AppArmor Profile

Create a file named `nginx-profile` on your host machine:

```bash
# /etc/apparmor.d/nginx-profile
profile nginx-profile flags=(attach_disconnected) {
  #include <abstractions/base>

  # Allow network access
  network,

  # Allow reading specific directories
  /usr/sbin/nginx ix,
  /etc/nginx/** r,
  /var/log/nginx/** w,
  /var/cache/nginx/** rw,

  # Deny access to sensitive files
  deny /etc/shadow r,
  deny /etc/passwd w,
  deny /root/** rw,
}
```

### Step 2: Load Profile on All Nodes

```bash
# Load the profile
apparmor_parser -r -W /etc/apparmor.d/nginx-profile

# Verify profile is loaded
apparmor_status | grep nginx-profile
```

### Verify installation

{{%expand "Answer" %}}
```bash
# Check if AppArmor is enabled
sudo apparmor_status

# List loaded profiles
sudo apparmor_status | grep nginx-profile

# Check profile mode
sudo apparmor_status | grep nginx-profile
```
{{% /expand%}}

## Apply AppArmor to Kubernetes Pod

### Create Secure Pod with AppArmor

```bash
cat << EOF > nginx-apparmor.yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx-secure
  annotations:
    container.apparmor.security.beta.kubernetes.io/nginx: localhost/nginx-profile
spec:
  containers:
  - name: nginx
    image: nginx:latest
    ports:
    - containerPort: 80
EOF

kubectl apply -f nginx-apparmor.yaml
```

### Test Profile Enforcement

{{%expand "Solution" %}}

```bash
# Wait for pod to be ready
kubectl wait --for=condition=Ready pod nginx-secure --timeout=60s

# Test allowed operations
kubectl exec nginx-secure -- cat /etc/nginx/nginx.conf

# Test denied operations (should fail)
kubectl exec nginx-secure -- cat /etc/shadow
kubectl exec nginx-secure -- touch /root/test

# Check logs for denials
dmesg | grep -i apparmor | grep nginx-profile
```

Expected behavior:
- Reading `/etc/nginx/nginx.conf` should succeed
- Reading `/etc/shadow` should be denied
- Creating files in `/root/` should be denied

{{% /expand%}}

## Advanced AppArmor Configuration

> **⚠️ Profile Syntax:** AppArmor profiles are sensitive to syntax. Always test profiles in complain mode first before enforcing them.

### Setting up Custom Rules

We will create a more restrictive profile that demonstrates various AppArmor capabilities.

#### Create the advanced profile

Create a file named `restricted-app-profile`:

```bash
cat << EOF > /etc/apparmor.d/restricted-app-profile
profile restricted-app-profile flags=(attach_disconnected) {
  #include <abstractions/base>

  # Explicitly allow specific capabilities
  capability net_bind_service,
  capability setuid,
  capability setgid,

  # Network restrictions
  network inet tcp,
  deny network inet udp,

  # File access rules
  /usr/bin/** ix,
  /etc/ssl/certs/** r,
  /var/log/app/** rw,

  # Deny dangerous directories
  deny /proc/sys/** rw,
  deny /sys/** rw,
  deny /etc/passwd w,
  deny /etc/shadow r,
  deny /root/** rw,
  deny /home/** rw,

  # Allow temporary files
  /tmp/** rw,
  /var/tmp/** rw,
}
EOF
```

#### Apply with Pod

```bash
# Load the profile
apparmor_parser -r -W /etc/apparmor.d/restricted-app-profile

cat << EOF > test-restricted.yaml
apiVersion: v1
kind: Pod
metadata:
  name: test-restricted
  annotations:
    container.apparmor.security.beta.kubernetes.io/app: localhost/restricted-app-profile
spec:
  containers:
  - name: app
    image: alpine:latest
    command: ["sleep", "3600"]
EOF

kubectl apply -f test-restricted.yaml
```

---

## Testing Profile Restrictions

**Your Task:**

1. Create a test pod with the restricted profile
2. Test various operations to verify profile enforcement
3. Check system logs for AppArmor denials

{{%expand "Solution" %}}
```bash
# Test allowed operations
kubectl exec test-restricted -- ls /tmp
kubectl exec test-restricted -- touch /tmp/testfile

# Test denied operations (should fail)
kubectl exec test-restricted -- cat /etc/shadow
kubectl exec test-restricted -- touch /root/test
kubectl exec test-restricted -- nc -l 1234

# Check denials in system logs
dmesg | grep -i apparmor | grep restricted-app-profile | tail -10

# Alternative: Check audit logs if auditd is running
ausearch -m AVC | grep restricted-app-profile
```

{{% /expand%}}

---

## Profile Development and Debugging

### AppArmor Profile Modes

AppArmor profiles can run in different modes:

- **enforce**: Violations are blocked and logged
- **complain**: Violations are logged but allowed (audit mode)
- **unconfined**: No restrictions applied

#### Switch Profile to Complain Mode

```bash
# Put profile in complain mode for testing
aa-complain /etc/apparmor.d/nginx-profile

# Check profile status
apparmor_status | grep nginx-profile

# Switch back to enforce mode
aa-enforce /etc/apparmor.d/nginx-profile
```

### Generate Profile from Application Behavior

{{%expand "Advanced: Profile Generation" %}}

```bash
# Install AppArmor utilities (if not already installed)
apt-get update && apt-get install -y apparmor-utils

# Generate a basic profile for nginx
aa-genprof nginx

# This will:
# 1. Put nginx in learning mode
# 2. Monitor its behavior
# 3. Generate profile rules based on observed activity

# After running nginx through typical operations, review and save the profile
```

{{% /expand%}}

## Troubleshooting

### Common Issues

```bash
# Profile not found error
kubectl describe pod nginx-secure

# Check if profile exists on node
apparmor_status | grep nginx-profile

# Profile syntax errors
apparmor_parser -r -W /etc/apparmor.d/nginx-profile

# Check AppArmor logs
dmesg | grep -i apparmor
journalctl -u apparmor
```

### Debug Profile Violations

```bash
# Monitor AppArmor denials in real-time
tail -f /var/log/kern.log | grep apparmor

# Or use audit logs (if auditd is running)
ausearch -m AVC --start recent

# Check specific denials for a profile
dmesg | grep "apparmor.*nginx-profile"
```

## Best Practices

1. **Test in complain mode first**: Always test profiles in complain mode before enforcement
2. **Profile distribution**: Ensure profiles are loaded on all nodes
3. **Minimal permissions**: Grant only the minimum required access
4. **Regular auditing**: Monitor AppArmor logs for violations and policy violations
5. **Profile maintenance**: Keep profiles updated as applications evolve
6. **Documentation**: Document profile purpose and restrictions clearly
7. **Automation**: Use configuration management to deploy profiles consistently

## Official Resources

- **Kubernetes Documentation**: [AppArmor Tutorial](https://kubernetes.io/docs/tutorials/security/apparmor/)
- **AppArmor Wiki**: [Ubuntu AppArmor Documentation](https://wiki.ubuntu.com/AppArmor)
- **Profile Examples**: [AppArmor Profile Repository](https://gitlab.com/apparmor/apparmor/-/tree/master/profiles)