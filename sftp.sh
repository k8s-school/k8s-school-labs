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
# Public URL of SERVER_DIR, used by the post-deploy verification below.
SITE_URL="https://k8s-school.fr/labs/k8s"
LOCAL_DIR="$DIR/public"
PDF_DIR="$LOCAL_DIR/pdf"
SLIDES_DIR="$DIR/slides"
STATIC_PDF_DIR="$DIR/static/pdf"

# Number of decks expected in static/pdf. Hugo builds public/pdf from it, so a
# checkout without them would publish a site whose slides all 404.
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
# Mirrored over SFTP with the operator's SSH key (run ssh-copy-id once).
#
# This replaced yafc, which silently lost files. yafc does not implement the
# 'fish' protocol the old script asked for -- it printed "don't know how to
# handle your 'fish' protocol, trying 'ftp' instead" and fell back to plain,
# unencrypted FTP. Worse, its recursive `put -rf <glob>` skipped entries without
# failing and still exited 0: on 2026-09-04 it dropped the whole css/ directory
# and pdf/.htpasswd (leaving every slide behind a 500) while reporting success.
#
# rsync would be the obvious answer but is impossible here: the OVH account has
# no remote shell (ssh <host> "id" returns nothing), and rsync needs to run a
# binary on the far end. lftp speaks SFTP and needs no remote shell.
#
# The old temporary-directory-then-swap dance is gone with it. It deleted the
# live site (rm -rf) before the replacement was known to be complete, which is
# exactly how a dropped transfer became a broken site.
# --delete is only safe if SERVER_DIR really is this site. www/labs/ next door
# holds a different, older site: mirroring onto an empty or mistyped SERVER_DIR
# would delete it. Refuse to run unless the target already looks like the k8s
# training site.
assert_target() {
    set +x
    if [ -z "$SERVER_DIR" ]; then
        >&2 echo "ERROR: SERVER_DIR is empty -- refusing to mirror with --delete."
        exit 1
    fi
    local listing
    listing=$(lftp -c "
        set sftp:connect-program 'ssh -a -x -o BatchMode=yes';
        open -u '$SERVER_USER,' sftp://$SERVER;
        cls $SERVER_DIR;
    ") || { >&2 echo "ERROR: cannot list $SERVER_DIR on the server."; exit 1; }
    if ! printf '%s' "$listing" | grep -q searchindex.en.js; then
        >&2 echo "ERROR: $SERVER_DIR does not look like the training site"
        >&2 echo "       (no searchindex.en.js). Refusing to mirror with --delete."
        exit 1
    fi
    set -x
}

upload() {
    # mirror -R walks public/ and transfers only what differs, so a redeploy
    # moves a few kilobytes instead of the 95 MB the whole site weighs -- of
    # which 82 MB are slides that almost never change.
    #
    # --delete makes this a true mirror: a file removed from public/ goes from
    # the server too. That is safe here because the preflight above refuses to
    # run on a checkout whose static/pdf is empty, which is the one case where
    # an incomplete public/ could wipe the slides.
    #
    # Dotfiles are included, so pdf/.htaccess and pdf/.htpasswd travel with the
    # rest; nothing needs to send them separately any more.
    lftp -c "
        set sftp:connect-program 'ssh -a -x -o BatchMode=yes';
        set net:max-retries 3;
        set net:timeout 20;
        set mirror:parallel-transfer-count 4;
        open -u '$SERVER_USER,' sftp://$SERVER;
        mirror -R --delete --verbose $LOCAL_DIR $SERVER_DIR;
    "
}

assert_target
upload

# --- Verify ------------------------------------------------------------------
# 'put -rf' skips files it fails to transfer without failing, and yafc exits 0
# either way, so the script used to report success on a half-uploaded site. On
# 2026-09-04 that silently dropped the whole css/ directory and three decks,
# including E_05, and the breakage was only noticed in the browser.
#
# Check every file over HTTP -- the same path a participant uses. pdf/ sits
# behind basic auth, hence the credentials.
verify() {
    # No tracing here: the pdf/ checks carry the htpasswd credentials on the
    # command line, and 500 traced curl calls would bury the result anyway.
    set +x
    local missing=0 checked=0 rel url code
    while IFS= read -r -d '' f; do
        rel=${f#"$LOCAL_DIR"/}
        # .htaccess/.htpasswd are served-but-hidden by Apache; skip them.
        case $rel in .htaccess|*/.htaccess|.htpasswd|*/.htpasswd) continue ;; esac
        url="$SITE_URL/$(printf '%s' "$rel" | sed 's/ /%20/g')"
        if [ "${rel%%/*}" = pdf ]; then
            code=$(curl -sS -u "$HTACCESS_USER:$HTACCESS_PASS" -o /dev/null -w '%{http_code}' -I "$url")
        else
            code=$(curl -sS -o /dev/null -w '%{http_code}' -I "$url")
        fi
        checked=$((checked + 1))
        if [ "$code" != 200 ]; then
            >&2 echo "MISSING ($code): $rel"
            missing=$((missing + 1))
        fi
    done < <(find "$LOCAL_DIR" -type f -print0)
    echo "Verified $checked files, $missing missing."
    return $((missing > 0))
}

if ! verify; then
    >&2 echo ""
    >&2 echo "ERROR: the deployed site is incomplete. The upload itself did not"
    >&2 echo "       fail, so this is not a dropped transfer: check the paths"
    >&2 echo "       listed above on the server before re-running."
    exit 1
fi
