#!/bin/bash

# Publish the Kubernetes training site to https://k8s-school.fr/labs/k8s
#
# Slides are served from pdf/ behind basic auth and come from two places:
#   - static/pdf/    course decks with no markdown source. NOT in git (too
#                    heavy): they live on the trainer's machine only, which is
#                    why this script must be run locally, never from CI.
#   - slides/*.pdf   decks built from slides/*.md by md2pdf.sh
# Hugo copies the former into public/pdf, this script adds the latter.

set -e
set -x

DIR=$(cd "$(dirname "$0")"; pwd -P)

SERVER_DIR="www/labs/k8s"
SERVER_TMP_DIR="tmp-k8s"
LOCAL_DIR="$DIR/public"
PDF_DIR="$LOCAL_DIR/pdf"
SLIDES_DIR="$DIR/slides"
STATIC_PDF_DIR="$DIR/static/pdf"

# Number of decks expected in static/pdf. The deployment replaces the remote
# site wholesale, so publishing without them would wipe the slides online.
MIN_STATIC_PDF=50

. "$DIR/env-creds.sh"

# --- Preflight --------------------------------------------------------------
# Guards against a run from a fresh checkout (CI, another machine), where
# static/pdf is empty because it is gitignored.
STATIC_PDF_COUNT=$(ls -1 "$STATIC_PDF_DIR"/*.pdf 2>/dev/null | wc -l)
if [ "$STATIC_PDF_COUNT" -lt "$MIN_STATIC_PDF" ]; then
    >&2 echo "ERROR: only $STATIC_PDF_COUNT PDF found in static/pdf, expected at least $MIN_STATIC_PDF."
    >&2 echo "       These decks are not in git: run this script from the machine"
    >&2 echo "       holding them, or the slides would be wiped from the website."
    exit 1
fi

if [ -z "$HTACCESS_USER" ]; then
    >&2 echo "ERROR: undefined HTACCESS_USER in env-creds.sh"
    exit 1
fi

# --- Build ------------------------------------------------------------------
hugo --minify

# Decks built from markdown join the ones Hugo copied from static/pdf
if ! ls "$SLIDES_DIR"/*.pdf > /dev/null 2>&1; then
    >&2 echo "ERROR: no slide PDF found, run slides/md2pdf.sh first"
    exit 1
fi
cp "$SLIDES_DIR"/*.pdf "$PDF_DIR"

# Password protection for pdf/
sed "s/<LOGIN>/$SERVER_USER/g" "$DIR/deploy/pdf.htaccess" > "$PDF_DIR/.htaccess"
htpasswd -bc "$PDF_DIR/.htpasswd" "$HTACCESS_USER" "$HTACCESS_PASS"

# --- Deploy -----------------------------------------------------------------
# Uploaded to a temporary directory then moved into place, so the live site is
# never left half-updated.
yafc <<**
open fish://"$SERVER_USER":$SERVER_PASS@"$SERVER"
mkdir "$SERVER_TMP_DIR"
cd "$SERVER_TMP_DIR"
put -rf $LOCAL_DIR/*
cd pdf
put -f $PDF_DIR/.htaccess
put -f $PDF_DIR/.htpasswd
cd
rm -rf "$SERVER_DIR"
mv "$SERVER_TMP_DIR" "$SERVER_DIR"
close
**
