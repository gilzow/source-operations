#!/usr/bin/env bash
# note that the documentation on the functions indicates a return. Bash only really "returns" an exit status, but
# in case (or when) we convert this to another language, it may help to have the indicated return when it is different
# from a boolean exit status

#source our common functions
. "${BASH_SOURCE%/*}/common.sh"

function trigger_source_op() {
    printf "Beginning set up to perform the update...\n"
    # Things we need in order to be able to perform the operation
    (checkForPSHToken) || exit $?
    (ensureCliIsInstalled) || exit $?

    # Items we'll be using to perform the operation. updateBranch and sourceOpName have defaults; only with the
    # productionBranch we may encounter a fatal error
    productionBranch=$(getProductionBranchName) || exit $?
    updateBranch=$(getUpdateBranchName) # we have a default so need to exit on this step
    sourceOpName=$(getSourceOpName) # same, we have a default

    # We need to ensure we can operate on the targeted update branch, and once it's prepped, record its previous state
    # so we can set it back, if needed
    updateBranchPreviousStatus=$(prepareUpdateBranch "${updateBranch}" "${productionBranch}") || exit $?

    # Hey, we can finally run the source operation!
    (runSourceOperation "${sourceOpName}" "${updateBranch}") || exit $?

    # Now that we're done, let's restore the targeted update branch back to where it was before we touched it
    if [[ 'inactive' == "${updateBranchPreviousStatus}" ]]; then
      deactivateUpdateBranch "${updateBranch}"
    fi

    printf "Auto update of %s complete.\n" "${updateBranch}"
}

