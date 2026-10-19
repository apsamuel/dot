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


dot::paths::help() {
  local topic="${1:-}" usage="" description=""
  case "${topic}" in
    ''|help|-h|--help)
      printf '%s\n' 'Usage: dot::paths <command> [arguments]' 'Commands: in, add, delete, print, help' 'Example: dot::paths help add'
      return 0 ;;
    in) usage='DIRECTORY'; description='Test exact PATH membership. Returns 0 when present, 1 otherwise. Leaf arguments are literal data, including --help.' ;;
    add) usage='[--] DIRECTORY [DIRECTORY...]'; description='Append accessible directories containing executable files; skip duplicates and unsuitable directories. Changes PATH in this shell. Requires find.' ;;
    delete) usage='[--] DIRECTORY [DIRECTORY...]'; description='Remove exact directory entries from PATH in this shell. Missing entries are ignored.' ;;
    print) description='Print PATH entries, one per line. Does not change PATH.' ;;
    *) printf 'dot::paths: unknown help topic: %s\n' "${topic}" >&2; return 1 ;;
  esac
  printf 'Usage: dot::paths %s %s\n       dot::paths::%s %s\n%s\n' "${topic}" "${usage}" "${topic}" "${usage}" "${description}"
  printf '%s\n' 'Use -- before dash-leading directories for add/delete. Help requires no external tools.' 'Returns 0 on success, nonzero on invalid usage or an operational failure.'
}

dot::paths() {
  local action="${1:-help}"
  [[ $# -eq 0 ]] || shift
  case "${action}" in
    help|-h|--help) dot::paths::help "$@" ;;
    in) dot::paths::in "$@" ;;
    add) dot::paths::add "$@" ;;
    delete) dot::paths::delete "$@" ;;
    print) dot::paths::print "$@" ;;
    *) printf 'dot::paths: unknown command: %s\n' "${action}" >&2; return 1 ;;
  esac
}

dot::paths::in() {
  [[ $# -eq 1 ]] || return 1
  local target_path="$1"
  # check if the provided path is in the PATH variable
  [[ ":$PATH:" == *":${target_path}:"* ]] && return 0 || return 1
}

if [ -d "${HOME}/Tools/edirect" ] ; then
  PATH="${HOME}/Tools/edirect:${PATH}"
fi


# source $DOT_DIRECTORY/bin
if [ -d "$DOT_DIRECTORY/bin" ] ; then
  PATH="${DOT_DIRECTORY}/bin:${PATH}"
fi

# source $DOT_DIRECTORY/scripts
if [ -d "$DOT_DIRECTORY/scripts" ] ; then
  PATH="${DOT_DIRECTORY}/scripts:${PATH}"
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
  case "${1:-}" in -h|--help) dot::paths::help add; return ;; --) shift ;; -*) printf 'dot::paths::add: unknown option: %s\n' "$1" >&2; return 1 ;; esac
  [[ $# -gt 0 ]] || { dot::paths::help add >&2; return 1; }
  local target_path="" updated_path="${PATH}" executables="" search_path=""
  for target_path in "$@"; do
    [[ "${target_path}" != *:* ]] || { printf '%s\n' 'dot::paths::add: directories cannot contain a colon' >&2; return 1; }
  done
  for target_path in "$@"; do
    if [[ -z "${target_path}" ]]; then
      printf '%s\n' "skipping empty path: '${target_path}'"
      continue
    fi
    [[ -d "${target_path}" && -x "${target_path}" ]] || continue
    [[ ":${updated_path}:" != *":${target_path}:"* ]] || continue
    command -v find >/dev/null 2>&1 || { printf '%s\n' 'dot::paths::add: find is required' >&2; return 1; }
    search_path="${target_path}"
    case "${search_path}" in -*) search_path="./${search_path}" ;; esac
    executables="$(find "${search_path}" -maxdepth 1 -type f -executable)" || return $?
    [[ -n "${executables}" ]] || continue
    dot::static::logging::debug "adding path: ${target_path}"
    updated_path="${updated_path}:${target_path}"
  done
  PATH="${updated_path}"
  export PATH
  return 0

}

dot::paths::delete() {
  case "${1:-}" in -h|--help) dot::paths::help delete; return ;; --) shift ;; -*) printf 'dot::paths::delete: unknown option: %s\n' "$1" >&2; return 1 ;; esac
  [[ $# -gt 0 ]] || { dot::paths::help delete >&2; return 1; }
  local remaining="${PATH}" entry="" target_path="" updated_path="" separator="" remove_entry=0
  while :; do
    entry="${remaining%%:*}"
    remove_entry=0
    for target_path in "$@"; do
      [[ "${entry}" != "${target_path}" ]] || remove_entry=1
    done
    if [[ "${remove_entry}" -eq 0 ]]; then
      updated_path="${updated_path}${separator}${entry}"
      separator=:
    fi
    [[ "${remaining}" == *:* ]] || break
    remaining="${remaining#*:}"
  done
  PATH="${updated_path}"
  export PATH
  return 0
}

dot::paths::print() {
  case "${1:-}" in -h|--help) dot::paths::help print; return ;; esac
  [[ $# -eq 0 ]] || { dot::paths::help print >&2; return 1; }
  local remaining="${PATH}"
  while :; do
    printf '%s\n' "${remaining%%:*}"
    [[ "${remaining}" == *:* ]] || break
    remaining="${remaining#*:}"
  done
}


export PATH
