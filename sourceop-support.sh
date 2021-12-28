#!/usr/bin/env bash
# we can probably get rid of this one
function trigger_source_op() {
    ENV="$1"
    SOURCEOP="$2"

    (checkForPSHToken) || exit $?
    (ensureCliIsInstalled) || exit $?
    productionBranch=$(getProductionBranchName) || exit $?
    updateBranch=$(getUpdateBranchName) # we have a default so need to exit on this step
    sourceOpName=$(getSourceOpName) # same, we have a default
    (createOrSyncUpdateBranch "${updateBranch}" "${productionBranch}") || exit $?
    runSourceOperation "${sourceOpName}" "${updateBranch}"


    waitUntilEnvIsReady "$ENV"
    test_urls "$ENV"
    merge "$ENV"

}

# ensures we have the token to use the psh cli tool
function checkForPSHToken() {
  if [[ -z ${PLATFORMSH_CLI_TOKEN+x} ]]; then
    message="You will need to create an environmental variable 'PLATFORMSH_CLI_TOKEN' that contains a valid platform.sh "
    message="${message} token before I can run platform.sh cli commands."
    logFatalError "PSH Token Check" "${message}"
    exit 1
  fi
}

# Gets the production branch name
# One would think this should be simple, but one would be wrong
# https://platformsh.slack.com/archives/CEDK8KCSC/p1640717471389700
function getProductionBranchName() {
  defaultBranch=$(platform environment:list --type production --pipe)
  result=$?

  if ( 0 != result) || [ -z "${defaultBranch}" ]; then
    event="Retrieving default_branch from project"
    message="I was unable to retrieve the default_branch for this project. Please create a ticket and ask that it be"
    message="${message} assigned to the DevRel team."
    logFatalError "${event}" "${message}"
    exit 1
  fi

  # oh, we're not done yet. It's plausible that in the future, we may have more than one production branch
  # so split the return from the above by line break, and then let's see if we were given exactly one
  IFS=$'\n' read -rd '' -a branches <<< "${defaultBranch}"
  if (( 1 != ${#branches[@]} )); then
    message="More than one production branch was returned. I was given the following branches:\n%s" "${defaultBranch}"
    logFatalError "${event}" "${message}"
    exit 1
  fi

  # @todo since we know we have just one, should we echo defaultBranch, or branches[0]? or does it matter?
  echo "${branches[0]}"
}

function getUpdateBranchName() {
  echo "${PSH_SOP_UPDATE_BRANCH:-update}"

}

function getSourceOpName() {
  echo "${PSH_SOP_NAME:-auto-update}"
}

# For now this just echos the error message, but might expand to include slack notice?
function logFatalError() {
  event="${1:-no event specificied}"
  message="${2:-no message provided}"
  printf "Fatal error encountered during %s\n%s" "${event}" "${message}"
}

# Ensures the psh cli tool is installed and available
function ensureCliIsInstalled() {
    if which platform; then
        echo "Cli is already installed"
    else
        # @todo should we follow up afterwards and make sure it installs correctly?
        echo "Cli not installed, installing..."
        curl -sS https://platform.sh/cli/installer | php
    fi
}

# we need the update branch, and we need it to be synced with production
function createOrSyncUpdateBranch() {
    BRANCH_NAME="$1"
    BRANCH_FROM="$2"

    # kill two birds with one stone here: if it doesn't exist, then we'll get an error and know we need to create it. If
    # it exists, then we'll know if we need to sync it
    commitsBehind=$(platform environment:info merge_info.commits_behind -e "${BRANCH_NAME}")
    branchExists=$?

    if (( 0 != branchExists )); then
      # we need to create the branch
      platform e:branch "${BRANCH_NAME}" "${BRANCH_FROM}" --no-clone-parent --force
    elif (( 0 != commitsBehind )); then
      # we have the branch but it needs to be synced
    fi

    echo "Creating branch '$BRANCH_NAME'"

    CURRENT_BRANCH=$(platform e:list --type=development --columns=ID --no-header --format=csv | grep "$BRANCH_NAME")

    if [ "$CURRENT_BRANCH" == "$BRANCH_NAME" ]; then
        echo "Branch already exists, reactivating"
        activateBranch "$BRANCH_NAME"
        if platform sync -e "$BRANCH_NAME" --yes --wait code; then
            echo "Branch synced"
        else
            echo "Failed to sync"
            exit
        fi
    else
        platform branch --force --no-clone-parent --wait "$BRANCH_NAME" "$BRANCH_FROM"
        echo "Branch created"
    fi
}

function createBranch() {
  updateBranch="${1}"
  productionBranch="${2}"
}

function syncBranch() {
  updateBranch="${1}"
  productionBranch="${2}"      
}

function runSourceOperation() {
    SOURCEOP_NAME="$1"
    ENV_NAME="$2"
    echo "Running source operation '$SOURCEOP_NAME' on '$ENV_NAME'..."
    if platform source-operation:run "$SOURCEOP_NAME" --environment "$ENV_NAME" --wait ; then
        echo "Source op finished"
    else
        event="Running source operation ${SOURCEOP_NAME}"
        message="An error occurred while trying to run the source operation ${SOURCEOP_NAME}. Please see the activity log"
        logFatalError "${event}" "${message}"
        exit 1
    fi
}

function test_urls() {
    ENV_NAME="$1"
    for url in $(platform url --pipe --environment "$ENV_NAME"); do
        echo -n "Testing $url";
        STATUS_RETURNED=$(curl -ILSs "$url" | grep "HTTP" | tail -n 1 | cut -d' ' -f2)

        if [ "$STATUS_RETURNED" != "200" ]; then
            echo " [FAILED] $STATUS_RETURNED"
            exit
        else
            echo " [OK] $STATUS_RETURNED"
        fi
    done
    echo "All tests passed!"
}

function help() {
    echo "Usage: "
    echo " bash updater trigger_source_op ENV SOURCEOP (makes sure a branch named ENV is created, and then triggers the source operation named SOURCEOP)"
    echo " bash updater update_source (runs composer update and git add/commit)"
    exit 1
}

