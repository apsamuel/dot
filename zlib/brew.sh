#!/usr/local/bin/bash
set -o nopipefail


# executing in linux
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
# executing in native arm64 mac
elif [[ $OSTYPE == darwin* && "$ARCH" == "arm64" ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
# executing in rosetta or an intel mac
elif [[ $OSTYPE == darwin* && "$ARCH" == "i386" ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
else
    echo "Warning: problem detecting OSTYPE"
fi


function brew::check {
  local input="$1"
  if brew list -1 | grep -q "${input}"; then
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