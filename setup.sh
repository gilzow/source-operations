#!/usr/bin/env bash

perform=${1:-'nothing'}
case ${perform} in

  autoprsourceop)
    printf "Beginning automated pull request after auto-update source operation..."
    # grab our sourceop-support file, save it, source it, then fire off the main component
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