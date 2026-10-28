#!/bin/bash

# Build all slide decks to PDF with marp.
# The PDFs stay in this directory; sftp.sh uploads them into the site's pdf/.

set -euxo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Use a locally installed marp when available, fall back to npx so that CI
# runners need no extra setup step.
if command -v marp > /dev/null; then
    MARP=(marp)
else
    MARP=(npx --yes @marp-team/marp-cli@latest)
fi

for file in "$DIR"/*.md; do
    "${MARP[@]}" "$file" --config-file "$DIR/marp.config.yml" --theme-set "$DIR/custom-theme.css" --pdf --allow-local-files --no-stdin
done
