# shellcheck shell=bash
#% note: make brew great again

# set -o nopipefail
# 🕵️ ignore shellcheck warnings about source statements
# shellcheck source=/dev/null
directory=$(dirname "$0")
library=$(basename "$0")

dot::static::logging::loading "${library}" "${directory}"

if [[ "${DOT_DISABLE_BREW}" -eq 1 ]]; then
    dot::static::logging::skip "brew" "disabled"
    return
fi


dot::brew::_initialize() {
if [[ "$OPERATING_SYSTEM" == "linux-gnu"* ]]; then
    if [[ -x /home/linuxbrew/.linuxbrew/bin/brew ]]; then
        eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
    else
        dot::static::logging::error "brew not found at /home/linuxbrew/.linuxbrew/bin/brew"
        return 1
    fi
elif [[ $OPERATING_SYSTEM == "darwin" && "$CPU_ARCHITECTURE" == "arm64" ]]; then
    if [[ -x /opt/homebrew/bin/brew ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    else
        dot::static::logging::error "brew not found at /opt/homebrew/bin/brew"
        return 1
    fi
elif [[ $OPERATING_SYSTEM == "darwin" && ("$CPU_ARCHITECTURE" == "i386" || "$CPU_ARCHITECTURE" == "x86_64") ]]; then
    if [[ -x /usr/local/bin/brew ]]; then
        eval "$(/usr/local/bin/brew shellenv)"
    else
        dot::static::logging::error "brew not found at /usr/local/bin/brew"
        return 1
    fi
else
    dot::static::logging::warn "problem detecting OPERATING_SYSTEM for brew"
fi


}

dot::brew::help() {
  local usage="" purpose=""
  case "${1:-}" in
    ''|help|-h|--help) printf '%s\n' 'Usage: dot::brew <command> [args]' 'Commands: version, installed, install, update, upgrade, list, resolve, dump, recipe, load, parse-line, info, bottle-files' 'Use dot::brew help <command> for details.'; return ;;
    version) usage='<package>'; purpose='Print the installed package version (requires jq).' ;;
    installed) usage='[-t|--type formula|cask] <package>'; purpose='Check installed packages; default formula; returns 1 if absent.' ;;
    install) usage='[-a|--arch arm64|x86_64] <package>'; purpose='Install or reinstall a package; default native architecture. No retries.' ;;
    update|upgrade) usage='[brew-options...]'; purpose='Update package metadata; upgrade also upgrades packages. Backend arguments are forwarded.' ;;
    list) usage='[-t|--type formula|cask]'; purpose='List packages; default formula.' ;;
    resolve|recipe) usage='[-s cloud|dot] [-t formula|cask|mas|all]'; purpose='Resolve or print a Brewfile; defaults cloud/formula. No Brew prerequisite.' ;;
    dump) usage='[-t formula|cask|mas|all] [-o file]'; purpose='Overwrite a Brewfile from installed packages; default repository data/Brewfile for this type and architecture.' ;;
    load) usage='[-t formula|cask|mas|all] [-i file]'; purpose='Install a Brewfile; default repository data/Brewfile for this type and architecture. No retries.' ;;
    parse-line) usage='<line>'; purpose='Print the operation and target from literal Brewfile text. Use family help; no Brew prerequisite.' ;;
    info) usage='<package> [brew-options...]'; purpose='Print package information as JSON.' ;;
    bottle-files) usage='<package>'; purpose='Download a bottle and list its archive paths (requires tar).' ;;
    *) printf 'dot::brew: unknown help topic: %s\n' "$1" >&2; return 1 ;;
  esac
  printf '%s\n' "${purpose}"
  printf 'Usage: dot::brew %s %s\n       dot::brew::%s %s\n' "$1" "${usage}" "$1" "${usage}"
  case "$1" in
    dump|load) printf '%s\n' 'Default: <root>/data/Brewfile[.type].<arch>; formula omits .type. Root: DOT_DIR, then DOT_DIRECTORY, then DOT_ROOT, then $HOME/.dot. Explicit -o/-i overrides the default.' ;;
  esac
  printf '%s\n' 'Options: -h, --help (except literal parse-line). Operations require brew unless noted; help does not.' 'Invalid input returns 1; backend failures are nonzero. No automatic installation of prerequisites.'
  printf 'Example: dot::brew help %s\n' "$1"
}

dot::brew() {
  local action="${1:-help}"
  [[ $# -eq 0 ]] || shift
  case "${action}" in
    help|-h|--help) dot::brew::help "$@" ;;
    version) dot::brew::version "$@" ;;
    installed) dot::brew::installed "$@" ;;
    install) dot::brew::install "$@" ;;
    update) dot::brew::update "$@" ;;
    upgrade) dot::brew::upgrade "$@" ;;
    list) dot::brew::list "$@" ;;
    resolve) dot::brew::resolve "$@" ;;
    dump) dot::brew::dump "$@" ;;
    recipe) dot::brew::recipe "$@" ;;
    load) dot::brew::load "$@" ;;
    parse-line) dot::brew::parse-line "$@" ;;
    info) dot::brew::info "$@" ;;
    bottle-files) dot::brew::bottle-files "$@" ;;
    *) printf 'dot::brew: unknown command: %s\n' "${action}" >&2; return 1 ;;
  esac
}

