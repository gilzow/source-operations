#!/usr/bin/env bash
# bash <(curl -fsS https://raw.githubusercontent.com/gilzow/source-operations/main/test.sh) foobar
# https://github.com/gilzow/source-operations.git

dirSourceOps="/tmp/source-operations"

#check and see if we already have the repo cloned in /tmp
git -c "${dirSourceOps}" status
gitCheck=$?

if (( 0 == gitCheck )); then
  
fi


# Ensures we have our tmp directory set up
# @return string name of the temp directory
function makeTmpDir() {
  name="/tmp/sourceops"
  if [[ ! -d "${name}" ]]; then
    mkdir -p "${name}"
  fi

  echo "${name}"
}

# Removes the "old" version of our scripts
# @param string path *and* file to remove
# @return bool exit status
function removeOldVerion() {
  file="${1}"
  if [[ -f "${file}" ]]; then
    rm -f "${file}"
  fi
}

tmpDir=$(makeTmpDir) || exit 1

perform=${1:-'nothing'}
case ${perform} in

  autoprsourceop)
    printf "Beginning automated pull request after auto-update source operation..."
    # grab our sourceop-support file, save it, source it, then fire off the main component
    sourceopSupport="${tmpDir}/sourceops-support.sh"
    # get rid of the old version in case we already have it
    removeOldVerion "${sourceopSupport}"
    curl -o "${sourceopSupport}" -fsSO https://raw.githubusercontent.com/gilzow/source-operations/auto-pr/sourceop-support.sh
    . "${sourceopSupport}"
    (trigger_source_op) || exit 1
    createGHPR="${tmpDir}/create-ghpr.sh"
    removeOldVerion "${createGHPR}"
    curl -o "${createGHPR}" -fsSO https://raw.githubusercontent.com/gilzow/source-operations/auto-pr/create-ghpr.sh


    ;;

  foobar)
    echo "you want me to bar foo"
    ;;

  nothing)
    echo "You want me to do nothing"
    ;;

  *)
    echo "I have no idea what you want me to do"
    ;;
esac

