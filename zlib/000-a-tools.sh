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

fetchRemote() {
  # cat a remote file using ssh
  if [[ $# -ne 1 ]]; then
    echo "Usage: fetchRemote <remote_user@remote_host:remote_file>"
    echo "Example: fetchRemote user@host:/path/to/remote/file.txt"
    return 1  # return error if not enough arguments are provided
  fi
  local remote_file="$1"
  local tmpfile
  tmpfile=$(mktemp /tmp/remote_file.XXXXXX)  # create a temporary file to store the remote file content
  trap 'rm -f "${tmpfile}"' EXIT  # ensure the temporary file is removed on exit

  # check if the argument is a remote file
  if [[ "$remote_file" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+:[/].* ]]; then
    echo "Fetching remote file: ${remote_file}"
    # use ssh to cat the remote file
    if ! ssh "${remote_file}" "cat \${remote_file#*:}" > "${tmpfile}"; then
      echo "Error fetching remote file: ${remote_file}"
      return 1  # return error if ssh command fails
    fi
    cat "${tmpfile}"
  else
    echo "Invalid remote file format: ${remote_file}"
    return 1  # return error if the argument is not a valid remote file format
  fi
}

sshDiff() {
  # compare remote and local files using ssh
  # compare remote files using ssh
  fileA=$(mktemp /tmp/fileA.XXXXXX)
  fileB=$(mktemp /tmp/fileB.XXXXXX)
  if [[ $# -ne 2 ]]; then
    echo "we expect two arguments, but got $#"
    echo "usages: "
    echo "  sshDiff <remote_user@remote_host:remote_file> <local_file>"
    echo "  sshDiff user@host:/path/to/remote/file.txt /path/to/local/file.txt"
    echo "  sshDiff <remote_user@remote_host:remote_file> <remote_user@remote_host:remote_file>"
    return 1
  fi


  local a="$1"
  local b="$2"

  # check if both files are provided
  if [[ -z "${a}" || -z "${b}" ]]; then
    echo "both arguments are required."
    echo "usage: sshDiff <remote_user@remote_host:remote_file> <local_file>"
    echo "example: sshDiff user@host:/path/to/remote/file.txt /path/to/local/file.txt"
    echo "example: sshDiff user@host:/path/to/remote/file.txt user@host:/path/to/remote/file.txt"
    return 1
  fi

  # check if both arguments are the same
  if [[ "${a}" == "${b}" ]]; then
    echo "both arguments are the same: ${a}"
    return 0  # return success if both arguments are the same
  fi

  # check if the first argument is a remote file
  if [[ "${a}" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+:[~/].* ]]; then
    echo "fetching remote file: ${a}"
    # use scp to copy the remote file to a temporary file
    if ! scp "${a}" "${fileA}"; then
      echo "error fetching remote file: ${a}"
      return 1  # return error if scp command fails
    fi
  else
    echo "checking local file: ${a}"
    if [[ -f "$1" ]]; then
      cat "$1" > "$fileA"
    else
      return 1  # return error if the first argument is not a valid remote file format or local file
    fi
  fi

  if [[ "${b}" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+:[~/].* ]]; then
    echo "fetching remote file: ${b}"
    # use scp to copy the remote file to a temporary file
    if ! scp "${b}" "${fileB}"; then
      echo "error fetching remote file: ${b}"
      return 1  # return error if scp command fails
    fi
  else
    # check if the second argument is a valid local file
    echo "checking local file: ${b}"
    if [[ -f "$2" ]]; then
      cat "$2" > "$fileB"
    else
      return 1
    fi
  fi

  echo "comparing files:"
  echo "  File A: ${fileA}"
  echo "  File B: ${fileB}"

  diff "$fileA" "$fileB"

  return_code=$?
  # rm -f "${fileA}" "${fileB}"  # remove temporary files
  if [[ ${return_code} -eq 0 ]]; then
    echo "files are the same"
    return ${return_code}  # return error code if diff fails
  fi
  return 0  # return success
}