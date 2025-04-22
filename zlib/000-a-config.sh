#shellcheck shell=bash
#% description: base variables and functions

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