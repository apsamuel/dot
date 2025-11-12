#!/bin/bash
set -euo pipefail

javac  "${DOT_DIRECTORY}/test/java.bin/HelloWorld.java" -d "${DOT_DIRECTORY}/test/java.bin"