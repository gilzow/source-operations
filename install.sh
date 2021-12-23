#!/usr/bin/env bash

git clone https://github.com/gilzow/source-operations.git
IFS=':' read -ra PATHS <<< "${PATH}"
for dir in "${PATHS[@]}"; do
  printf "Evaluating %s\n" "${dir}"
  sourceFile="sourceOp"
  source="${PLATFORM_SOURCE_DIR}/source-operations/${sourceFile}"
  if [ -d "${dir}" ] && [ -w "${dir}" ] && [ ! -e "${dir}/${sourceFile}" ]  && [ ! -L "${dir}/${sourceFile}" ]; then
    printf "Creating link at %s for source %s" "${dir}/${sourceFile}" "${source}"
    ln -s -f "$source" "${dir}/${sourceFile}"
    break;
  fi
done

