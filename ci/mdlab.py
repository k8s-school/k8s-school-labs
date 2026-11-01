#!/usr/bin/env python3
"""Extract the shell commands of a lab page and run them, to test the page itself.

The page is the test: the ```bash blocks are run in order, in one bash
process, with `set -euo pipefail`. Solutions inside {{% expand %}} are run
too. Two HTML comments, invisible on the site, adapt a page to a test run:

    <!-- ci-skip -->
    ```bash
    docker exec -it node bash     # an interactive block: not run
    ```

    <!-- ci-exec
    # commands run by the test only, e.g. the non-interactive version
    # of an edit the page asks to do with vi, or a wait
    sed -i ... /etc/kubernetes/manifests/kube-scheduler.yaml
    -->

A third one runs the next block on the nodes of a kubeadm cluster, over ssh,
for the pages where the trainee works on their own VMs (kubeadm labs):

    <!-- ci-host: all -->        (or master, or worker)
    ```bash
    sudo apt-get install -y containerd.io
    ```

The page itself defines $MASTER and $WORKER, the ssh names of the nodes, in a
block run locally. Each remote block runs in a bash of its own, on every node
it names at the same time, with ssh keepalives: a connection which dies fails
the block instead of hanging it. MDLAB_SSH overrides the ssh command, e.g.
MDLAB_SSH="ssh -F my_ssh_config". A ci-exec block runs a remote block itself
with the mdlab_remote function: echo 'kubeadm version' | mdlab_remote master

Usage:
    ci/mdlab.py extract <page.md>     print the script
    ci/mdlab.py run [-x] <page.md>    run it (-x: trace the commands)
"""
import argparse
import os
import re
import subprocess
import sys
import tempfile

FENCE = re.compile(r"^(\s*)```(\S*)\s*$")
SKIP = "<!-- ci-skip -->"
EXEC_START = "<!-- ci-exec"
EXEC_END = "-->"
HOST = re.compile(r"^<!-- ci-host: (all|master|worker) -->$")

# Shell function of the generated script which runs its stdin on the nodes
REMOTE = r'''
# Run stdin on the nodes of a kubeadm cluster: mdlab_remote all|master|worker
mdlab_remote() {
  local role=$1 code hosts h pids=() rc=0 ssh_cmd
  code=$(cat)
  ssh_cmd="${MDLAB_SSH:-ssh} -o ServerAliveInterval=15 -o ServerAliveCountMax=8"
  case $role in
    master) hosts=$MASTER ;;
    worker) hosts=$WORKER ;;
    all) hosts="$MASTER $WORKER" ;;
  esac
  for h in $hosts; do
    if [ "$role" = all ]; then
      printf '%s\n' "$MDLAB_REMOTE_PRELUDE" "$code" \
        | $ssh_cmd -T "$h" bash -s 2>&1 | sed -u "s/^/[$h] /" &
    else
      printf '%s\n' "$MDLAB_REMOTE_PRELUDE" "$code" | $ssh_cmd -T "$h" bash -s &
    fi
    pids+=($!)
  done
  for h in "${pids[@]}"; do
    wait "$h" || rc=1
  done
  return $rc
}
'''


def extract(path):
    """Return the list of (line number, host, code) blocks to run, in page order.

    host is None for a block run locally, else all, master or worker.
    """
    blocks = []
    lines = open(path, encoding="utf-8").read().splitlines()
    i = 0
    skip_next = False
    host_next = None
    while i < len(lines):
        line = lines[i]
        stripped = line.strip()
        if stripped == SKIP:
            skip_next = True
        elif HOST.match(stripped):
            host_next = HOST.match(stripped).group(1)
        elif stripped.startswith(EXEC_START):
            start = i + 1
            body = [stripped[len(EXEC_START):]] if stripped != EXEC_START else []
            i += 1
            while i < len(lines) and lines[i].strip() != EXEC_END:
                body.append(lines[i])
                i += 1
            blocks.append((start, None, "\n".join(body)))
        else:
            m = FENCE.match(line)
            if m:
                indent, lang = m.group(1), m.group(2)
                start = i + 1
                body = []
                i += 1
                while i < len(lines) and not FENCE.match(lines[i]):
                    # Blocks indented in a list: remove the indentation
                    body.append(lines[i][len(indent):] if lines[i].startswith(indent) else lines[i])
                    i += 1
                if lang == "bash" and not skip_next:
                    blocks.append((start + 1, host_next, "\n".join(body)))
                skip_next = False
                host_next = None
            elif stripped:
                skip_next = skip_next and stripped.startswith("{{")
                host_next = host_next if stripped.startswith("{{") else None
        i += 1
    return blocks


def script(path, trace):
    out = ["#!/bin/bash", f"# Extracted from {path} by ci/mdlab.py", "set -euo pipefail"]
    blocks = extract(path)
    if any(host for _, host, _ in blocks):
        # apt-get must not wait for an answer (needrestart on Ubuntu)
        prelude = "set -euo pipefail\nexport DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a"
        if trace:
            prelude += "\nset -x"
        out.append(f"MDLAB_REMOTE_PRELUDE='{prelude}'")
        out.append(REMOTE)
    if trace:
        out.append("set -x")
    for lineno, host, code in blocks:
        name = os.path.basename(path)
        if host:
            out.append(f"\n# --- {name}:{lineno} (on {host})")
            out.append(f"mdlab_remote {host} <<'MDLAB_EOF'\n{code}\nMDLAB_EOF")
        else:
            out.append(f"\n# --- {name}:{lineno}")
            out.append(code)
    return "\n".join(out) + "\n"


def run(path, trace):
    with tempfile.NamedTemporaryFile("w", suffix=".sh", delete=False) as f:
        f.write(script(path, trace))
    try:
        if sys.stdin.isatty():
            cmd = ["bash", f.name]
        else:
            # Some commands need a terminal (docker exec -it, kubectl exec -it):
            # give them one in CI, where stdin is not a terminal
            cmd = ["script", "-qefc", f"bash {f.name}", "/dev/null"]
        return subprocess.call(cmd)
    finally:
        os.unlink(f.name)


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("action", choices=["extract", "run"])
    parser.add_argument("-x", "--trace", action="store_true", help="trace the commands (set -x)")
    parser.add_argument("page")
    args = parser.parse_args()
    if args.action == "extract":
        sys.stdout.write(script(args.page, args.trace))
        return 0
    return run(args.page, args.trace)


if __name__ == "__main__":
    sys.exit(main())
