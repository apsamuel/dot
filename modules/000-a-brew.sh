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


function brew::version() {
  local input="$1"

  if [[ -z "$input" ]]; then
    echo "No package name provided" >&2
    return 1
  fi
  if brew list -1 | grep -q "${input}" &> /dev/null; then
    local pkg_version
    pkg_version="$(brew info "$input" --json | jq -r '.[0].linked_keg')"
    if [[ -z "$pkg_version" || "$pkg_version" == "null" ]]; then
      echo "Package '$input' is installed, but version could not be determined" >&2
      return 1
    else
      echo "$pkg_version"
      return 0
    fi
  else
    echo "Package '$input' is not installed" >&2
    return 1
  fi
}

function brew::installed() {
  local check_type="formula"
  local usage="Usage: brew::installed [-t type] <package>
  -t type   Package type: formula (default), cask"

  local OPTIND=1
  while getopts "t:h" opt; do
    case "$opt" in
      t) check_type="$OPTARG" ;;
      h) echo "$usage"; return 0 ;;
      *) echo "$usage" >&2; return 1 ;;
    esac
  done
  shift $((OPTIND - 1))

  local input="$1"
  if [[ -z "$input" ]]; then
    echo "No package name provided" >&2
    return 1
  fi

  local list_flag="--formula"
  [[ "$check_type" == "cask" ]] && list_flag="--cask"

  if brew list -1 "$list_flag" | grep -q "$input" &> /dev/null; then
    echo "Package '$input' is installed"
    return 0
  else
    echo "Package '$input' is not installed" >&2
    return 1
  fi
}

function brew::install() {
  local target_arch=""
  local usage="Usage: brew::install [-a arch] <package>
  -a arch   Architecture: arm64, x86_64 (default: native)"

  local OPTIND=1
  while getopts "a:h" opt; do
    case "$opt" in
      a) target_arch="$OPTARG" ;;
      h) echo "$usage"; return 0 ;;
      *) echo "$usage" >&2; return 1 ;;
    esac
  done
  shift $((OPTIND - 1))

  local input="$1"
  if [[ -z "$input" ]]; then
    echo "No package name provided" >&2
    return 1
  fi

  if brew::installed "$input" &> /dev/null; then
    echo "Reinstalling '$input'"
    if [[ -n "$target_arch" ]]; then
      arch "-${target_arch}" brew reinstall "$input"
    else
      brew reinstall "$input"
    fi
  else
    echo "Installing '$input'"
    if [[ -n "$target_arch" ]]; then
      arch "-${target_arch}" brew install "$input"
    else
      brew install "$input"
    fi
  fi
}

function brew::update() {
  brew update "$@"
}

function brew::upgrade() {
  brew update && brew upgrade "$@"
}

function brew::list() {
  local list_type="formula"
  local usage="Usage: brew::list [-t type]
  -t type   List type: formula (default), cask"

  local OPTIND=1
  while getopts "t:h" opt; do
    case "$opt" in
      t) list_type="$OPTARG" ;;
      h) echo "$usage"; return 0 ;;
      *) echo "$usage" >&2; return 1 ;;
    esac
  done

  case "$list_type" in
    formula|brew) brew list -1 --formula ;;
    cask)         brew list -1 --cask ;;
    *)
      echo "Unknown list type: $list_type" >&2
      return 1
      ;;
  esac
}

function brew::resolve() {
  local source="cloud"
  local resolve_type="formula"
  local usage="Usage: brew::resolve [-s source] [-t type]
  -s source  Source location: cloud (default, \$ICLOUD/dot), dot (\$HOME/.dot/data)
  -t type    Brewfile type: formula (default), cask, mas, all"

  local OPTIND=1
  while getopts "s:t:h" opt; do
    case "$opt" in
      s) source="$OPTARG" ;;
      t) resolve_type="$OPTARG" ;;
      h) echo "$usage"; return 0 ;;
      *) echo "$usage" >&2; return 1 ;;
    esac
  done

  local arch="${CPU_ARCHITECTURE:-$(uname -m)}"
  local base_dir=""

  case "$source" in
    cloud|c)
      base_dir="${ICLOUD}/dot"
      ;;
    dot|d)
      base_dir="${HOME}/.dot/data"
      ;;
    *)
      echo "Unknown source: $source (use cloud or dot)" >&2
      return 1
      ;;
  esac

  local file=""
  case "$resolve_type" in
    formula|brew)
      file="${base_dir}/Brewfile.${arch}"
      ;;
    cask)
      file="${base_dir}/Brewfile.cask.${arch}"
      ;;
    mas)
      file="${base_dir}/Brewfile.mas.${arch}"
      ;;
    all)
      file="${base_dir}/Brewfile.all.${arch}"
      ;;
    *)
      echo "Unknown type: $resolve_type" >&2
      echo "$usage" >&2
      return 1
      ;;
  esac

  if [[ -f "$file" ]]; then
    echo "$file"
    return 0
  else
    echo "Brewfile not found at $file" >&2
    return 1
  fi
}

