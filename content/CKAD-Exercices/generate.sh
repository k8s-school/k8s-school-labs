#!/bin/bash

# Generate pages from https://github.com/dgkanatsios/CKAD-exercises.git

set -euxo pipefail

DATE=$(date '+%Y%m%d')
DIR=$(cd "$(dirname "$0")"; pwd -P)

HEADER_TPL="$DIR/header.tpl"

HEADER_TMP="/tmp/header.tmp"

FILES=$(find . -type f -name '[a-z]\.*.md' -print)

GIT_CKAD="/tmp/CKAD-exercises"
if [ ! -d "$GIT_CKAD" ]
then
    git clone https://github.com/dgkanatsios/CKAD-exercises.git  "$GIT_CKAD"
else
    cd "$GIT_CKAD"
    git pull
fi

FILES=$(find "$GIT_CKAD" -type f -name '[a-z]\.*.md' -print)

for f in $FILES
do
  TITLE=$(grep "^# " "$f" | head -n 1 | sed "s/^# //")
  sed "s/<TITLE>/$TITLE/" "$HEADER_TPL" | sed "s/<DATE>/$DATE/" > $HEADER_TMP
  filename=$(basename -- "$f")
  filename="${filename%.*}"
  MD_FILE="$DIR/${filename}.en.md"
  cat "$HEADER_TMP" "$f" > "$MD_FILE"
  echo "$MD_FILE generated"
done

