#!/usr/bin/env bash
# shellcheck source=/dev/null


# source the plumbing functions, these should be prefixed with __ in this ecosystem

source "$(dirname "$0")/lib/common.sh"
function project_root() {
  local dir="$PWD"
  while [[ "$dir" != "/" ]]; do
    if [[ -f "$dir/.git/config" ]]; then
      echo "$dir"
      return
    fi
    dir="$(dirname "$dir")"
  done
  echo ""
}
