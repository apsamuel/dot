#% author: Aaron Samuel
#% description: shell output functions
# shellcheck shell=bash

#** disable relevant shellcheck warnings **#
# shellcheck source=/dev/null
# shellcheck disable=SC2207

# edirect tools

directory=$(dirname "$0")
library=$(basename "$0")

dot::static::logging::loading "${library}" "${directory}"

# GNU Make 4.4+ from Homebrew (required by dot Makefile .ONESHELL)
if [[ -d "$(brew --prefix 2>/dev/null)/opt/make/libexec/gnubin" ]]; then
  PATH="$(brew --prefix)/opt/make/libexec/gnubin:${PATH}"
fi


dot::paths::in() {
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

# source $DOT_DIR/scripts
if [ -d "$DOT_DIR/scripts" ] ; then
  PATH="${DOT_DIR}/scripts:${PATH}"
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

dot::paths::add() {
  if [[ -z "$1" ]]; then
    echo "Usage: dot::paths::add <path1> <path2> ..."
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
        dot::static::logging::debug "skipping existing path: '${path}'"
        continue  # skip if the path is already in the PATH
      fi

      # skip paths that are not executable
      if [[ ! -x "${path}" ]]; then
        dot::static::logging::debug "skipping inaccessible path: ${path}"
        continue  # skip if the path does not exist
      fi

      # skip paths that do not contain any executable files ...
      if [[ -z "$(find "${path}" -maxdepth 1 -type f -executable)" ]]; then
        dot::static::logging::debug "skipping path with no executables: ${path}"
        continue  # skip if the path does not contain any executable files
      fi

      dot::static::logging::debug "adding path: ${path}"
      # add the path to the array
      path_array+=("${path}")
    else
      dot::static::logging::debug "skipping non-directory path: ${path}"
      continue  # skip if the path is not a directory
    fi

  done
  # join the array back into a string
  PATH=$(joinList ":" "${path_array[@]}")
  export PATH  # export the updated PATH variable
  return 0

}

dot::paths::delete() {
  # delete one or more paths from the PATH variable
  if [[ -z "$1" ]]; then
    echo "Usage: dot::paths::delete <path1> <path2> ..."
    return 1  # return error if no path is provided
  fi
  new_path_array=()
  path_array=(
    $(splitString "${PATH}" ":")
  )
  for path in "${path_array[@]}"; do
    # skip empty paths
    if [[ -z "${path}" ]]; then
      dot::static::logging::debug "skipping empty path: '${path}'"
      continue  # skip empty paths
    fi

    # check if the path is in the arguments to delete
    if [[ " $* " =~ " ${path} " ]]; then
      dot::static::logging::debug "deleting path: ${path}"
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

dot::paths::print() {
  printf "%s\n" "$(echo "$PATH" | sed -e 's/:/\n/g')"
}


export PATH