# Gets the production branch name
# One would think this should be simple, but one would be wrong
# https://platformsh.slack.com/archives/CEDK8KCSC/p1640717471389700
# @return string|bool production branch name, or exit status of 1
function getProductionBranchName() {
  defaultBranch=$(platform environment:list --type production --pipe)
  result=$?

  if ( 0 != result) || [ -z "${defaultBranch}" ]; then
    event="Retrieving production branch(es) from project"
    message="I was unable to retrieve a list of production type branches for this project. Please create a ticket and"
    message="${message} ask that it be assigned to the DevRel team."
    logFatalError "${event}" "${message}"
    exit 1
  fi

  # oh, we're not done yet. It's plausible that in the future, we may have more than one production branch
  # so split the return from the above by line break, and then let's see if we were given exactly one
  IFS=$'\n' read -rd '' -a branches <<< "${defaultBranch}"
  if (( 1 != ${#branches[@]} )); then
    # reusing event from above
    message="More than one production branch was returned. I was given the following branches:\n%s" "${defaultBranch}"
    logFatalError "${event}" "${message}"
    exit 1
  fi

  # @todo since we know we have just one, should we echo defaultBranch, or branches[0]? or does it matter?
  echo "${branches[0]}"
}

# gets the update branch name from the environmental variable PSH_SOP_UPDATE_BRANCH, or defaults to 'update'
# @return string targeted update branch name
function getUpdateBranchName() {
  echo "${PSH_SOP_UPDATE_BRANCH:-update}"
}
# gets the source operation name from the environmental variable PSH_SOP_NAME, or defaults to 'auto-update'
# @return string source operation name we want to run
function getSourceOpName() {
  echo "${PSH_SOP_NAME:-auto-update}"
}

# we need the update branch, and we need it to be synced with production
# this could mean we need to create the branch, or sync the branch, or do nothing
# @param string updateBranch name of branch we will target for updates
# @param string productionBranch name of the branch used for the production environment
# @return string|bool update branch status from before we touched it, or an exit status of 1
function prepareUpdateBranch() {
    updateBranch="$1"
    productionBranch="$2"

    # how many are we allowed to have
    #platform p:info subscription.environments
    # how many do we have active
    # platform e:list --type=development,staging --no-inactive --pipe
    # kill two birds with one stone here: if it doesn't exist, then we'll get an error and know we need to create it. If
    # it exists, then we'll know if we need to sync it
    updateBranchStatus=$(platform environment:info status -e "${updateBranch}")
    branchExists=$?

    if (( 0 != branchExists )); then
      # we need to create the branch. Since we're creating it, we need to later deactivate it
      updateBranchStatus='inactive'
      (createBranch "${updateBranch}" "${productionBranch}") || exit $?
    else
      # we also need to make sure the update branch's parent is the same as production
      (validateUpdateBranchAncestory "${updateBranch}" "${productionBranch}") || exit $?

      # we have the branch but it needs to be synced. In order to be sync'ed it has to be active
      if [[ 'inactive' == "${updateBranchStatus}" ]]; then
        (activateBranch "${updateBranch}") || exit $?
      fi
      #now that we know it's active, let's sync
      # Originally we were checking the `commits_behind` status of the branch and only doing a sync if it was behind,
      # but if a branch is already up-to-date with its parent, then performing a sync command on it will simply return
      # a true
      (syncBranch "${updateBranch}" "${productionBranch}") || exit $?
    fi

    echo "${updateBranchStatus}"
}

# Activates a branch
# @param string name of branch to activate
# @return void
function activateBranch() {
    ENV_NAME="$1"
    printf "Activating branch '%s'..." "${ENV_NAME}"
    platform environment:activate "${ENV_NAME}" --wait --yes
    result=$?
    if (( 0 != result )); then
      event="Failure activating branch ${ENV_NAME}"
      message="I encountered an error while attempting to activate the branch ${ENV_NAME}. Please check the activity log"
      message="${message} to see why activation failed"
      logFatalError "${event}" "${message}"
      exit 1
    fi
    printf " Environment activated.\n"
}

# Creates the update branch so we can run source operations against it
# @param string name of the branch to be created
# @param string name of the parent branch (production) to create the branch from
# @return bool exit status
function createBranch() {
  updateBranch="${1}"
  productionBranch="${2}"
  printf "Creating environment %s..." "${updateBranch}"
  platform e:branch "${updateBranch}" "${productionBranch}" --no-clone-parent --force
  result=$?
  if (( 0 != result )); then
    event="Failure creating branch ${ENV_NAME}"
    message="I encountered an error while attempting to create the branch ${ENV_NAME}. Please check the activity log"
    message="${message} to see why creation failed"
    logFatalError "${event}" "${message}"
    exit 1
  fi

  printf " Environment created.\n"
}

# Make sure the update branch is a direct child of production
# @param string name of update branch
# @param string name of production branch
# @return bool exit status
function validateUpdateBranchAncestory() {
  updateBranch="${1}"
  productionBranch="${2}"
  parent=$(platform environment:info parent -e "${updateBranch}")

  if [[ "${parent}" != "${productionBranch}" ]]; then
    event="Update Branch ${updateBranch} is not a direct descendant of ${productionBranch}"
    message="The targeted update branch, ${updateBranch}, is not a direct descendant of the production branch"
    message="${message} ${productionBranch}. The update branch's parent is ${parent}. This automated source operation"
    message="${message} only supports updating branches that are direct descendants of the production branch"
    logFatalError "${event}" "${message}"
    exit 1
  fi
}

# Syncs the code from production down to our update branch before we run the auto-update source operation
# @param string update branch name
# @param string production branch name
# @return bool exit status
function syncBranch() {
  updateBranch="${1}"
  productionBranch="${2}"

  printf "Syncing branch %s with %s..." "${updateBranch}" "${productionBranch}"

  platform sync -e "${updateBranch}" --yes --wait code
  result=$?
  if (( 0 != result )); then
    event="Failed to sync environment ${updateBranch} with ${productionBranch}"
    message="I was unable to sync the environment ${updateBranch} with ${productionBranch}. You will need to examine the"
    message="${message} logs to find out why"
    logFatalError "${event}" "${message}"
    exit 1
  fi

  printf " Syncing complete.\n"
}

# Sets the environment back to inactive status (ie Deletes the *environment* but not the git branch)
# @todo do we care about tracking the return status from the command?
# @param string name of branch to deactivate
# @return exit status
function deactivateUpdateBranch() {
  updateBranch="${1}"
  printf "Deactivating environment %s\n" "${updateBranch}"
  platform e:delete "${updateBranch}" --no-delete-branch --no-wait --yes
}

# Runs the named source operation against a target branch
# @param string the name of the source operation we want to run
# @param string name of the branch we want to perform the source operation against
# @return exit status
function runSourceOperation() {
    SOURCEOP_NAME="$1"
    ENV_NAME="$2"
    printf "Running source operation '%s' on '%s'..." "${SOURCEOP_NAME}" "${ENV_NAME}"
    if platform source-operation:run "${SOURCEOP_NAME}" --environment "${ENV_NAME}" --wait ; then
        printf " Source op finished!\n"
    else
        event="Running source operation ${SOURCEOP_NAME}"
        message="An error occurred while trying to run the source operation ${SOURCEOP_NAME}. Please see the activity log"
        logFatalError "${event}" "${message}"
        exit 1
    fi
}


