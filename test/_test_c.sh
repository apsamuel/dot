#!/bin/bash
set -euo pipefail

clang "${DOT_DIRECTORY}/test/main.c" -o "${DOT_DIRECTORY}/test/c.bin"