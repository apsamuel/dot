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


getConfig() {
  yq '.' "${_dot_config_path}" 2>/dev/null
}

getTheme() {
  yq '.theme' "${_dot_config_path}" 2>/dev/null
}

getCondition() {
  local condition="$1"
  local target="$2"
  yq ".conditions.${condition}.${target}" "${_dot_config_path}" 2>/dev/null

}
