#!/bin/bash

set -e
set -x

DIR=$(cd "$(dirname "$0")"; pwd -P)

SERVER_DIR="www/labs"
SERVER_TMP_DIR="tmp"
LOCAL_DIR="$DIR/public"

. "$DIR/env-creds.sh"

#yafc fish://"$SERVER_USER"@"$SERVER"

yafc  <<**
open fish://"$SERVER_USER":$SERVER_PASS@"$SERVER"
pwd
ls
mkdir "$SERVER_DIR"
mkdir "$SERVER_TMP_DIR"
cd "$SERVER_TMP_DIR"
put -rf $LOCAL_DIR/*
cd
rm -rf "$SERVER_DIR"
mv "$SERVER_TMP_DIR" "$SERVER_DIR"
close
**

curl "http://www.google.com/ping?sitemap=https://www.k8s-school.fr/resources/sitemap.xml"
