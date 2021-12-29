#!/usr/bin/env bash

#source our common functions
. "common.sh"

function createPR() {
  #can't interact with github w/o a token
  ghToken=$(getGHToken) || exit $?
  # we should already have this given we needed it to run source ops, but let's double check
  (checkForPSHToken) || exit $?
  # same for this but let's make sure
  ensureCliIsInstalled

}

function getGHToken() {
  if [[ -z ${GITHUB_TOKEN+x} ]]; then
    event="Github Token missing!"
    message="I was unable to locate a github token. Without it, I am unable to create a Pull Request for the recent"
    message="${message} update. Please create an environmental variable named 'GITHUB_TOKEN' with a valid token. "
    logFatalError "${event}" "${message}"
    exit 1
  fi
}