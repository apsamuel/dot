#!/usr/local/bin/bash


splitString() {
    local string="$1"
    local delimiter="$2"
    parts=()
    if [[ -z "${delimiter}" ]]; then
        delimiter=" "  # default to space if no delimiter is provided
    fi

    if [[ -z "${string}" ]]; then
        echo "empty string"  # return empty string if input is empty
        return
    fi
    OLD_IFS="${IFS}"  # save the old IFS
    IFS="${delimiter}"

    read -rA parts <<< "${string}"  # read the string into an array using the delimiter
    set -- "${string}"  # set positional parameters to the split parts

    IFS="${OLD_IFS}"  # restore the old IFS

    echo "${parts[@]}"  # print the parts as a space-separated string
    return 0
}

joinList() {
    # given a delimiter and a list of elements, join them into a single string
    # use xargs to handle the elements

    local joined=""
    if [[ $# -lt 2 ]]; then
        echo "Usage: joinList <delimiter> <element1> <element2> ..."
        return 1  # return error if not enough arguments
    fi
    if [[ -z "${delimiter}" ]]; then
        delimiter=" "  # default to space if no delimiter is provided
    fi


    local delimiter="$1"
    shift



    local elements=("$@")

    if [[ -z "${elements}" ]]; then
        echo "No elements provided"  # return empty string if no elements are provided
        return 0
    fi
    # echo "elements: ${elements[*]}"  # debug print of elements
    if [[ ${#elements[@]} -eq 0 ]]; then
        echo "No elements to join"  # return empty string if no elements are provided
        return 0
    fi


    for element in "${elements[@]}"; do
        if [[ -z "${element}" ]]; then
            continue  # skip empty elements
        fi
        if [[ -z "${joined}" ]]; then
            joined="${element}"  # initialize joined string
        else
            joined+="${delimiter}${element}"  # append with delimiter
        fi
    done
    echo "${joined}"  # print the joined string
    return 0
}

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