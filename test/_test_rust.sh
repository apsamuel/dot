#!/bin/bash

function check_toolchain() {
  for tool in rustc cargo rustfmt; do
    if ! command -v "$tool" &>/dev/null; then
      echo "🛑 $tool is not installed or not found in PATH"
      exit 1
    fi
  done
}

function get_versions() {
  echo "Rust version: $(rustc --version)"
  echo "Cargo version: $(cargo --version)"
  echo "Rustfmt version: $(rustfmt --version)"
}

function build_project () {
  if ! rustc "${DOT_DIRECTORY}"/test/main.rs -o "${DOT_DIRECTORY}"/test/rust.bin; then
    echo "🛑 Rust project build failed"
    exit 1
  fi
}

function main () {
  check_toolchain
  get_versions
  build_project
}

main