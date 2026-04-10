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

getTheme() {
  jq -r '.theme' "${icloud_dot_directory}/data.json" 2>/dev/null
}

getCondition() {
  local condition="$1"
  local target="$2"
  jq -r --arg condition "${condition}" --arg target "${target}" \
    '.conditions[$condition][$target]' "${icloud_dot_directory}/data.json" 2>/dev/null

}