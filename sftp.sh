#!/bin/bash

set -e
set -x

DIR=$(cd "$(dirname "$0")"; pwd -P)

SERVER_DIR="www/resources"
LOCAL_DIR="$DIR/public"

"$DIR"/content/01-CKAD_Exercices/generate.sh

rm -rf "$LOCAL_DIR/*"
hugo

. "$DIR/env-creds.sh"

#yafc fish://"$SERVER_USER"@"$SERVER"

yafc  <<**
open fish://"$SERVER_USER":$SERVER_PASS@"$SERVER"
mkdir "$SERVER_DIR"
cd "$SERVER_DIR"
# rm -rf *
put -rf $LOCAL_DIR/*
close
**
