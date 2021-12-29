#!/usr/bin/env bash
function trigger_source_op() {
    ENV="$1"
    SOURCEOP="$2"

    if [ "$PLATFORMSH_CLI_TOKEN" == "" ]; then
        echo "env:PLATFORMSH_CLI_TOKEN is not set, please create it."
        exit 1
    fi

    ensureCliIsInstalled

    echo "Looking for production branch... "
    PRODUCTION_ENV=$(platform e:list --type=production --columns=ID --no-header --format=csv)
    echo "Production branch = $PRODUCTION_ENV"

    createBranchIfNotExists "$ENV" "$PRODUCTION_ENV"
    runSourceOperation "$SOURCEOP" "$ENV"


    waitUntilEnvIsReady "$ENV"
    test_urls "$ENV"
    merge "$ENV"

}

function ensureCliIsInstalled() {
    if which platform; then
        echo "Cli is already installed"
    else
        echo "Cli not installed, installing..."
        curl -sS https://platform.sh/cli/installer | php
    fi
}

function createBranchIfNotExists() {
    BRANCH_NAME="$1"
    BRANCH_FROM="$2"

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

function activateBranch() {
    ENV_NAME="$1"
    echo "Activating branch '$ENV_NAME'..."
    platform environment:activate "$ENV_NAME" --wait --yes
    echo "Environment activated"
}

function runSourceOperation() {
    SOURCEOP_NAME="$1"
    ENV_NAME="$2"
    echo "Running source operation '$SOURCEOP_NAME' on '$ENV_NAME'..."
    if platform source-operation:run "$SOURCEOP_NAME" --environment "$ENV_NAME" --wait ; then
        echo "Source op finished"
    else
        echo "Source op failed to run"
        exit
    fi
}

function waitUntilEnvIsReady() {
    ENV_NAME="$1"
    echo "Waiting for '$ENV_NAME' to be ready..."

    until [ "$is_dirty" == "false" ] && [ "$activity_count" == "0" ]; do
        sleep 10
        is_dirty=$(platform e:info is_dirty -e "$ENV_NAME")
        activity_count=$(platform activity:list -e "$ENV_NAME" --incomplete --format=csv | wc -l)
    done
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

function mergeAndDelete() {
    ENV_NAME="$1"
    echo "Merging '$ENV_NAME'..."
    platform merge "$ENV_NAME" --no-wait --yes
    echo "Removing '$ENV_NAME'..."
    platform e:delete "$ENV_NAME" --no-wait --yes
}


function update_source() {
    declare -A cmds
    cmds["composer.lock"]="composer update --prefer-dist --no-interaction"
    cmds["Pipfile.lock"]="pipenv lock"
    cmds["Gemfile.lock"]="bundle update"
    cmds["package-lock.json"]="npm update"
    cmds["go.sum"]="go update -u all"
    cmds["yarn.lock"]="yarn upgrade"

    WAS_UPDATED=false

    echo "Updating source of $PLATFORM_BRANCH"

    # find each directory that has a .platform.app.yaml file
    for yaml in $(find . -name '.platform.app.yaml' -type f); do
        DIRECTORY=$(dirname "$yaml")
        # then, check each directory for the existance of package files (composer.json)
        for PACKAGE_FILE in ${!cmds[@]}; do
        if test -f "$DIRECTORY/$PACKAGE_FILE"; then
            # and when we find one, execute the package update command (composer update, npm update, ...)
            echo "$PACKAGE_FILE exists. Running ${cmds[$PACKAGE_FILE]}"
            ${cmds[$PACKAGE_FILE]}
            WAS_UPDATED=true
        fi
        done
    done

    # if we did an update, commit the changes
    if $WAS_UPDATED; then
        date > last_updated_on
        git add .
        git commit -m "auto update"
    fi
}


function help() {
    echo "Usage: "
    echo " bash updater trigger_source_op ENV SOURCEOP (makes sure a branch named ENV is created, and then triggers the source operation named SOURCEOP)"
    echo " bash updater update_source (runs composer update and git add/commit)"
    exit 1
}

ACTION="$1"

case $ACTION in

  trigger_source_op)
    ENV="$2"
    SOURCEOP="$3"
    if [ "$ENV" == "" ] || [ "$SOURCEOP" == "" ]; then
        help
    fi
    trigger_source_op "$2" "$3"
    ;;

  update_source)
    update_source
    ;;

  install_cli)
    ensureCliIsInstalled
    ;;

  *)
    help
    ;;
esac