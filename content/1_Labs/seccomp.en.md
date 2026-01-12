---
title: 'Seccomp Security Profiles'
date: 2024-06-06T19:00:00+10:00
draft: false
weight: 70
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
1. **Unconfined**: No restrictions (default for most runtimes)
2. **RuntimeDefault**: Use the container runtime's default seccomp profile
3. **Localhost**: Use a custom seccomp profile from the node's filesystem
4. **Custom profiles**: JSON files defining allowed/blocked syscalls
{{% /expand%}}

## Using RuntimeDefault Profile

The simplest and most common approach is using the runtime's default seccomp profile:

### Example Pod with RuntimeDefault

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: seccomp-runtime-default
spec:
  securityContext:
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: test-container
    image: nginx:alpine
    command: ["/bin/sh"]
    args: ["-c", "while true; do sleep 30; done;"]
```

### Testing the Default Profile

```bash
# Apply the pod
kubectl apply -f seccomp-pod.yaml

# Test system calls
kubectl exec -it seccomp-runtime-default -- sh

# Try some commands (these should work)
ps aux
ls -la
cat /etc/passwd

# Try restricted operations (these might be blocked)
mount
reboot  # Should fail with permission error
```

## Custom Seccomp Profiles

For more granular control, create custom seccomp profiles:

### Step 1: Create a Custom Profile

Create a seccomp profile that blocks specific system calls:

```bash
# Create profiles directory on all nodes
sudo mkdir -p /var/lib/kubelet/seccomp/profiles
```

```json
{
  "defaultAction": "SCMP_ACT_ALLOW",
  "syscalls": [
    {
      "names": ["mount", "umount2", "syslog"],
      "action": "SCMP_ACT_ERRNO"
    },
    {
      "names": ["reboot"],
      "action": "SCMP_ACT_KILL"
    }
  ]
}
```

Save this as `/var/lib/kubelet/seccomp/profiles/custom-profile.json`

### Step 2: Use Custom Profile

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: seccomp-custom-profile
spec:
  securityContext:
    seccompProfile:
      type: Localhost
      localhostProfile: profiles/custom-profile.json
  containers:
  - name: test-container
    image: nginx:alpine
    command: ["/bin/sh"]
    args: ["-c", "while true; do sleep 30; done;"]
```

## Pod Security Standards Integration

Seccomp profiles work with Pod Security Standards:

### Restricted Profile Requirement

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: restricted-seccomp
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
---
apiVersion: v1
kind: Pod
metadata:
  name: compliant-pod
  namespace: restricted-seccomp
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

## Container-Level Seccomp

You can also apply seccomp profiles at the container level:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: container-level-seccomp
spec:
  containers:
  - name: restricted-container
    image: nginx:alpine
    securityContext:
      seccompProfile:
        type: RuntimeDefault
  - name: unconfined-container
    image: busybox:latest
    securityContext:
      seccompProfile:
        type: Unconfined
    command: ["/bin/sh"]
    args: ["-c", "while true; do sleep 30; done;"]
```

## Testing and Validation

### Verify Seccomp is Applied

```bash
# Check if seccomp is enabled on the node
grep -i seccomp /proc/version

# Check container's seccomp status
kubectl exec <pod-name> -- grep -i seccomp /proc/1/status

# Look for "Seccomp: 2" (filtered mode)
```

### Test System Call Restrictions

```bash
# Create a test pod
kubectl run seccomp-test --image=busybox:latest \
  --restart=Never \
  --overrides='{"spec":{"securityContext":{"seccompProfile":{"type":"RuntimeDefault"}},"containers":[{"name":"seccomp-test","image":"busybox:latest","command":["/bin/sh"],"args":["-c","while true; do sleep 30; done;"],"securityContext":{"seccompProfile":{"type":"RuntimeDefault"}}}]}}'

# Test restricted operations
kubectl exec -it seccomp-test -- sh

# These might be restricted depending on the profile
strace -c ls 2>&1 | head -10  # System call tracing
mount  # Should fail
reboot # Should fail
```

## Advanced Seccomp Profiles

### Profile for Web Applications

```json
{
  "defaultAction": "SCMP_ACT_ERRNO",
  "syscalls": [
    {
      "names": [
        "accept", "accept4", "access", "arch_prctl", "bind", "brk",
        "clone", "close", "connect", "dup", "dup2", "epoll_create1",
        "epoll_ctl", "epoll_wait", "execve", "exit", "exit_group",
        "fcntl", "fstat", "futex", "getcwd", "getdents64", "getpid",
        "getppid", "getrandom", "getsockname", "getsockopt", "getuid",
        "ioctl", "listen", "lseek", "mmap", "mprotect", "munmap",
        "nanosleep", "open", "openat", "poll", "read", "readv",
        "recvfrom", "recvmsg", "rt_sigaction", "rt_sigprocmask",
        "rt_sigreturn", "sched_getaffinity", "sendmsg", "sendto",
        "set_robust_list", "setsockopt", "socket", "stat", "write",
        "writev"
      ],
      "action": "SCMP_ACT_ALLOW"
    }
  ]
}
```

### Profile Generator

Use tools to generate profiles based on application behavior:

```bash
# Install seccomp-tools (on development machine)
# gem install seccomp-tools

# Generate profile from running container
# docker run --security-opt seccomp=unconfined --name profiling-container nginx:alpine
# seccomp-tools dump $(docker inspect profiling-container -f '{{.State.Pid}}')
```

## Troubleshooting

### Common Issues

1. **Profile not found**: Ensure profile exists on all nodes
2. **Permission denied**: Check file permissions and paths
3. **Application crashes**: Profile may be too restrictive

### Debugging Steps

```bash
# Check kubelet logs
journalctl -u kubelet | grep -i seccomp

# Check container runtime logs
journalctl -u containerd | grep -i seccomp

# Verify profile syntax
cat /var/lib/kubelet/seccomp/profiles/custom-profile.json | jq .

# Check pod events
kubectl describe pod <pod-name>
```

## Security Best Practices

1. **Start with RuntimeDefault**: Use runtime's default profile as baseline
2. **Test thoroughly**: Validate applications work with seccomp enabled
3. **Principle of least privilege**: Allow only necessary system calls
4. **Monitor violations**: Log and alert on seccomp violations
5. **Gradual rollout**: Apply seccomp profiles incrementally
6. **Profile versioning**: Version control your custom profiles

## Integration with Other Security Features

### Combine with AppArmor

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: multi-security-pod
  annotations:
    container.apparmor.security.beta.kubernetes.io/secure-container: runtime/default
spec:
  securityContext:
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: secure-container
    image: nginx:alpine
    securityContext:
      runAsNonRoot: true
      runAsUser: 1001
      capabilities:
        drop:
        - ALL
      readOnlyRootFilesystem: true
```

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