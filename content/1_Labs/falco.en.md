---
title: 'Runtime Security with Falco'
date: 2024-06-06T16:00:00+10:00
draft: false
weight: 40
tags: ["CKS", "Falco", "Runtime", "Security"]
---

## Objectives
Use Falco to detect suspicious behaviors inside containers in real-time and learn to configure custom security rules for Kubernetes environments.

## Prerequisites

### Understanding Falco
Falco is a cloud-native runtime security project that detects unexpected behavior, intrusions, and data theft in real-time. It works by monitoring system calls and Kubernetes events.

### Q1: What does Falco monitor?
{{%expand "Answer" %}}
Falco monitors:
- **System calls**: File access, process execution, network activity
- **Kubernetes events**: Pod creation, service account changes, ConfigMap modifications
- **Runtime behavior**: Shell access in containers, privilege escalations, suspicious file access

Falco uses rules written in a YAML format that define suspicious activities and generate alerts when these conditions are met.
{{% /expand%}}

### Q2: How does Falco work in Kubernetes?
{{%expand "Answer" %}}
Falco typically runs as a DaemonSet in Kubernetes:
- **One pod per node**: Monitors all containers on that node
- **Kernel module or eBPF**: Captures system call information
- **Rule engine**: Evaluates events against security rules
- **Output**: Sends alerts to logs, SIEM systems, or notification channels

The default installation includes pre-built rules for common security scenarios.
{{% /expand%}}

## Install Falco on Kind

### Setup Falco
```bash
# Add Falco Helm repository
helm repo add falcosecurity https://falcosecurity.github.io/charts
helm repo update

# Install Falco in its own namespace
helm install falco falcosecurity/falco \
  --namespace falco-system \
  --create-namespace \
  --set tty=true \
  --set falco.grpc.enabled=true \
  --set falco.grpcOutput.enabled=true

# Verify installation
kubectl get pods -n falco-system
kubectl wait --for=condition=Ready pods --all -n falco-system --timeout=300s

# Check Falco is running
kubectl logs -l app.kubernetes.io/name=falco -n falco-system -c falco --tail=10
```

### Alternative: Install with custom configuration
```bash
# Create custom values file
cat > falco-values.yaml <<EOF
tty: true
falco:
  grpc:
    enabled: true
  grpcOutput:
    enabled: true
  fileOutput:
    enabled: true
    filename: "/var/log/falco.log"
  rules_file:
    - /etc/falco/falco_rules.yaml
    - /etc/falco/falco_rules.local.yaml
    - /etc/falco/k8s_audit_rules.yaml
    - /etc/falco/rules.d

customRules:
  rules-cks.yaml: |-
    - rule: CKS Suspicious Shell Access
      desc: Detect shell access in production containers
      condition: >
        spawned_process and container and
        (proc.name in (sh, bash, dash, zsh, fish)) and
        not container.image.repository contains "debug"
      output: >
        Shell spawned in container (user=%user.name container_id=%container.id
        container_name=%container.name image=%container.image.repository:%container.image.tag
        proc=%proc.cmdline)
      priority: WARNING
      tags: [container, shell, mitre_execution]

    - rule: CKS Sensitive File Access
      desc: Detect access to sensitive files
      condition: >
        open_read and container and
        (fd.name in (/etc/shadow, /etc/passwd, /etc/sudoers, /root/.ssh/id_rsa))
      output: >
        Sensitive file accessed in container (user=%user.name container_id=%container.id
        file=%fd.name proc=%proc.cmdline)
      priority: CRITICAL
      tags: [filesystem, sensitive]
EOF

# Install with custom rules
helm install falco falcosecurity/falco \
  --namespace falco-system \
  --create-namespace \
  -f falco-values.yaml
```

## Test Default Falco Rules

### Create Test Workload
```bash
# Create a test deployment
kubectl create deployment test-app --image=nginx:alpine

# Wait for pod to be ready
kubectl wait --for=condition=Ready pod -l app=test-app --timeout=60s

# Get pod name
TEST_POD=$(kubectl get pods -l app=test-app -o jsonpath='{.items[0].metadata.name}')
echo "Test pod: $TEST_POD"
```

### Trigger Security Alerts
{{%expand "Solution" %}}

