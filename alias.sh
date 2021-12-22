#!/usr/bin/env bash
# where are we, the long form ?
dirName="$( cd -- "$( dirname -- "$0" )" > /dev/null && pwd -P)"
# This assumes that main.py is in the same directory as this alias script
sourceOp() {
  python "${dirName}/main.py" "$@"
}