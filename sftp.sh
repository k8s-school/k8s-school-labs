#!/bin/bash

set -e
set -x

DIR=$(cd "$(dirname "$0")"; pwd -P)

SERVER_DIR="www/labs"
LOCAL_DIR="$DIR/public"

. "$DIR/env-creds.sh"

#yafc fish://"$SERVER_USER"@"$SERVER"

yafc  <<**
open fish://"$SERVER_USER":$SERVER_PASS@"$SERVER"
mkdir "$SERVER_DIR"
cd "$SERVER_DIR"
rm -rf *
put -rf $LOCAL_DIR/*
close
**

curl "http://www.google.com/ping?sitemap=https://www.k8s-school.fr/resources/sitemap.xml"
