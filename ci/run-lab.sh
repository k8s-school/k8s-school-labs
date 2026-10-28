#!/bin/bash

# Run the shell commands of lab pages, to test them (see ci/mdlab.py)

set -euo pipefail

DIR=$(cd "$(dirname "$0")"; pwd -P)
LABS="$DIR/../content/1_Labs"

usage() {
  cat << EOD

Usage: $(basename "$0") [options] <lab>...

  Run the shell commands of the lab pages, e.g. 'gvisor' for
  content/1_Labs/gvisor.en.md. Do not run two labs at the same time: they
  change the current context of ~/.kube/config (kubectx).

  Available options:
    -h         this message
    -e         only print the extracted script
    -c         run all the labs of the CKS training (content/Trainings/cks.en.md)
    -k         keep going after a failed lab

EOD
}

EXTRACT=false
CKS=false
KEEP_GOING=false

while getopts heck c ; do
    case $c in
        h) usage ; exit 0 ;;
        e) EXTRACT=true ;;
        c) CKS=true ;;
        k) KEEP_GOING=true ;;
        \?) usage ; exit 2 ;;
    esac
done
shift $((OPTIND - 1))

labs=("$@")
if [ "$CKS" = true ]; then
    mapfile -t labs < <(grep -o 'ref "/1_Labs/[a-z0-9-]*"' "$DIR/../content/Trainings/cks.en.md" \
        | sed 's|ref "/1_Labs/||; s|"||' | awk '!seen[$0]++')
fi
if [ ${#labs[@]} -eq 0 ]; then
    usage
    exit 2
fi

failed=()
for lab in "${labs[@]}"; do
    page="$LABS/${lab%.en.md}.en.md"
    if [ ! -f "$page" ]; then
        echo "ERROR: no page $page"
        exit 2
    fi
    if [ "$EXTRACT" = true ]; then
        "$DIR/mdlab.py" extract "$page"
        continue
    fi
    echo "=== Run lab $lab"
    if "$DIR/mdlab.py" run -x "$page"; then
        echo "=== Lab $lab: OK"
    else
        echo "=== Lab $lab: FAILED"
        failed+=("$lab")
        [ "$KEEP_GOING" = true ] || exit 1
    fi
done

if [ ${#failed[@]} -ne 0 ]; then
    echo "Failed labs: ${failed[*]}"
    exit 1
fi