```bash
# Terminal 1: Watch Falco logs in real-time
kubectl logs -l app.kubernetes.io/name=falco -n falco-system -c falco -f

# Terminal 2: Trigger various security violations

# 1. Trigger "Read sensitive file untrusted" rule
kubectl exec -it $TEST_POD -- cat /etc/shadow

# 2. Trigger "Shell in container" rule
kubectl exec -it $TEST_POD -- /bin/sh -c "whoami"

# 3. Trigger "Write below etc" rule
kubectl exec -it $TEST_POD -- /bin/sh -c "echo 'test' > /etc/test-file"

# 4. Trigger "Change thread namespace" rule
kubectl exec -it $TEST_POD -- /bin/sh -c "unshare -n /bin/sh"

# 5. Trigger "Set setuid or setgid bit" rule (might not work in all environments)
kubectl exec -it $TEST_POD -- /bin/sh -c "chmod +s /bin/ls" || echo "Expected to fail"

# Check logs for alerts
kubectl logs -l app.kubernetes.io/name=falco -n falco-system -c falco --tail=20 | grep -i warning
```

Expected output examples:
```
Warning Shell spawned in container (user=root container_id=abc123 container_name=test-app ...)
Warning Sensitive file opened for reading by non-trusted program (user=root file=/etc/shadow ...)
Warning File below /etc opened for writing (user=root file=/etc/test-file ...)
```

{{% /expand%}}

## Modify Falco Rules Directly

### Exercise 1: Edit Default Rules

Access the Falco pod and modify rules directly (without Helm):

{{%expand "Solution" %}}

```bash
# Get Falco pod name
FALCO_POD=$(kubectl get pods -n falco-system -l app.kubernetes.io/name=falco -o jsonpath='{.items[0].metadata.name}')

# Access Falco pod
kubectl exec -it $FALCO_POD -n falco-system -c falco -- /bin/bash

# Inside the pod, check existing rules
cat /etc/falco/falco_rules.yaml | grep -A5 -B5 "Shell in container"

# Check local rules file (this is where we add custom rules)
ls -la /etc/falco/

# Create or edit local rules file
cat > /etc/falco/falco_rules.local.yaml <<EOF
# Custom CKS Rules

- rule: CKS Unauthorized Package Manager
  desc: Detect unauthorized package manager usage in containers
  condition: >
    spawned_process and container and
    (proc.name in (apt, apt-get, yum, dnf, apk, pip, npm)) and
    not container.image.repository contains "build"
  output: >
    Package manager used in container (user=%user.name container=%container.name
    image=%container.image.repository proc=%proc.cmdline)
  priority: WARNING
  tags: [package_management, unauthorized]

- rule: CKS Network Tool Usage
  desc: Detect network reconnaissance tools
  condition: >
    spawned_process and container and
    (proc.name in (nmap, netcat, nc, telnet, wget, curl)) and
    not container.image.repository contains "debug"
  output: >
    Network tool executed in container (user=%user.name container=%container.name
    tool=%proc.name cmdline=%proc.cmdline)
  priority: INFO
  tags: [network, reconnaissance]

- rule: CKS Privilege Escalation Attempt
  desc: Detect potential privilege escalation
  condition: >
    spawned_process and container and
    (proc.name in (sudo, su, passwd)) and
    not user.name=root
  output: >
    Privilege escalation attempt (user=%user.name container=%container.name
    proc=%proc.name cmdline=%proc.cmdline)
  priority: CRITICAL
  tags: [privilege_escalation]

# Override default rule to be more specific
- rule: Shell in container
  desc: CKS Custom - A shell was used as the entrypoint/exec point into a container with an attached terminal.
  condition: >
    spawned_process and container
    and shell_procs and proc.tty != 0
    and container_entrypoint
    and not user_expected_terminal_shell_in_container_conditions
  output: >
    CKS Alert - Shell spawned in container with terminal (user=%user.name user_uid=%user.uid user_loginuid=%user.loginuid process=%proc.name proc_exepath=%proc.exepath parent=%proc.pname command=%proc.cmdline terminal=%proc.tty container_id=%container.id container_name=%container.name image=%container.image.repository:%container.image.tag)
  priority: NOTICE
  tags: [container, shell, mitre_execution, T1059.004]
  override:
    append: false
EOF

# Restart Falco to reload rules (exit the pod first)
exit

# Restart Falco pod to reload rules
kubectl delete pod $FALCO_POD -n falco-system

# Wait for new pod
kubectl wait --for=condition=Ready pods -l app.kubernetes.io/name=falco -n falco-system --timeout=120s

# Verify new rules are loaded
FALCO_POD=$(kubectl get pods -n falco-system -l app.kubernetes.io/name=falco -o jsonpath='{.items[0].metadata.name}')
kubectl logs $FALCO_POD -n falco-system -c falco | grep -i "loaded rules"
```

{{% /expand%}}

### Exercise 2: Test Custom Rules

Test the newly created custom rules:

{{%expand "Solution" %}}