dot::brew::_require() {
  command -v brew >/dev/null 2>&1 || { printf '%s\n' 'dot::brew: brew is required' >&2; return 1; }
}

function dot::brew::version() {
  case "${1:-}" in -h|--help) dot::brew::help version; return ;; esac
  local input="${1:-}"

  if [[ -z "$input" ]]; then
    echo "No package name provided" >&2
    return 1
  fi
  dot::brew::_require || return $?
  command -v jq >/dev/null 2>&1 || { printf '%s\n' 'dot::brew: jq is required' >&2; return 1; }
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

function dot::brew::installed() {
  local check_type="formula"
  local usage="Usage: dot::brew::installed [-t type] <package>
  -t type   Package type: formula (default), cask"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -t|--type) [[ $# -ge 2 && -n "$2" ]] || { echo "$usage" >&2; return 1; }; check_type="$2"; shift 2 ;;
      -t?*) check_type="${1#-t}"; shift ;;
      -h|--help) dot::brew::help installed; return ;;
      --) shift; break ;;
      -*) echo "$usage" >&2; return 1 ;;
      *) break ;;
    esac
  done

  local input="${1:-}"
  if [[ -z "$input" ]]; then
    echo "No package name provided" >&2
    return 1
  fi

  local list_flag="--formula"
  case "$check_type" in formula|brew|cask) ;; *) echo "$usage" >&2; return 1 ;; esac
  dot::brew::_require || return $?
  [[ "$check_type" == "cask" ]] && list_flag="--cask"

  if brew list -1 "$list_flag" | grep -q "$input" &> /dev/null; then
    echo "Package '$input' is installed"
    return 0
  else
    echo "Package '$input' is not installed" >&2
    return 1
  fi
}

function dot::brew::install() {
  local target_arch=""
  local usage="Usage: dot::brew::install [-a arch] <package>
  -a arch   Architecture: arm64, x86_64 (default: native)"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -a|--arch) [[ $# -ge 2 && -n "$2" ]] || { echo "$usage" >&2; return 1; }; target_arch="$2"; shift 2 ;;
      -a?*) target_arch="${1#-a}"; shift ;;
      -h|--help) dot::brew::help install; return ;;
      --) shift; break ;;
      -*) echo "$usage" >&2; return 1 ;;
      *) break ;;
    esac
  done

  local input="${1:-}"
  if [[ -z "$input" ]]; then
    echo "No package name provided" >&2
    return 1
  fi

  case "$target_arch" in ''|arm64|x86_64) ;; *) echo "$usage" >&2; return 1 ;; esac
  dot::brew::_require || return $?
  if dot::brew::installed "$input" &> /dev/null; then
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

function dot::brew::update() {
  case "${1:-}" in -h|--help) dot::brew::help update; return ;; esac
  dot::brew::_require || return $?
  brew update "$@"
}

function dot::brew::upgrade() {
  case "${1:-}" in -h|--help) dot::brew::help upgrade; return ;; esac
  dot::brew::_require || return $?
  brew update && brew upgrade "$@"
}

function dot::brew::list() {
  local list_type="formula"
  local usage="Usage: dot::brew::list [-t type]
  -t type   List type: formula (default), cask"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -t|--type) [[ $# -ge 2 && -n "$2" ]] || { echo "$usage" >&2; return 1; }; list_type="$2"; shift 2 ;;
      -t?*) list_type="${1#-t}"; shift ;;
      -h|--help) dot::brew::help list; return ;;
      --) shift; break ;;
      *) echo "$usage" >&2; return 1 ;;
    esac
  done
  [[ $# -eq 0 ]] || { echo "$usage" >&2; return 1; }
  dot::brew::_require || return $?

  case "$list_type" in
    formula|brew) brew list -1 --formula ;;
    cask)         brew list -1 --cask ;;
    *)
      echo "Unknown list type: $list_type" >&2
      return 1
      ;;
  esac
}

function dot::brew::resolve() {
  case "${1:-}" in -h|--help) dot::brew::help resolve; return ;; esac
  local source="cloud"
  local resolve_type="formula"
  local usage="Usage: dot::brew::resolve [-s source] [-t type]
  -s source  Source location: cloud (default, \$ICLOUD/dot), dot (\$HOME/.dot/data)
  -t type    Brewfile type: formula (default), cask, mas, all"

  local OPTIND=1 OPTARG="" opt=""
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

