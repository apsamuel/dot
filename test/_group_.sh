#!/bin/bash

function test::check () {
    declare dot_user
    declare -A all_groups
    declare -a user_groups
    declare -a desired_groups
    dot_user=$(command gid --user --name)
    desired_groups+=("admin")

    while read -r group_name group_members; do
        all_groups["${group_name}"]="${group_members}"
    done < <(command dscl . list /Groups GroupMembership)

    for _group in "${!all_groups[@]}"; do
        if [[ "${all_groups[${_group}]}" =~ ${dot_user} ]]; then
            user_groups+=("${_group}")
        fi
    done

    for desired_group in "${desired_groups[@]}"; do
        if [[ ! "${user_groups[*]}" =~ ${desired_group} ]]; then
            echo "🛑 ${dot_user} is not in group: ${desired_group}"
            exit 1
        fi
    done
}

function main () {
    test::check
}

main