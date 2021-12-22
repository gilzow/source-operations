#!/usr/bin/env bash
# where are we, the long form ?
dirName=="${BASH_SOURCE%/*}"
if [[ ! -d "${dirName}" ]]; then dirName="$PWD"; fi
echo "dirName is ${dirName}"
# This assumes that main.py is in the same directory as this alias script
sourceOp() {
  python "${dirName}/main.py" "$@"
}