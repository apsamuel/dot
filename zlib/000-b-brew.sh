# shellcheck shell=bash
#% note: make brew great again

# set -o nopipefail
# 🕵️ ignore shellcheck warnings about source statements
# shellcheck source=/dev/null


if [[ "${DOT_DEBUG}" -eq 1 ]]; then
    echo "loading: ${DOT_LIBRARY} (${DOT_DIRECTORY})"
fi

if [[ "${DOT_DISABLE_BREW}" -eq 1 ]]; then
    if [[ "${DOT_DEBUG}" -eq 1 ]]; then
        echo "brew is disabled"
    fi
    return
fi

if [[ "$OPERATING_SYSTEM" == "linux-gnu"* ]]; then
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
# executing in native arm64 mac
elif [[ $OPERATING_SYSTEM == "darwin" && "$CPU_ARCHITECTURE" == "arm64" ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
# executing in rosetta or on an intel mac
elif [[ $OPERATING_SYSTEM == "darwin" && ("$CPU_ARCHITECTURE" == "i386" || "$CPU_ARCHITECTURE" == "x86_64") ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
else
    echo "Warning: problem detecting OPERATING_SYSTEM!"
fi


function brew::check {
  local input="$1"
  if brew list -1 | grep  "${input}" &> /dev/null; then
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

function brew::install::arm () {
  arch -arm64 brew install "$1"
}

function brew::install::intel () {
  arch -x86_64 brew install "$1"
}

function brew::update () {
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
  if brew list --cask -1 | grep  "$1" &> /dev/null; then
    echo "Package '$1' is installed"
  else
    echo "Package '$1' is not installed"
    return 1
  fi
}

function brew::dump () {
    #local backend=""
    brew bundle dump --describe --casks --brews --taps --no-upgrade --force --file="${1:-${ICLOUD}/dot/Brewfile}"
}

function brew::dump::mas () {
    brew bundle dump --describe --mas --no-upgrade --force --file="${1:-${ICLOUD}/dot/Brewfile.mas}"
}

function brew::recipe () {
  cat "${1:-${ICLOUD}/dot/Brewfile}"
}

function brew::load () {
    brew bundle install --file="${1:-${ICLOUD}/dot/Brewfile}"
}

function brew::load::mas () {
    brew bundle install --mas --file="${1:-${ICLOUD}/dot/Brewfile.mas}"
}

function brew::package::query () {
    brew info --json "$@"
}