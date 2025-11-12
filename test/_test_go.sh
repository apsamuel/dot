#!/bin/bash
set -euo pipefail

go build -x -v -o "${DOT_DIRECTORY}/test/go.bin" "${DOT_DIRECTORY}/test/main.go"