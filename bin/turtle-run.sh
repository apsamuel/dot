#!/usr/bin/env bash

# shellcheck source=/dev/null
# shellcheck shell=bash

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
	echo "Usage: turtle-run.sh [cargo-run-args...]"
	echo "Run the turtle project with cargo from the project root."
	exit 0
fi

source "$(dirname "$0")/lib/main.sh"
# Navigate to the turtle project root
cd "$(turtle_project_root)" || exit 1
cargo run -- "$@"