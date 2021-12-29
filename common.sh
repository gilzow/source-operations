#!/usr/bin/env bash

# Outputs the event and error message that was encountered during the process
# Do NOT include a final period (.) at the end of your message. I'll do that for ya.
# @todo For now this just echos an error message, but might expand to include slack notices?
# @return void
function logFatalError() {
  event="${1:-no event specificied}"
  message="${2:-no message provided}"
  printf "\nFatal error encountered during %s\n%s\n" "${event}" "${message}. Exiting."
}

# ensures we have the token to use the psh cli tool
# @return bool
function checkForPSHToken() {
  if [[ -z ${PLATFORMSH_CLI_TOKEN+x} ]]; then
    message="You will need to create an environmental variable 'PLATFORMSH_CLI_TOKEN' that contains a valid platform.sh"
    message="${message} token before I can run platform.sh cli commands"
    logFatalError "PSH Token Check" "${message}"
    exit 1
  fi
}

# Ensures the psh cli tool is installed and available
# @return bool exit status
function ensureCliIsInstalled() {
    which platform
    result=$?

    if (( 0 != result )); then
      event="Checking for the Platform.sh CLI tool"
      message="The Platform.sh CLI tool is not installed. Please add its installation to the build section of your"
      message="${message} .platform.app.yaml. See https://github.com/platformsh/platformsh-cli#installation for more"
      message="${message} information"
      logFatalError "${event}" "${message}"
      exit 1
    else
      printf "The Platform.sh CLI tool is installed.\n"
    fi
}