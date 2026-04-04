# shellcheck shell=bash
# 🕵️ ignore shellcheck warnings about source statements
# shellcheck source=/dev/null

directory=$(dirname "$0")
library=$(basename "$0")

if [[ "${DOT_DEBUG}" -eq 1 ]]; then
    echo "loading: ${library} (${directory})"
fi

if [[ -x /Applications/iTerm.app/Contents/MacOS/iTerm2 ]]; then
  [[ "$TERM_PROGRAM" == "iTerm.app" ]] && \
  # only source the initialization file if it present
  if [[ -f $HOME/.iterm2_shell_integration.zsh ]]; then
    . "$HOME/.iterm2_shell_integration.zsh"
  fi
fi