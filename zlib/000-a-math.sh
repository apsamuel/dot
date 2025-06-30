#!/usr/local/bin/bash

bcSolve() {
    # given a mathematical expression, solve it using bc
    if [[ $# -eq 0 ]]; then
        echo "Usage: bcSolve <expression>"
        return 1  # return error if no expression is provided
    fi

    local expression="$1"
    if [[ -z "${expression}" ]]; then
        echo "No expression provided"
        return 0  # return empty string if no expression is provided
    fi

    # use bc to evaluate the expression
    result=$(echo "${expression}" | bc -l)
    echo "${result}"  # print the result
    return 0
}