function brew::dump() {
  local dump_type="formula"
  local output_file=""
  local usage="Usage: brew::dump [-t type] [-o file]
  -t type   Dump type: formula (default), cask, mas, all
  -o file   Output file path (default: \${ICLOUD}/dot/Brewfile[.type].\${arch})"

  local OPTIND=1
  while getopts "t:o:h" opt; do
    case "$opt" in
      t) dump_type="$OPTARG" ;;
      o) output_file="$OPTARG" ;;
      h) echo "$usage"; return 0 ;;
      *) echo "$usage" >&2; return 1 ;;
    esac
  done

  local arch="${CPU_ARCHITECTURE:-$(uname -m)}"
  local flags=(--describe --force)

  case "$dump_type" in
    formula|brew)
      flags+=(--formula --taps)
      [[ -z "$output_file" ]] && output_file="${ICLOUD}/dot/Brewfile.${arch}"
      ;;
    cask)
      flags+=(--cask)
      [[ -z "$output_file" ]] && output_file="${ICLOUD}/dot/Brewfile.cask.${arch}"
      ;;
    mas)
      flags+=(--mas)
      [[ -z "$output_file" ]] && output_file="${ICLOUD}/dot/Brewfile.mas.${arch}"
      ;;
    all)
      flags+=(--formula --taps --cask --mas)
      [[ -z "$output_file" ]] && output_file="${ICLOUD}/dot/Brewfile.all.${arch}"
      ;;
    *)
      echo "Unknown dump type: $dump_type" >&2
      echo "$usage" >&2
      return 1
      ;;
  esac

  brew bundle dump "${flags[@]}" --file="${output_file}"
}

function brew::recipe() {
  local recipe_type="formula"
  local source="cloud"
  local usage="Usage: brew::recipe [-t type] [-s source]
  -t type    Brewfile type: formula (default), cask, mas, all
  -s source  Source: cloud (default), dot"

  local OPTIND=1
  while getopts "t:s:h" opt; do
    case "$opt" in
      t) recipe_type="$OPTARG" ;;
      s) source="$OPTARG" ;;
      h) echo "$usage"; return 0 ;;
      *) echo "$usage" >&2; return 1 ;;
    esac
  done

  local file
  file="$(brew::resolve -s "$source" -t "$recipe_type")" || return 1
  cat "$file"
}

function brew::load() {
  local load_type="formula"
  local input_file=""
  local usage="Usage: brew::load [-t type] [-i file]
  -t type   Load type: formula (default), cask, mas, all
  -i file   Input Brewfile path (default: \${ICLOUD}/dot/Brewfile[.type].\${arch})"

  local OPTIND=1
  while getopts "t:i:h" opt; do
    case "$opt" in
      t) load_type="$OPTARG" ;;
      i) input_file="$OPTARG" ;;
      h) echo "$usage"; return 0 ;;
      *) echo "$usage" >&2; return 1 ;;
    esac
  done

  local arch="${CPU_ARCHITECTURE:-$(uname -m)}"

  case "$load_type" in
    formula|brew)
      [[ -z "$input_file" ]] && input_file="${ICLOUD}/dot/Brewfile.${arch}"
      ;;
    cask)
      if [[ "$OPERATING_SYSTEM" == "darwin" && "$CPU_ARCHITECTURE" == "i386" ]]; then
        echo "Skipping cask install on i386 architecture"
        return
      fi
      [[ -z "$input_file" ]] && input_file="${ICLOUD}/dot/Brewfile.cask.${arch}"
      ;;
    mas)
      [[ -z "$input_file" ]] && input_file="${ICLOUD}/dot/Brewfile.mas.${arch}"
      ;;
    all)
      [[ -z "$input_file" ]] && input_file="${ICLOUD}/dot/Brewfile.all.${arch}"
      ;;
    *)
      echo "Unknown load type: $load_type" >&2
      echo "$usage" >&2
      return 1
      ;;
  esac

  if [[ ! -f "$input_file" ]]; then
    echo "Brewfile not found: $input_file" >&2
    return 1
  fi

  brew bundle install --file="${input_file}"
}

function brew::parse-line() {
  local line="$1"
  if [[ -z "$line" ]]; then
    echo "No line provided" >&2
    return 1
  fi

  local operation
  local target
  operation="$(echo "$line" | awk '{print $1}')"
  target="$(echo "$line" | awk '{print $2}')"
  echo "$operation" "$target"
}

function brew::info() {
  if [[ -z "$1" ]]; then
    echo "No package name provided" >&2
    return 1
  fi
  brew info --json "$@"
}

function brew::bottle-files() {
  local input="$1"
  if [[ -z "$input" ]]; then
    echo "No package name provided" >&2
    return 1
  fi
  if ! brew fetch --formula "$input"; then
    echo "Failed to fetch bottle for '$input'" >&2
    return 1
  fi
  local cached
  cached="$(brew --cache --formula "$input")"
  if [[ ! -f "$cached" ]]; then
    echo "Cached bottle not found for '$input'" >&2
    return 1
  fi
  tar tf "$cached"
}
