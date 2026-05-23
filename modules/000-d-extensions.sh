#shellcheck shell=bash
# shellcheck source=/dev/null

directory=$(dirname "$0")
library=$(basename "$0")

dot::static::logging::loading "${library}" "${directory}"


if [[ "${DOT_DISABLE_EXTENSIONS}" -eq 1 ]]; then
    dot::static::logging::skip "extensions" "disabled"
    return
fi

export ITERM2_SQUELCH_MARK=1
export ITERM_ENABLE_SHELL_INTEGRATION_WITH_TMUX=1
test -e "${HOME}/.iterm2_shell_integration.zsh" && source "${HOME}/.iterm2_shell_integration.zsh"

# load thefuck
# conditionally enable thefuck
if [[ "${DOT_DISABLE_THEFUCK}" -lt 1 ]]; then
    command -v thefuck >/dev/null 2>&1 && eval "$(thefuck --enable-experimental-instant-mode --yeah --alias)"
fi


# load zsh autosuggestions
# NOTE: zsh-autosuggestions is now loaded by oh-my-zsh via the custom plugin
# submodule in vendor/oh-my-zsh. The brew-installed version is no longer needed.
# if [[ "${DOT_DISABLE_ZSH_AUTOSUGGESTIONS}" -lt 1 ]]; then
#     test -e "$HOMEBREW_PREFIX"/share/zsh-autosuggestions/zsh-autosuggestions.zsh && source "$HOMEBREW_PREFIX"/share/zsh-autosuggestions/zsh-autosuggestions.zsh
# fi

# load zsh-syntax-highlighting
if [[ "${DOT_DISABLE_ZSH_SYNTAX_HIGHLIGHTING}" -lt 1 ]]; then
  export ZSH_HIGHLIGHT_HIGHLIGHTERS_DIR="$HOMEBREW_PREFIX"/share/zsh-syntax-highlighting/highlighters
  test -e "$HOMEBREW_PREFIX"/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh && source "$HOMEBREW_PREFIX"/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
fi

# load "z"
if [[ "${DOT_DISABLE_Z}" -lt 1 ]]; then
    test -e "$HOMEBREW_PREFIX"/etc/profile.d/z.sh && source "$HOMEBREW_PREFIX"/etc/profile.d/z.sh
fi
# test -e "$HOMEBREW_PREFIX"/etc/profile.d/z.sh && source "$HOMEBREW_PREFIX"/etc/profile.d/z.sh
