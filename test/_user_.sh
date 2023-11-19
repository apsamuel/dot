#!/bin/bash

function tests::check () {
    RUNNER=$(gid --user --name)
    if [[ "$RUNNER" == "root" ]]; then
        echo "🛑 please run this script as a non-root user"
        exit 1
    fi

    echo "✅ user $RUNNER ok"
}

function main () {
    tests::check
}

main
