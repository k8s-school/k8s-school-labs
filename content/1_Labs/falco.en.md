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

## Install Falco on Kubernetes

### Setup Falco
```bash
helm repo update

# Install Falco in its own namespace
# tty=true allow instant flush: as soon as an alert is generated, the line is "flushed" to the console.
helm install --replace falco --namespace falco --create-namespace \
  --set tty=true \
  --set falcosidekick.enabled=true \
  --set falcosidekick.webui.enabled=true \
  falcosecurity/falco
```

> **Note for Kind Users:** Since all nodes in a Kind cluster share the host's Linux kernel, a Falco instance on one node may "hear" system calls from a pod running on another node. This leads to duplicate alerts where some entries show `<NA>` for Kubernetes metadata.

### Verify installation

{{%expand "Answer" %}}
```bash
kubectl get pods -n falco
kubectl wait --for=condition=Ready pods --all -n falco --timeout=300s
# Check Falco is running
kubectl logs -l app.kubernetes.io/name=falco -n falco -c falco --tail=10
```
{{% /expand%}}

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
# ### 💡 Pro-tip: Cleaning the output
# Since we are in a Kind environment, you will see background noise from the infrastructure.
# To focus only on relevant security events, use `grep` to filter out empty metadata and infrastructure processes:
kubectl logs -l app.kubernetes.io/name=falco -n falco -c falco -f | grep "k8s_pod_name=<NA>"

# Terminal 2: Trigger various security violations

# 1. Trigger "Read sensitive file untrusted" rule
kubectl exec -it $TEST_POD -- cat /etc/shadow

# 2. Trigger "Shell in container" rule
kubectl exec -it $TEST_POD -- /bin/sh -c "whoami"

# 3. Trigger "Executing binary not part of base image" rule
kubectl exec -it $TEST_POD -- chmod +s /bin/ls || echo "Expected to fail"

# Check logs for alerts on given levels: Notice|Warning|Critical|Error
kubectl logs -l app.kubernetes.io/name=falco -n falco -c falco --tail=20 | grep "k8s_pod_name=<NA>" | grep -E "Error"
```

Expected output examples:
```
Warning Sensitive file opened for reading by non-trusted program
Notice A shell was spawned in a container with an attached terminal
```

{{% /expand%}}

## Modify Falco Rules Directly

> **⚠️ Indentation Warning:** YAML does not allow tab characters. Ensure your editor (VS Code, Vim, Nano) is configured to **"Expand Tabs"** (use 2 or 4 spaces). In Vim, you can run `:set expandtab`.

### Setting up CKS Rules

We will start by injecting baseline detection rules for network reconnaissance and privilege escalation.

#### Create the configuration file

Create a file named `falco-cks-values.yaml` on your host machine:

```bash
cat << EOF > falco-cks-values.yaml
# Configuration for Falco CKS Lab
customRules:
  cks_rules.yaml: |-
    # 1. Rule for Network Tools
    - rule: CKS Network Tool Usage
      desc: Detect network reconnaissance tools
      # Simple and robust condition for lab environments
      condition: >
        evt.type = execve and
        (proc.name in (nmap, netcat, nc, telnet, wget, curl))
      output: "ALERT_CKS: Network tool detected (user=%user.name pod=%k8s.pod.name tool=%proc.name cmdline=%proc.cmdline)"
      priority: WARNING
      tags: [network, reconnaissance]

    # 2. Rule for Privilege Escalation
    - rule: CKS Privilege Escalation Attempt
      desc: Detect potential privilege escalation
      # Note: 'passwd' is used here for testing even if run by root
      condition: >
        evt.type = execve and
        (proc.name in (sudo, su, passwd))
      output: "ALERT_CKS: Privilege escalation tool (user=%user.name pod=%k8s.pod.name proc=%proc.name)"
      priority: CRITICAL
      tags: [privilege_escalation]
EOF
```

#### Apply with Helm

Run the following command to update Falco:

```bash
helm upgrade falco falcosecurity/falco --namespace falco \
  --set tty=true \
  --set falcosidekick.enabled=true \
  --set falcosidekick.webui.enabled=true \
  -f falco-cks-values.yaml

