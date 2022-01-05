#!/usr/bin/env bash
# bash <(curl -fsS https://raw.githubusercontent.com/gilzow/source-operations/main/test.sh) foobar
# bash <(curl -fsS https://raw.githubusercontent.com/gilzow/source-operations/main/setup.sh) autoprsourceop
# https://github.com/gilzow/source-operations.git

# Repo for our source ops support scripts
gitSourceOps="https://github.com/gilzow/source-operations.git"
# A writable location where we can store things
tmpDir="/tmp"
dirSourceOps="${tmpDir}/source-operations"

#check and see if we already have the repo cloned in /tmp
# we dont really care what the status us other than does it exist, hence the 2>/dev/null
git -C "${dirSourceOps}" status 2>/dev/null
gitCheck=$?

# we dont have the repo cloned so let's clone it
if (( 0 != gitCheck )) || [[ ! -d "${dirSourceOps}" ]]; then
  git -C "${tmpDir}" clone "${gitSourceOps}"
else
  # we have it so let's make sure we're up-to-date
  git -C "${dirSourceOps}" pull origin
fi

# Add our directory to PATH so we can call it
export PATH="${dirSourceOps}:${PATH}"

sourceOp "${1:-'nothing'}"
