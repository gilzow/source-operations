#!/usr/bin/env bash

git clone https://github.com/gilzow/source-operations.git

function sourceOp() {
  python "${PWD}/main.py" "$@"
}

#python source-operations/main.py
