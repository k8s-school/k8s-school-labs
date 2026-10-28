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


def extract(path):
    """Return the list of (line number, code) blocks to run, in page order."""
    blocks = []
    lines = open(path, encoding="utf-8").read().splitlines()
    i = 0
    skip_next = False
    while i < len(lines):
        line = lines[i]
        stripped = line.strip()
        if stripped == SKIP:
            skip_next = True
        elif stripped.startswith(EXEC_START):
            start = i + 1
            body = [stripped[len(EXEC_START):]] if stripped != EXEC_START else []
            i += 1
            while i < len(lines) and lines[i].strip() != EXEC_END:
                body.append(lines[i])
                i += 1
            blocks.append((start, "\n".join(body)))
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
                    blocks.append((start + 1, "\n".join(body)))
                skip_next = False
            elif stripped:
                skip_next = skip_next and stripped.startswith("{{")
        i += 1
    return blocks


def script(path, trace):
    out = ["#!/bin/bash", f"# Extracted from {path} by ci/mdlab.py", "set -euo pipefail"]
    if trace:
        out.append("set -x")
    for lineno, code in extract(path):
        out.append(f"\n# --- {os.path.basename(path)}:{lineno}")
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
