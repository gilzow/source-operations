#!/usr/bin/env bash
# where are we ?
dirName=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
# This assumes that main.py is in the same directory as this alias script
function sourceOp() {
  python "${dirName}/main.py" "$@"
}