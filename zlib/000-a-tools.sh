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
    printf "%s" "${joined}"  # print the joined string
    return_code=$?
    if [[ ${return_code} -ne 0 ]]; then
        echo "Error joining elements"
        return ${return_code}  # return error code if join fails
    fi
    return 0  # return success
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

addPath() {
  if [[ -z "$1" ]]; then
    echo "Usage: addPath <path1> <path2> ..."
    return 1  # return error if no path is provided
  fi
  path_array=(
    $(splitString "${PATH}" ":")
  )
  for path in "$@"; do

    # skip empty paths
    if [[ -z "${path}" ]]; then
      echo "skipping empty path: '${path}'"
      continue  # skip empty paths
    fi

    # check if the path is an existing directory
    if [ -d "${path}" ]; then
      # check if the path is already in the PATH array
      if [[ "${path_array[*]}" =~ ${path} ]]; then
        echo "skipping existing path: '${path}'"
        continue  # skip if the path is already in the PATH
      fi

      # skip paths that are not executable
      if [[ ! -x "${path}" ]]; then
        echo "skipping inaccessible path: ${path}"
        continue  # skip if the path does not exist
      fi

      # skip paths that do not contain any executable files ...
      if [[ -z "$(find "${path}" -maxdepth 1 -type f -executable)" ]]; then
        echo "skipping path with no executables: ${path}"
        continue  # skip if the path does not contain any executable files
      fi

      echo "adding path: ${path}"
      # add the path to the array
      path_array+=("${path}")
    else
      echo "skipping non-directory path: ${path}"
      continue  # skip if the path is not a directory
    fi

  done
  # join the array back into a string
  PATH=$(joinList ":" "${path_array[@]}")
  export PATH  # export the updated PATH variable
  return 0

}

deletePath() {
  # delete one or more paths from the PATH variable
  if [[ -z "$1" ]]; then
    echo "Usage: deletePath <path1> <path2> ..."
    return 1  # return error if no path is provided
  fi
  new_path_array=()
  path_array=(
    $(splitString "${PATH}" ":")
  )
  for path in "${path_array[@]}"; do
    # skip empty paths
    if [[ -z "${path}" ]]; then
      echo "skipping empty path: '${path}'"
      continue  # skip empty paths
    fi

    # check if the path is in the arguments to delete
    if [[ " $* " =~ " ${path} " ]]; then
      echo "deleting path: ${path}"
      continue  # skip if the path is in the arguments to delete
    fi

    # add the path to the new array
    new_path_array+=("${path}")
  done

  return_code=$?
  if [[ ${return_code} -ne 0 ]]; then
    echo "Error deleting paths"
    return ${return_code}
  fi
}

printPath() {
  return 0
}