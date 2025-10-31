#!/bin/bash
set -euo pipefail

javac -verbose "${DOT_DIRECTORY}/test/test.java" -d "${DOT_DIRECTORY}/test/java.bin"