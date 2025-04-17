#!/bin/bash

user=$(gid --user --name)
function test::check () {
    if [[ ! "$user" == "root" ]]; then
        echo "🛑 prefix this execution with 'sudo'"
        echo "🛑 sudo -u root ./test/_sudo_.sh"
        exit 1
    fi
}

function main () {
    test::check
}

main