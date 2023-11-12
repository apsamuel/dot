#!/usr/local/bin/bash

# command zsh -c 'emulate bash'
# function hello () {
#     echo "hello world"
# }

function brew::check {
  if brew list -1 | grep -q "$1"; then
    echo "Package '$1' is installed"
  else
    echo "Package '$1' is not installed"
    return 1
  fi
}

function brew::install () {
  if brew::check "$1"; then
    echo "Reinstalling '$1'"
    brew reinstall "$1"
  else
    echo "Installing '$1'"
    brew install "$1"
  fi
}

function brew::refresh () {
    brew update
}

function brew::upgrade () {
    brew update && brew upgrade
}

function brew::list () {
    brew list -1
}

function brew::cask::list () {
    brew list --cask -1
}

function brew::cask::check () {
  if brew list --cask -1 | grep -q "$1"; then
    echo "Package '$1' is installed"
  else
    echo "Package '$1' is not installed"
    return 1
  fi
}

function brew::dump () {
    brew bundle dump --force --file="${1:-/tmp/Brewfile}"
}

function brew::load () {
    brew bundle install --file="${1:-/tmp/Brewfile}"
}