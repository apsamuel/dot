#shellcheck shell=bash
#% description: base variables and functions

# Prevent pagers from switching to alternate screen buffer.
# -R: pass ANSI colors through  -X: skip terminal init/deinit (no alt buffer)  -F: quit if output fits on one screen
export LESS="-R -X -F"
export BAT_PAGER="less -R -X -F"
export GIT_PAGER="less -R -X -F"
export MANPAGER="less -R -X -F"

icloud_directory="${HOME}/Library/Mobile Documents/com~apple~CloudDocs"
icloud_dot_directory="${icloud_directory}/dot"

# Resolve config path: prefer local repo copy of zsh.yaml, fall back to iCloud copy
_dot_config_path="${DOT_SHELL_DATA:-${HOME}/.dot/data/zsh.yaml}"
if [[ ! -f "${_dot_config_path}" ]] && [[ -f "${icloud_dot_directory}/shell/zsh/zsh.yaml" ]]; then
    _dot_config_path="${icloud_dot_directory}/shell/zsh/zsh.yaml"
fi
export DOT_SHELL_DATA="${_dot_config_path}"


dot::config::help() {
  local topic="${1:-}" arguments="" description=""
  case "${topic}" in
    ''|help|-h|--help)
      printf '%s\n' 'Usage: dot::config <command> [arguments]' 'Commands: get, theme, condition, help' 'Example: dot::config help condition'
      return 0 ;;
    get) description='Print the full shell configuration.' ;;
    theme) description='Print the configured theme.' ;;
    condition) arguments='CONDITION TARGET'; description='Print .conditions.CONDITION.TARGET. The two operands retain their existing yq path syntax.' ;;
    *) printf 'dot::config: unknown help topic: %s\n' "${topic}" >&2; return 1 ;;
  esac
  printf 'Usage: dot::config %s %s\n       dot::config::%s %s\n%s\n' "${topic}" "${arguments}" "${topic}" "${arguments}" "${description}"
  printf '%s\n' 'Options: -h, --help (alone). Help does not read configuration or run yq.' 'Queries require yq and use the configuration path selected when this module loaded.' 'Returns 0 on success, 1 on usage/missing dependency; query failures retain the yq status.' 'These commands are read-only. Example: dot::config condition network home'
}

dot::config() {
  local action="${1:-help}"
  [[ $# -eq 0 ]] || shift
  case "${action}" in
    help|-h|--help) dot::config::help "$@" ;;
    get) dot::config::get "$@" ;;
    theme) dot::config::theme "$@" ;;
    condition) dot::config::condition "$@" ;;
    *) printf 'dot::config: unknown command: %s\n' "${action}" >&2; return 1 ;;
  esac
}

dot::config::_query() {
  command -v yq >/dev/null 2>&1 || { printf '%s\n' 'dot::config: yq is required' >&2; return 1; }
  yq "$1" "${_dot_config_path}"
}

dot::config::get() {
  case "${1:-}" in -h|--help) dot::config::help get; return ;; esac
  [[ $# -eq 0 ]] || { dot::config::help get >&2; return 1; }
  dot::config::_query '.'
}

dot::config::theme() {
  case "${1:-}" in -h|--help) dot::config::help theme; return ;; esac
  [[ $# -eq 0 ]] || { dot::config::help theme >&2; return 1; }
  dot::config::_query '.theme'
}

dot::config::condition() {
  if [[ $# -eq 1 ]]; then
    case "$1" in -h|--help) dot::config::help condition; return ;; esac
  fi
  [[ $# -eq 2 && -n "${1:-}" && -n "${2:-}" ]] || { dot::config::help condition >&2; return 1; }
  dot::config::_query ".conditions.$1.$2"
}
