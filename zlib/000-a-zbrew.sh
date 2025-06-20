# shellcheck shell=bash
#% note: make brew great again

# set -o nopipefail
# 🕵️ ignore shellcheck warnings about source statements
# shellcheck source=/dev/null
directory=$(dirname "$0")
library=$(basename "$0")

if [[ "${DOT_DEBUG}" -eq 1 ]]; then
    echo "loading: ${library} (${directory})"
fi

if [[ "${DOT_DISABLE_BREW}" -eq 1 ]]; then
    if [[ "${DOT_DEBUG}" -eq 1 ]]; then
        echo "brew is disabled"
    fi
    return
fi

if [[ "$OPERATING_SYSTEM" == "linux-gnu"* ]]; then
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
elif [[ $OPERATING_SYSTEM == "darwin" && "$CPU_ARCHITECTURE" == "arm64" ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ $OPERATING_SYSTEM == "darwin" && ("$CPU_ARCHITECTURE" == "i386" || "$CPU_ARCHITECTURE" == "x86_64") ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
else
    echo "Warning: problem detecting OPERATING_SYSTEM!"
fi

function brewInstalledVersion() {
  local input="$1"

  if [[ -z "$input" ]]; then
    echo "No package name provided"
    return 1
  fi
  if brew list -1 | grep  "${input}" &> /dev/null; then
    pkg_version="$(brew info "$input" --json | jq -r '.[0].linked_keg' )"
    if [[ -z "$pkg_version" ]]; then
      echo "Package '$1' is installed, but version could not be determined"
      return 1
    else
      echo "$pkg_version"
      return 0
    fi
  else
    echo "Package '$1' is not installed"
    return 1
  fi
}

function brewCheckInstalled {
  local input="$1"
  if [[ -z "$input" ]]; then
    echo "No package name provided"
    return 1
  fi
  if brew list -1 | grep  "${input}" &> /dev/null; then
    echo "Package '$1' is installed"
  else
    echo "Package '$1' is not installed"
    return 1
  fi
}

function brewInstall() {
  if [[ -z "$input" ]]; then
    echo "No package name provided"
    return 1
  fi
  if brewCheckInstalled "$1"; then
    echo "Reinstalling '$1'"
    brew reinstall "$1"
  else
    echo "Installing '$1'"
    brew install "$1"
  fi
}

function brewInstallArm () {
  if [[ -z "$input" ]]; then
    echo "No package name provided"
    return 1
  fi
  arch -arm64 brew install "$1"
}

function brewInstallIntel () {
  if [[ -z "$input" ]]; then
    echo "No package name provided"
    return 1
  fi
  arch -x86_64 brew install "$1"
}

function brewUpdate() {
    brew update
}

function brewUpgrade () {
    brew update && brew upgrade
}

function brewList () {
    brew list -1 --formula
}

function brewCaskList () {
    brew list --cask -1
}

function brewCheckCask () {
  if [[ -z "$input" ]]; then
    echo "No package name provided"
    return 1
  fi
  if brew list --cask -1 | grep  "$1" &> /dev/null; then
    echo "Package '$1' is installed"
  else
    echo "Package '$1' is not installed"
    return 1
  fi
}

function brewDump() {
    brew bundle dump --describe --brews --taps --no-upgrade --force --file="${1:-${ICLOUD}/dot/Brewfile}"
}

function brewDumpMas () {
    brew bundle dump --describe --mas --no-upgrade --force --file="${1:-${ICLOUD}/dot/Brewfile.mas}"
}

function brewDumpCask () {
    brew bundle dump --describe --casks --no-upgrade --force --file="${1:-${ICLOUD}/dot/Brewfile.cask}"
}

function brewRecipe () {
  cat "${1:-${ICLOUD}/dot/Brewfile}"
}

function brewLoad () {
    brew bundle install --file="${1:-${ICLOUD}/dot/Brewfile}"
}

function parseLine() {
  ## if tap, the second word is the name of the tap
  ## if brew install, the second word is the name of the package

  local line="$1"

  local operation
  local target
  # parse the line into two parameters

  operation="$(echo "$line" | awk '{print $1}')"
  target="$(echo "$line" | awk '{print $2}')"
  echo "$operation" "$target"
}

function brewLoad.v2() {
  ## list each line of the Brewfile
  ## either configure a tap, or install a package
  ## configure an exclude for the brewfile


  parseLine "$@"
  while IFS= read -r line; do
    if [[ "$line" == *"tap"* ]]; then
      echo "tapping: $line"
      eval "$line"
    elif [[ "$line" == *"brew"* ]]; then
      echo "installing: $line"
      eval "$line"
    fi
  done < "${1:-${ICLOUD}/dot/Brewfile}"
}

function brewLoadMas () {
    brew bundle install --mas --file="${1:-${ICLOUD}/dot/Brewfile.mas}"
}

function brewLoadCask () {
    brew bundle install --cask --file="${1:-${ICLOUD}/dot/Brewfile.cask}"
}

function brewJson () {
    brew info --json "$@"
}