```bash
# Monitor Falco logs
kubectl logs -l app.kubernetes.io/name=falco -n falco-system -c falco -f &

# Test unauthorized package manager rule
kubectl exec -it $TEST_POD -- apk --help

# Test network tool usage rule
kubectl exec -it $TEST_POD -- wget --help

# Test the modified shell rule
kubectl exec -it $TEST_POD -- /bin/sh

# In the shell, try some commands
whoami
ps aux
ls /etc/

# Exit the shell
exit

# Check for custom rule alerts
kubectl logs -l app.kubernetes.io/name=falco -n falco-system -c falco --tail=30 | grep -i "CKS"
```

{{% /expand%}}

## Advanced Falco Configuration

### Exercise 3: Configure Output Channels

Configure Falco to send alerts to different outputs:

{{%expand "Solution" %}}

```bash
# Access Falco pod
FALCO_POD=$(kubectl get pods -n falco-system -l app.kubernetes.io/name=falco -o jsonpath='{.items[0].metadata.name}')
kubectl exec -it $FALCO_POD -n falco-system -c falco -- /bin/bash

# Check current Falco configuration
cat /etc/falco/falco.yaml | grep -A10 -B5 "outputs:"

# Create custom output configuration
cat > /etc/falco/falco_custom_outputs.yaml <<EOF
# Custom outputs configuration

# File output
file_output:
  enabled: true
  keep_alive: false
  filename: /var/log/falco_events.log

# stdout output
stdout_output:
  enabled: true

# Program output (for external integration)
program_output:
  enabled: false
  keep_alive: false
  program: "curl -X POST https://webhook.site/your-webhook-url"

# HTTP output
http_output:
  enabled: false
  url: "http://falcosidekick:2801/"
  user_agent: "falco/0.33.1"

# Configure output format
json_output: true
json_include_output_property: true
json_include_tags_property: true

# Log level
log_level: info
EOF

# Modify main falco.yaml to include custom outputs
cp /etc/falco/falco.yaml /etc/falco/falco.yaml.backup
cat >> /etc/falco/falco.yaml <<EOF

# Include custom outputs
include: /etc/falco/falco_custom_outputs.yaml
EOF

# Exit and restart pod
exit

kubectl delete pod $FALCO_POD -n falco-system
kubectl wait --for=condition=Ready pods -l app.kubernetes.io/name=falco -n falco-system --timeout=120s

# Check if outputs are working
FALCO_POD=$(kubectl get pods -n falco-system -l app.kubernetes.io/name=falco -o jsonpath='{.items[0].metadata.name}')
kubectl exec -it $FALCO_POD -n falco-system -c falco -- tail -f /var/log/falco_events.log &

# Generate test event
kubectl exec -it $TEST_POD -- cat /etc/passwd

# Check custom log file
kubectl exec -it $FALCO_POD -n falco-system -c falco -- cat /var/log/falco_events.log | tail -5
```

{{% /expand%}}

### Exercise 4: Rule Tuning and Performance

Learn to tune rules for better performance and reduced false positives:

{{%expand "Solution" %}}

