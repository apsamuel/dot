#% author: Aaron Samuel
#% description: shell output functions
# shellcheck shell=bash

#** disable relevant shellcheck warnings **#
# shellcheck source=/dev/null
# shellcheck disable=SC2207

# edirect tools

directory=$(dirname "$0")
library=$(basename "$0")

if [[ "${DOT_DEBUG}" -eq 1 ]]; then
    echo "loading: ${library} (${directory})"
fi


inPath() {
  local path="$1"
  # check if the provided path is in the PATH variable
  [[ ":$PATH:" == *":$path:"* ]] && return 0 || return 1
}

if [ -d "${HOME}/Tools/edirect" ] ; then
  PATH="${HOME}/Tools/edirect:${PATH}"
fi


# source $DOT_DIR/bin
if [ -d "$DOT_DIR/bin" ] ; then
  PATH="${DOT_DIR}/bin:${PATH}"
fi

# theoretical $HOME/bin
if [ ! -d "${HOME}/bin" ] ; then
  mkdir -p "${HOME}/bin"
fi
PATH="${HOME}/bin:${PATH}"

# read YAML/JSON configuration, find the PATHS property, and add those paths to the PATH variable
# # scripts in devops dir
# if [ -d "${HOME}/devops/scripts" ] ; then
#   PATH="${HOME}/devops/scripts:${PATH}"
# fi

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
  printf "%s\n" "$(echo "$PATH" | sed -e 's/:/\n/g')"
}


export PATH