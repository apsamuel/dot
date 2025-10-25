#!/usr/bin/env bash

function project_root() {
  local dir="$PWD"
  while [[ "$dir" != "/" ]]; do
    if [[ -f "$dir/.turtle_project" || -f "$dir/.git/config" ]]; then
      echo "$dir"
      return
    fi
    dir="$(dirname "$dir")"
  done
  echo ""
}

function turtle_project_root() {
  # we expect a turtle project root to exist in the $HOME/.dot/turtle directory
  echo "$(project_root)/turtle"
}