```bash
# Access Falco pod
FALCO_POD=$(kubectl get pods -n falco-system -l app.kubernetes.io/name=falco -o jsonpath='{.items[0].metadata.name}')
kubectl exec -it $FALCO_POD -n falco-system -c falco -- /bin/bash

# Create performance-tuned rules
cat > /etc/falco/falco_rules.performance.yaml <<EOF
# Performance-tuned custom rules

# Macro definitions for reusability
- macro: sensitive_mount_points
  condition: (fd.name startswith /proc or fd.name startswith /sys)

- macro: container_process
  condition: (container.id != host)

- macro: known_shell_binaries
  condition: (proc.name in (sh, bash, zsh, dash, fish))

- macro: system_users
  condition: (user.name in (root, daemon, nobody))

# List of trusted container images
- list: trusted_images
  items:
    - "nginx"
    - "alpine"
    - "busybox"
    - "registry.k8s.io"

# List of expected shells in debugging containers
- list: debug_images
  items:
    - "debug"
    - "troubleshoot"
    - "busybox"

# Efficient rule - avoid checking every process spawn
- rule: CKS Optimized Shell Detection
  desc: Efficiently detect shells in non-debug containers
  condition: >
    spawned_process and
    container_process and
    known_shell_binaries and
    proc.tty != 0 and
    not container.image.repository contains debug and
    not container.image.repository in (trusted_images)
  output: >
    Optimized shell detection (container=%container.name image=%container.image.repository
    user=%user.name proc=%proc.name tty=%proc.tty)
  priority: WARNING
  tags: [shell, optimized]

# Rule with exceptions to reduce false positives
- rule: CKS File Access with Exceptions
  desc: Detect sensitive file access with proper exceptions
  condition: >
    open_read and
    container_process and
    sensitive_mount_points and
    not proc.name in (ps, top, htop, cat, ls) and
    not system_users
  output: >
    Sensitive file system access (file=%fd.name proc=%proc.name user=%user.name
    container=%container.name)
  priority: INFO
  tags: [filesystem, tuned]

# Performance rule - limit syscall monitoring scope
- rule: CKS Network Connection Monitoring
  desc: Monitor network connections efficiently
  condition: >
    (inbound or outbound) and
    container_process and
    not fd.name contains "127.0.0.1" and
    not fd.name contains "localhost" and
    fd.net != "127.0.0.0/8"
  output: >
    Network activity (connection=%fd.name direction=%evt.type container=%container.name
    proc=%proc.name)
  priority: INFO
  tags: [network, monitoring]
  enabled: false  # Disable by default due to high volume

# Exception-based rule
- rule: CKS Package Manager with Business Exceptions
  desc: Package manager usage with business logic exceptions
  condition: >
    spawned_process and
    container_process and
    proc.name in (apt, yum, pip, npm) and
    not container.image.repository contains "builder" and
    not k8s.ns.name in (kube-system, falco-system, development)
  output: >
    Package manager usage in production (proc=%proc.name container=%container.name
    namespace=%k8s.ns.name image=%container.image.repository)
  priority: WARNING
  tags: [package_manager, production]
EOF

# Exit and restart to load new rules
exit

kubectl delete pod $FALCO_POD -n falco-system
kubectl wait --for=condition=Ready pods -l app.kubernetes.io/name=falco -n falco-system --timeout=120s

# Test performance rules
kubectl exec -it $TEST_POD -- /bin/sh -c "ps aux"
kubectl exec -it $TEST_POD -- cat /proc/version

# Check which rules triggered
FALCO_POD=$(kubectl get pods -n falco-system -l app.kubernetes.io/name=falco -o jsonpath='{.items[0].metadata.name}')
kubectl logs $FALCO_POD -n falco-system -c falco --tail=20 | grep "CKS"
```

{{% /expand%}}

## Rule Management and Debugging

### Exercise 5: Debug Falco Rules

Learn to debug and troubleshoot Falco rules:

{{%expand "Solution" %}}

```bash
# Check Falco configuration and rule loading
FALCO_POD=$(kubectl get pods -n falco-system -l app.kubernetes.io/name=falco -o jsonpath='{.items[0].metadata.name}')

# Check rule loading logs
kubectl logs $FALCO_POD -n falco-system -c falco | grep -i "rule\|loaded\|error"

# Access pod for rule validation
kubectl exec -it $FALCO_POD -n falco-system -c falco -- /bin/bash

# Validate rule syntax
falco --validate /etc/falco/falco_rules.local.yaml

# Test specific rules
falco --print_support

# Check rule compilation
falco -r /etc/falco/falco_rules.local.yaml --list

# Test rule with specific events
cat > /tmp/test_rule.yaml <<EOF
- rule: Test Rule Debug
  desc: Test rule for debugging
  condition: spawned_process and proc.name=cat
  output: "Test rule triggered (proc=%proc.name)"
  priority: INFO
EOF

# Validate test rule
falco --validate /tmp/test_rule.yaml

# List all loaded rules
falco --list

# Check for rule conflicts or issues
falco --list | grep -i "shell\|test"

# Exit pod
exit

# Generate events and monitor
kubectl exec -it $TEST_POD -- cat /etc/hostname
kubectl logs $FALCO_POD -n falco-system -c falco --tail=10
```

{{% /expand%}}

## Monitoring and Alerting Integration

### Exercise 6: Integrate with External Systems

Set up Falco to integrate with monitoring systems:

{{%expand "Solution" %}}