# Wait for falco to restart
kubectl wait --for=condition=Ready pods --all -n falco --timeout=300s
```

---

## Triggering Alerts


**Your Task:**

1. Launch a test pod: `kubectl run test-attack --image=nginx:alpine`
2. Trigger the network detection: `kubectl exec test-attack -- curl google.com`
3. Open a terminal to monitor Falco logs. Observe the logs appearing in your monitoring terminal.


{{%expand "Solution" %}}
```bash

# Monitor logs cleanly in terminal 1
kubectl logs -l app.kubernetes.io/name=falco -n falco -c falco -f | grep -v "k8s_pod_name=<NA>"

# In terminal 2

# 1. Launch a test pod
kubectl run test-attack --image=nginx:alpine

# 2. Trigger the network detection rule
kubectl exec test-attack -- curl google.com

# 3. Trigger the privilege escalation rule
kubectl exec test-attack -- passwd
```

{{% /expand%}}
---

## Modifying an Existing Rule

The goal is to enrich the default `Terminal shell in container` rule to include Kubernetes metadata and filter out empty events.

### Instructions

Update your `falco-cks-values.yaml` file to append logic to the shell rule.

- **Goal 1:** Only trigger the alert if `k8s.pod.name` is known (not equal to `<NA>`). (`kind` specific)
- **Goal 2:** Append the Pod name and the container image repository to the output message.

> 💡 **Useful Resources:**
>
> - [Doc: Override existing rules)](https://falco.org/docs/concepts/rules/overriding/#overview)
> - [Doc: Supported Fields (k8s.pod.name, container.image.repository...)](https://falco.org/docs/rules/supported-fields/)
>
>

{{%expand "Solution" %}}

```bash

# Edit local rule file
cat << EOF >> falco-cks-values.yaml
    - rule: Terminal shell in container
      desc: A shell was spawned in a container with an attached terminal
      condition: >
        spawned_process and container
        and shell_procs and proc.tty != 0
        and container.id != host
      output: "[CKS_UPDATE] Shell detected! pod=%k8s.pod.name image=%container.image.repository tty=%proc.tty"
      priority: WARNING
EOF

# Apply the changes
helm upgrade falco falcosecurity/falco --namespace falco \
  --set tty=true \
  --set falcosidekick.enabled=true \
  --set falcosidekick.webui.enabled=true \
  -f falco-cks-values.yaml


# Wait for falco to restart
kubectl wait --for=condition=Ready pods --all -n falco --timeout=300s
```

{{% /expand%}}

---

## 4. Final Test: Shell Validation

Run the following command to validate your custom rule:

```bash
kubectl exec -it test-attack -- sh
```

**Expected Result:**
The alert should now display with the enriched suffix: `... | pod=test-attack image=nginx`.

## Falco UI

```bash
kubectl port-forward svc/falco-falcosidekick-ui 2802:2802 -n falco
```

## Best Practices


1. Always validate rules before applying: falco --validate
2. Use macros and lists for reusable rule components
3. Use appropriate priority levels (INFO, WARNING, ERROR, CRITICAL)
4. Tag rules properly for filtering and organization
5. Test rules thoroughly before production deployment
6. Keep custom rules in separate files from default rules
7. Version control your custom rule configurations
8. Monitor Falco itself for performance and resource usage"


## Troubleshooting

### Common Issues

```bash

# Falco not starting
kubectl describe pods -n falco -l app.kubernetes.io/name=falco

# Rule syntax errors
kubectl logs -n falco -l app.kubernetes.io/name=falco | grep -i error

# No events generated
# Check if Falco is monitoring the right kernel events
kubectl exec -it $(kubectl get pods -n falco -l app.kubernetes.io/name=falco -o name) -c falco -- falco --print_support

# Performance issues (require metrics-server installed: https://github.com/kubernetes-sigs/metrics-server)
kubectl top pods -n falco
```

### Debug and troubleshoot Falco rules

```bash
# Check Falco configuration and rule loading
FALCO_POD=$(kubectl get pods -n falco -l app.kubernetes.io/name=falco -o jsonpath='{.items[0].metadata.name}')

# Access pod for rule validation
kubectl exec -it $FALCO_POD -n falco -c falco -- /bin/bash

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
```
