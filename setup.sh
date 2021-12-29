#!/usr/bin/env bash
# bash <(curl -fsS https://raw.githubusercontent.com/gilzow/source-operations/main/test.sh) foobar
# bash <(curl -fsS https://raw.githubusercontent.com/gilzow/source-operations/main/setup.sh) autoprsourceop
# https://github.com/gilzow/source-operations.git

gitSourceOps="https://github.com/gilzow/source-operations.git"
tmpDir="/tmp"
dirSourceOps="${tmpDir}/source-operations"

#check and see if we already have the repo cloned in /tmp
git -C "${dirSourceOps}" status
gitCheck=$?

# we dont have the repo cloned so let's clone it
if (( 0 != gitCheck )) || [[ ! -d "${dirSourceOps}" ]]; then
  git -C "${tmpDir}" clone "${gitSourceOps}"
else
  # we have it so let's make sure we're up-to-date
  git -C "${dirSourceOps}" pull origin
fi


perform=${1:-'nothing'}
case ${perform} in

  autoprsourceop)
    echo "Beginning the automated pull request for auto-update source operation task..."
    # grab our sourceop-support file, source it, then fire off the main component
    . "${dirSourceOps}/sourceop-support.sh"
    # run the set up and source operation
    (trigger_source_op) || exit 1

    #now we're ready to start the PR process
    . "{$dirSourceOps}/ghPR.sh"

    ;;

  autoupdatesourceop)
    echo "Beginning automated source operation update process..."
    # grab our sourceop-support file, source it, then fire off the main component
    . "${dirSourceOps}/sourceop-support.sh"
    # run the set up and source operation
    (trigger_source_op) || exit 1
    echo "Complete. You can now test the updated branch."
    ;;

  nothing)
    echo "You want me to do nothing"
    ;;

  *)
    echo "I have no idea what you want me to do"
    ;;
esac

# @todo maybe we should move