```bash
# Create a simple webhook receiver for testing
kubectl create deployment webhook-receiver --image=nginx:alpine

kubectl expose deployment webhook-receiver --port=80 --target-port=80

# Get webhook service IP
WEBHOOK_IP=$(kubectl get svc webhook-receiver -o jsonpath='{.spec.clusterIP}')

# Configure Falco for webhook integration
FALCO_POD=$(kubectl get pods -n falco-system -l app.kubernetes.io/name=falco -o jsonpath='{.items[0].metadata.name}')
kubectl exec -it $FALCO_POD -n falco-system -c falco -- /bin/bash

# Create webhook output configuration
cat > /etc/falco/webhook_config.yaml <<EOF
# Webhook integration configuration

http_output:
  enabled: true
  url: "http://$WEBHOOK_IP/falco-alerts"
  user_agent: "falco-cks/1.0"
  timeout: 5s

program_output:
  enabled: true
  keep_alive: false
  program: |
    #!/bin/bash
    # Simple alert processor
    while IFS= read -r alert; do
      echo "$(date): FALCO ALERT: $alert" >> /var/log/falco-alerts.log
      # Could send to Slack, PagerDuty, etc.
    done

json_output: true
json_include_output_property: true
json_include_tags_property: true

# Rule for critical alerts only
priority: WARNING
EOF

# Create alert processing script
cat > /usr/local/bin/falco-alert-processor.sh <<'EOF'
#!/bin/bash
LOGFILE="/var/log/falco-critical-alerts.log"
WEBHOOK_URL="http://webhook-receiver/critical"

while IFS= read -r line; do
    # Parse JSON alert
    PRIORITY=$(echo "$line" | jq -r '.priority // "INFO"')
    RULE=$(echo "$line" | jq -r '.rule // "Unknown"')
    OUTPUT=$(echo "$line" | jq -r '.output // "No output"')

    # Log all alerts
    echo "$(date -Iseconds): [$PRIORITY] $RULE - $OUTPUT" >> "$LOGFILE"

    # Send critical alerts to webhook
    if [[ "$PRIORITY" == "CRITICAL" ]]; then
        curl -s -X POST "$WEBHOOK_URL" \
          -H "Content-Type: application/json" \
          -d "$line" || echo "Failed to send webhook"
    fi
done
EOF

chmod +x /usr/local/bin/falco-alert-processor.sh

# Exit and restart Falco
exit

kubectl delete pod $FALCO_POD -n falco-system
kubectl wait --for=condition=Ready pods -l app.kubernetes.io/name=falco -n falco-system --timeout=120s

# Test integration
kubectl exec -it $TEST_POD -- cat /etc/shadow

# Check alerts
FALCO_POD=$(kubectl get pods -n falco-system -l app.kubernetes.io/name=falco -o jsonpath='{.items[0].metadata.name}')
kubectl exec -it $FALCO_POD -n falco-system -c falco -- cat /var/log/falco-alerts.log

# Clean up
kubectl delete deployment webhook-receiver
kubectl delete service webhook-receiver
```

{{% /expand%}}

## Cleanup and Best Practices

```bash
# Clean up test resources
kubectl delete deployment test-app

# Remove Falco (optional)
# helm uninstall falco -n falco-system
# kubectl delete namespace falco-system

# Show Falco rule management best practices
echo "Best Practices Summary:
1. Always validate rules before applying: falco --validate
2. Use macros and lists for reusable rule components
3. Include proper exception conditions to reduce false positives
4. Monitor rule performance and disable high-volume rules if needed
5. Use appropriate priority levels (INFO, WARNING, ERROR, CRITICAL)
6. Tag rules properly for filtering and organization
7. Test rules thoroughly before production deployment
8. Keep custom rules in separate files from default rules
9. Version control your custom rule configurations
10. Monitor Falco itself for performance and resource usage"
```

## Advanced Topics for CKS

### Rule Optimization Techniques
- **Macro usage**: Create reusable condition fragments
- **List definitions**: Maintain lists of trusted/untrusted entities
- **Exception patterns**: Properly handle false positives
- **Performance tuning**: Optimize rules for high-volume environments

### Production Considerations
- **Resource limits**: Configure appropriate CPU/memory limits for Falco
- **Output buffering**: Configure appropriate buffer sizes for high alert volumes
- **Rule versioning**: Maintain version control for custom rules
- **Testing strategy**: Implement proper testing for rule changes

### Integration Patterns
- **SIEM integration**: Send alerts to security information systems
- **Incident response**: Trigger automated responses to critical alerts
- **Compliance reporting**: Generate reports for security compliance
- **Metrics and dashboards**: Create monitoring dashboards for security events

## Troubleshooting

### Common Issues
```bash
# Falco not starting
kubectl describe pods -n falco-system -l app.kubernetes.io/name=falco

# Rule syntax errors
kubectl logs -n falco-system -l app.kubernetes.io/name=falco | grep -i error

# No events generated
# Check if Falco is monitoring the right kernel events
kubectl exec -it $(kubectl get pods -n falco-system -l app.kubernetes.io/name=falco -o name) -c falco -- falco --print_support

# Performance issues
kubectl top pods -n falco-system
```

### Kind-specific Notes
- Kind uses containerd, which may affect some system call monitoring
- Ensure proper privileges for Falco pods in kind environments
- Some advanced rules may not work in containerized control planes
- Test thoroughly before applying rules in production kind-based environments