#!/usr/bin/env bash
# where are we, the long form ?
# @todo I give up trying to figure out how to get dash to give me the full path to where
# this file is located. I'll hard-code it for now and come back to it later
dirName="${PLATFORM_SOURCE_DIR}/source-operations"
# This assumes that main.py is in the same directory as this alias script
sourceOp() {
  python "${dirName}/main.py" "$@"
}