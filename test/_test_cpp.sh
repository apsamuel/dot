# shellcheck shell=bash
set -euo pipefail
g++ "${DOT_DIRECTORY}/test/main.cpp" -o "${DOT_DIRECTORY}/test/cpp.bin"
