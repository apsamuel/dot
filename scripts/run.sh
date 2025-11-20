# shellcheck source=/dev/null
# shellcheck shell=bash
source "$(dirname "$0")/lib/main.sh"
# Navigate to the turtle project root
cd "$(turtle_project_root)" || exit 1
cargo run -- "$@"