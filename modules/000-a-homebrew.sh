# shellcheck shell=bash
#% note: make brew great again

# set -o nopipefail
# 🕵️ ignore shellcheck warnings about source statements
# shellcheck source=/dev/null
directory=$(dirname "$0")
library=$(basename "$0")

dot::loading "${library}" "${directory}"

if [[ "${DOT_DISABLE_BREW}" -eq 1 ]]; then
    dot::skip "brew" "disabled"
    return
fi


if [[ "$OPERATING_SYSTEM" == "linux-gnu"* ]]; then
    if [[ -x /home/linuxbrew/.linuxbrew/bin/brew ]]; then
        eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
    else
        dot::error "brew not found at /home/linuxbrew/.linuxbrew/bin/brew"
        return 1
    fi
elif [[ $OPERATING_SYSTEM == "darwin" && "$CPU_ARCHITECTURE" == "arm64" ]]; then
    if [[ -x /opt/homebrew/bin/brew ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    else
        dot::error "brew not found at /opt/homebrew/bin/brew"
        return 1
    fi
elif [[ $OPERATING_SYSTEM == "darwin" && ("$CPU_ARCHITECTURE" == "i386" || "$CPU_ARCHITECTURE" == "x86_64") ]]; then
    if [[ -x /usr/local/bin/brew ]]; then
        eval "$(/usr/local/bin/brew shellenv)"
    else
        dot::error "brew not found at /usr/local/bin/brew"
        return 1
    fi
else
    dot::warn "problem detecting OPERATING_SYSTEM for brew"
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

function brewResolveBrewfile() {
  local arch="${CPU_ARCHITECTURE:-$(uname -m)}"
  local file="${1:-${ICLOUD}/dot/Brewfile.${arch}}"
  if [[ -f "$file" ]]; then
    echo "$file"
    return 0
  else
    echo "Brewfile not found at $file"
    return 1
  fi
}

function brewDump() {
    local arch="${CPU_ARCHITECTURE:-$(uname -m)}"
    local file="${1:-${ICLOUD}/dot/Brewfile.${arch}}"
    brew bundle dump --describe --brews --taps --no-upgrade --force --file="${file}"
}

function brewDumpMas () {
  local arch="${CPU_ARCHITECTURE:-$(uname -m)}"
  local file="${1:-${ICLOUD}/dot/Brewfile.mas.${arch}}"
  brew bundle dump --describe --mas --no-upgrade --force --file="${file}"
}

function brewDumpCask () {
  local arch="${CPU_ARCHITECTURE:-$(uname -m)}"
  local file="${1:-${ICLOUD}/dot/Brewfile.cask.${arch}}"
  brew bundle dump --describe --casks --no-upgrade --force --file="${file}"
}

function brewRecipe () {
  cat "${1:-${ICLOUD}/dot/Brewfile}"
}

function brewLoad () {
  local arch="${CPU_ARCHITECTURE:-$(uname -m)}"
  local file="${1:-${ICLOUD}/dot/Brewfile.${arch}}"
  brew bundle install --file="${file}"
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

function brewLoadMas () {
  local arch="${CPU_ARCHITECTURE:-$(uname -m)}"
  local file="${1:-${ICLOUD}/dot/Brewfile.mas.${arch}}"
  brew bundle install --mas --file="${file}"
}

function brewLoadCask () {
  local arch="${CPU_ARCHITECTURE:-$(uname -m)}"
  # casks should only be installed in native architecture (no rosetta)
  if [[ "$OPERATING_SYSTEM" == "darwin" && "$CPU_ARCHITECTURE" == "i386" ]]; then
    echo "Skipping cask install on i386 architecture"
    return
  fi
  local file="${1:-${ICLOUD}/dot/Brewfile.cask.${arch}}"
  brew bundle install --cask --file="${file}"
}

function brewJson () {
    brew info --json "$@"
}

function brewListUninstalledFiles() {
  local input="$1"
  if [[ -z "$input" ]]; then
    echo "No package name provided"
    return 1
  fi
  if ! brew fetch --formula "$input"; then
    echo "Failed to fetch bottle for '$input'"
    return 1
  fi
  local cached
  cached="$(brew --cache --formula "$input")"
  if [[ ! -f "$cached" ]]; then
    echo "Cached bottle not found for '$input'"
    return 1
  fi
  tar tf "$cached"
}
