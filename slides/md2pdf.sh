#!/bin/bash

set -euxo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

for file in "$DIR"/*.md; do
    marp "$file" --theme-set $DIR/custom-theme.css --pdf --allow-local-files
done

cp "$DIR"/*.pdf "$DIR/../../k8s-school-www/public/pdf"