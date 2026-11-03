---
title: 'Runtime Security with Falco'
date: 2024-06-06T16:00:00+10:00
draft: false
weight: 110
tags: ["CKS", "Falco", "Runtime", "Security"]
---

**Author:** Fabrice JAMMES ([LinkedIn](https://www.linkedin.com/in/fabrice-jammes-5b29b042/)).

## Objective
Use Falco to detect suspicious behaviors inside containers in real-time and learn to configure custom security rules for Kubernetes environments.

## Understanding Falco

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

## Prerequisites

Falco runs as a DaemonSet, with a rule set for the whole cluster: use a kind cluster of your own, never a shared one.

```bash
# On the CKS training server, use your own cluster ($CLUSTER_NAME),
# elsewhere create a cluster for the lab
CLUSTER=${CLUSTER_NAME:-falco-$(whoami)}
kind get clusters | grep -qx $CLUSTER || kind create cluster --name $CLUSTER
kind export kubeconfig --name $CLUSTER
mkdir -p $HOME/falco && cd $HOME/falco
```

<!-- ci-exec
# A new cluster: wait for the service account controller
until kubectl get serviceaccount default -n default >/dev/null 2>&1; do sleep 2; done
kubectl wait --for=condition=Ready node --all --timeout=180s
-->

## Install Falco

Install the Helm chart `falco` (version `9.2.0`) of the repository `https://falcosecurity.github.io/charts`, in the namespace `falco`, with `tty=true`: the alerts are written at once in the logs.

{{%expand "Solution" %}}
```bash
helm upgrade --install falco falco --repo https://falcosecurity.github.io/charts --version 9.2.0 \
  --namespace falco --create-namespace --set tty=true
kubectl rollout status daemonset/falco -n falco --timeout=300s
kubectl wait --for=condition=Ready pod -l app.kubernetes.io/name=falco -n falco --timeout=300s
kubectl logs -n falco daemonset/falco -c falco --tail=5
```
{{% /expand%}}

{{% notice note %}}
All the nodes of a kind cluster share the kernel of the server: the Falco pod of a node also sees the system calls of the other nodes, and of the other clusters of the server. These events have no Kubernetes metadata (`k8s_pod_name=<NA>`): filter them out.
{{% /notice %}}

Follow the alerts in a **second terminal**, during the whole lab:

<!-- ci-skip -->
```bash
kubectl logs -n falco -l app.kubernetes.io/name=falco -c falco -f --max-log-requests=10 | grep -v "k8s_pod_name=<NA>"
```

In the first terminal, this function displays the alerts of the last 2 minutes which match a pattern:

```bash
alerts() {
  sleep 5
  kubectl logs -n falco -l app.kubernetes.io/name=falco -c falco --since=2m --max-log-requests=10 \
    | grep -v "k8s_pod_name=<NA>" | grep -E "$1"
}
```

## Exercise 1: the default rules

Run a Deployment `test-app` (image `nginx:1.27-alpine`). In its pod, read `/etc/shadow`, then open a shell **with a terminal** (`kubectl exec -it`). Which alerts does Falco raise?

{{%expand "Solution" %}}
```bash
kubectl create deployment test-app --image=nginx:1.27-alpine
kubectl wait --for=condition=Available deployment/test-app --timeout=120s
TEST_POD=$(kubectl get pods -l app=test-app -o jsonpath='{.items[0].metadata.name}')

kubectl exec $TEST_POD -- cat /etc/shadow > /dev/null
kubectl exec -it $TEST_POD -- sh -c "whoami"
alerts "Sensitive file|shell was spawned"
# ... Warning Sensitive file opened for reading by non-trusted program | file=/etc/shadow ... k8s_pod_name=test-app-...
# ... Notice A shell was spawned in a container with an attached terminal | ... k8s_pod_name=test-app-...
```

The rule `Terminal shell in container` requires a terminal (`proc.tty != 0`): `kubectl exec` without `-t` raises no alert. An attacker with a reverse shell usually has no terminal: a rule is a compromise between noise and blind spots.
{{% /expand%}}

## Exercise 2: custom rules

Add two rules with the Helm value `customRules`:

- `CKS Network Tool Usage`, priority `WARNING`: a process `nmap`, `netcat`, `nc`, `telnet`, `wget` or `curl` is started. Output: `ALERT_CKS: Network tool detected (user=%user.name pod=%k8s.pod.name tool=%proc.name cmdline=%proc.cmdline)`
- `CKS Privilege Escalation Attempt`, priority `CRITICAL`: a process `sudo`, `su` or `passwd` is started. Output: `ALERT_CKS: Privilege escalation tool (user=%user.name pod=%k8s.pod.name proc=%proc.name)`

Then run a pod `test-attack` (image `nginx:1.27-alpine`), and run `curl` and `passwd` in it.

How to build them:

1. **The shape of a rule.** A rule is a YAML item with 5 keys:

    ```yaml
    - rule: <name>               # unique: the same name replaces a rule
      desc: <description>
      condition: <filter>        # when the alert is raised
      output: "<message>"        # %field is replaced by its value
      priority: WARNING          # EMERGENCY, ALERT, CRITICAL, ERROR, WARNING, NOTICE, INFO, DEBUG
    ```

2. **The condition.** A process is started by the system call `execve`: `evt.type = execve`. The name of the process is `proc.name`, and `in (a, b, c)` tests a list: `evt.type = execve and proc.name in (curl, wget)`.
3. **Where to put the rules.** Falco reads its rules from files, in its pods. The chart has a value for that, `customRules`: it writes its content in a ConfigMap, mounted in the Falco pods as `/etc/falco/rules.d/`, and Falco loads every file of this directory. The values of a chart, with their documentation, are listed by `helm show values`:

    ```bash
    helm show values falco --repo https://falcosecurity.github.io/charts --version 9.2.0 \
      | grep -B 1 -A 10 "^customRules:"
    # customRules: {}
    #   ...
    #   # rules-traefik.yaml: |-
    #   #   [ rule body ]
    ```

    `customRules` is a map: each key is a file name, its value is the content of the file, a list of rules. Write a values file `falco-cks-values.yaml`:

    ```yaml
    customRules:
      cks_rules.yaml: |-
        - rule: ...
    ```

    and apply it with `helm upgrade ... -f falco-cks-values.yaml`, with the same options as the installation.

Look at the default rules for examples: they are in `/etc/falco/falco_rules.yaml`, in the Falco pods (`kubectl exec -n falco daemonset/falco -c falco -- cat /etc/falco/falco_rules.yaml`).

{{% notice warning %}}
YAML does not allow tabulations: configure your editor to insert spaces (`:set expandtab` in vim).
{{% /notice %}}

{{%expand "Solution" %}}
```bash
cat << EOF > falco-cks-values.yaml
customRules:
  cks_rules.yaml: |-
    - rule: CKS Network Tool Usage
      desc: Detect network reconnaissance tools
      condition: >
        evt.type = execve and
        (proc.name in (nmap, netcat, nc, telnet, wget, curl))
      output: "ALERT_CKS: Network tool detected (user=%user.name pod=%k8s.pod.name tool=%proc.name cmdline=%proc.cmdline)"
      priority: WARNING
      tags: [network, reconnaissance]

    - rule: CKS Privilege Escalation Attempt
      desc: Detect potential privilege escalation
      condition: >
        evt.type = execve and
        (proc.name in (sudo, su, passwd))
      output: "ALERT_CKS: Privilege escalation tool (user=%user.name pod=%k8s.pod.name proc=%proc.name)"
      priority: CRITICAL
      tags: [privilege_escalation]
EOF
helm upgrade falco falco --repo https://falcosecurity.github.io/charts --version 9.2.0 \
  --namespace falco --set tty=true -f falco-cks-values.yaml
kubectl rollout status daemonset/falco -n falco --timeout=300s
kubectl wait --for=condition=Ready pod -l app.kubernetes.io/name=falco -n falco --timeout=300s
sleep 10

kubectl run test-attack --image=nginx:1.27-alpine
kubectl wait --for=condition=Ready pod/test-attack --timeout=120s
kubectl exec test-attack -- curl -s -m 5 -o /dev/null https://k8s-school.fr || true
kubectl exec test-attack -- passwd < /dev/null || true
alerts "ALERT_CKS"
# ... Warning ALERT_CKS: Network tool detected (user=root pod=test-attack tool=curl cmdline=curl -s -m 5 ...)
# ... Critical ALERT_CKS: Privilege escalation tool (user=root pod=test-attack proc=passwd)
```
{{% /expand%}}

## Exercise 3: change an existing rule

Falco loads its rule files one after the other, in the order of `rules_files` in `/etc/falco/falco.yaml`, and **the last definition of a rule wins**:

```bash
kubectl exec -n falco daemonset/falco -c falco -- grep -A 3 "rules_files:" /etc/falco/falco.yaml
# rules_files:
# - /etc/falco/falco_rules.yaml          <- 1. the default rules
# - /etc/falco/falco_rules.local.yaml    <- 2. the local overrides
# - /etc/falco/rules.d                   <- 3. every file of the directory, in alphabetical order
```

The chart writes each entry of `customRules` in `/etc/falco/rules.d/`, loaded last:

```bash
kubectl exec -n falco daemonset/falco -c falco -- ls /etc/falco/rules.d/
# cks_rules.yaml
```

When Falco reads `Terminal shell in container` in `cks_rules.yaml`, the default rule of the same name is already loaded: the new definition replaces it. This is by design: the default rules are never edited in place, or the next upgrade of Falco would erase the changes; they are overridden in a file read later. The same goes for the macros and the lists: redefining `shell_procs` in `rules.d/` changes every rule which uses it.

{{% notice tip %}}
In the exam, Falco is often installed on the node, not with Helm: edit `/etc/falco/falco_rules.local.yaml`, already in `rules_files` after `falco_rules.yaml`, then restart Falco (`systemctl restart falco`). On an unknown installation, `grep -A 3 rules_files /etc/falco/falco.yaml` gives the order.
{{% /notice %}}

Start from the default rule: display it with its condition and its output.

```bash
kubectl exec -n falco daemonset/falco -c falco -- \
  grep -A 20 -e "- rule: Terminal shell in container" /etc/falco/falco_rules.yaml
```

Change the default rule `Terminal shell in container`:

- it only raises an alert if `k8s.pod.name` is known (not `<NA>`)
- its output is `[CKS_UPDATE] Shell detected! pod=%k8s.pod.name image=%container.image.repository tty=%proc.tty`

Add it to `cks_rules.yaml`, in your `falco-cks-values.yaml`, then upgrade the release. Open a shell with a terminal in `test-attack`.

- [Overriding rules](https://falco.org/docs/concepts/rules/overriding/)
- [Supported fields](https://falco.org/docs/reference/rules/supported-fields/)

{{%expand "Solution" %}}
```bash
cat << EOF >> falco-cks-values.yaml

    - rule: Terminal shell in container
      desc: A shell was spawned in a container with an attached terminal
      condition: >
        spawned_process and container
        and shell_procs and proc.tty != 0
        and container.id != host
        and k8s.pod.name != "<NA>"
      output: "[CKS_UPDATE] Shell detected! pod=%k8s.pod.name image=%container.image.repository tty=%proc.tty"
      priority: WARNING
EOF
helm upgrade falco falco --repo https://falcosecurity.github.io/charts --version 9.2.0 \
  --namespace falco --set tty=true -f falco-cks-values.yaml
kubectl rollout status daemonset/falco -n falco --timeout=300s
kubectl wait --for=condition=Ready pod -l app.kubernetes.io/name=falco -n falco --timeout=300s
sleep 10

kubectl exec -it test-attack -- sh -c "whoami"
alerts "CKS_UPDATE"
# ... Warning [CKS_UPDATE] Shell detected! pod=test-attack image=docker.io/library/nginx tty=...
```

A rule defined again with the same name replaces the default one entirely: condition, output, priority, tags. This is why the solution repeats the whole default condition, and the required keys `desc` and `priority`. The copy no longer gets the updates of the next versions of the rule set.

To only change some keys of the default rule, use `override`:

```yaml
- rule: Terminal shell in container
  condition: and k8s.pod.name != "<NA>"
  output: "[CKS_UPDATE] Shell detected! pod=%k8s.pod.name image=%container.image.repository tty=%proc.tty"
  override:
    condition: append     # added at the end of the default condition
    output: replace       # the output is replaced
```

The rule keeps the default condition, with its future updates, and only gets the extra filter. In the exam, both work: the full replacement is the quickest to write, by copying the default rule from `falco_rules.yaml`.
{{% /expand%}}

## Troubleshooting

```bash
# The Falco pods and their events
kubectl describe pods -n falco -l app.kubernetes.io/name=falco | tail -20
# The loaded rules
kubectl exec -n falco daemonset/falco -c falco -- falco -L | grep -i -E "CKS|Terminal shell"
```

A rule with an error stops Falco at startup: the pods of the DaemonSet restart (`CrashLoopBackOff`), and their logs show the line of the error.

## Questions

1. Falco detects a shell in a container. What does it not do?
2. How do you send the alerts to a team, instead of the pod logs?

{{%expand "Answers" %}}
1. It does not block anything: Falco detects and alerts, after the action. To prevent, use seccomp, AppArmor, a read-only root filesystem, or a sandbox ([gVisor]({{% ref "/1_Labs/gvisor" %}})).
2. With [Falcosidekick](https://github.com/falcosecurity/falcosidekick) (`falcosidekick.enabled=true` in the chart), which sends them to Slack, a SIEM, Loki... and has a web UI (`falcosidekick.webui.enabled=true`).
{{% /expand%}}

## In the exam

Falco is usually already installed on the node, as a systemd service, not with Helm. The typical tasks:

1. **Read the alerts**: `journalctl -u falco` (or `/var/log/syslog`), and find the pod. Falco appends the container and Kubernetes fields to each alert (`append_output` with `suggested_output: true` in `/etc/falco/falco.yaml`): `container_id=... k8s_ns_name=... k8s_pod_name=...`. If only the container ID is there, `crictl ps --id <container_id>` on the node gives the pod.
2. **Change the output of a rule**, for example to a given format: copy the rule from `/etc/falco/falco_rules.yaml` to `/etc/falco/falco_rules.local.yaml`, read after it, change the `output`, then `systemctl restart falco`. Check the order with `grep -A 3 rules_files /etc/falco/falco.yaml`.
3. **Stop the suspicious workload**, the one found in step 1, as the task asks. A pod of a Deployment comes back when it is deleted: scale the Deployment to 0 (`kubectl scale deployment <name> -n <namespace> --replicas=0`).

Writing rules from scratch is rare. The Helm part of this lab (`customRules`, ConfigMap) is only the way to run Falco in kind.

## Clean up

```bash
kubectl delete pod test-attack
kubectl delete deployment test-app
helm uninstall falco -n falco
kubectl delete namespace falco
cd $HOME && rm -rf $HOME/falco
# Delete the cluster only if it was created for the lab
if [ -z "${CLUSTER_NAME:-}" ]; then kind delete cluster --name $CLUSTER; fi
```

The [falco.sh](https://github.com/k8s-school/k8s-advanced/blob/master/labs/5_runtime_security/falco.sh) script of the k8s-advanced repository runs the same scenario.