function dot::brew::dump() {
  case "${1:-}" in -h|--help) dot::brew::help dump; return ;; esac
  local dump_type="formula"
  local output_file=""
  local usage="Usage: dot::brew::dump [-t type] [-o file]
  -t type   Dump type: formula (default), cask, mas, all
  -o file   Output file path (default: <root>/data/Brewfile[.type].<arch>)
  Root: DOT_DIR, then DOT_DIRECTORY, then DOT_ROOT, then \$HOME/.dot"

  local OPTIND=1 OPTARG="" opt=""
  while getopts "t:o:h" opt; do
    case "$opt" in
      t) dump_type="$OPTARG" ;;
      o) output_file="$OPTARG" ;;
      h) echo "$usage"; return 0 ;;
      *) echo "$usage" >&2; return 1 ;;
    esac
  done

  local arch="${CPU_ARCHITECTURE:-$(uname -m)}"
  local base_dir="${DOT_DIR:-${DOT_DIRECTORY:-${DOT_ROOT:-${HOME}/.dot}}}/data"
  local flags=(--force)

  case "$dump_type" in
    formula|brew)
      flags+=(--formula --taps)
      [[ -z "$output_file" ]] && output_file="${base_dir}/Brewfile.${arch}"
      ;;
    cask)
      flags+=(--cask)
      [[ -z "$output_file" ]] && output_file="${base_dir}/Brewfile.cask.${arch}"
      ;;
    mas)
      flags+=(--mas)
      [[ -z "$output_file" ]] && output_file="${base_dir}/Brewfile.mas.${arch}"
      ;;
    all)
      flags+=(--formula --taps --cask --mas)
      [[ -z "$output_file" ]] && output_file="${base_dir}/Brewfile.all.${arch}"
      ;;
    *)
      echo "Unknown dump type: $dump_type" >&2
      echo "$usage" >&2
      return 1
      ;;
  esac

  dot::brew::_require || return $?
  brew bundle dump "${flags[@]}" --file="${output_file}"
}

function dot::brew::recipe() {
  case "${1:-}" in -h|--help) dot::brew::help recipe; return ;; esac
  local recipe_type="formula"
  local source="cloud"
  local usage="Usage: dot::brew::recipe [-t type] [-s source]
  -t type    Brewfile type: formula (default), cask, mas, all
  -s source  Source: cloud (default), dot"

  local OPTIND=1 OPTARG="" opt=""
  while getopts "t:s:h" opt; do
    case "$opt" in
      t) recipe_type="$OPTARG" ;;
      s) source="$OPTARG" ;;
      h) echo "$usage"; return 0 ;;
      *) echo "$usage" >&2; return 1 ;;
    esac
  done

  local file
  file="$(dot::brew::resolve -s "$source" -t "$recipe_type")" || return 1
  cat "$file"
}

function dot::brew::load() {
  case "${1:-}" in -h|--help) dot::brew::help load; return ;; esac
  local load_type="formula"
  local input_file=""
  local usage="Usage: dot::brew::load [-t type] [-i file]
  -t type   Load type: formula (default), cask, mas, all
  -i file   Input Brewfile path (default: <root>/data/Brewfile[.type].<arch>)
  Root: DOT_DIR, then DOT_DIRECTORY, then DOT_ROOT, then \$HOME/.dot"

  local OPTIND=1 OPTARG="" opt=""
  while getopts "t:i:h" opt; do
    case "$opt" in
      t) load_type="$OPTARG" ;;
      i) input_file="$OPTARG" ;;
      h) echo "$usage"; return 0 ;;
      *) echo "$usage" >&2; return 1 ;;
    esac
  done

  local arch="${CPU_ARCHITECTURE:-$(uname -m)}"

  local base_dir="${DOT_DIR:-${DOT_DIRECTORY:-${DOT_ROOT:-${HOME}/.dot}}}/data"
  case "$load_type" in
    formula|brew)
      [[ -z "$input_file" ]] && input_file="${base_dir}/Brewfile.${arch}"
      ;;
    cask)
      if [[ "$OPERATING_SYSTEM" == "darwin" && "$CPU_ARCHITECTURE" == "i386" ]]; then
        echo "Skipping cask install on i386 architecture"
        return
      fi
      [[ -z "$input_file" ]] && input_file="${base_dir}/Brewfile.cask.${arch}"
      ;;
    mas)
      [[ -z "$input_file" ]] && input_file="${base_dir}/Brewfile.mas.${arch}"
      ;;
    all)
      [[ -z "$input_file" ]] && input_file="${base_dir}/Brewfile.all.${arch}"
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

  dot::brew::_require || return $?
  brew bundle install --file="${input_file}"
}

function dot::brew::parse-line() {
  local line="${1:-}"
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

function dot::brew::info() {
  case "${1:-}" in -h|--help) dot::brew::help info; return ;; esac
  if [[ -z "${1:-}" ]]; then
    echo "No package name provided" >&2
    return 1
  fi
  dot::brew::_require || return $?
  brew info --json "$@"
}

function dot::brew::bottle-files() {
  case "${1:-}" in -h|--help) dot::brew::help bottle-files; return ;; esac
  local input="${1:-}"
  if [[ -z "$input" ]]; then
    echo "No package name provided" >&2
    return 1
  fi
  dot::brew::_require || return $?
  if ! brew fetch --formula "$input"; then
    echo "Failed to fetch bottle for '$input'" >&2
    return 1
  fi
  local cached
  cached="$(brew --cache --formula "$input")" || return $?
  if [[ ! -f "$cached" ]]; then
    echo "Cached bottle not found for '$input'" >&2
    return 1
  fi
  tar tf "$cached"
}

dot::brew::_initialize
