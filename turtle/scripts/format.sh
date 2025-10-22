#! /usr/bin/env bash

# Format Turtle source files
find . -name "*.rs" -print -exec rustfmt {} \;
# rustfmt ./src/main.rs