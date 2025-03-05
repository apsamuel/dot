#shellcheck shell=bash
# shellcheck source=/dev/null

# load iterm shell integration

# if [[ "${DOT_CONFIGURE_EXTENSIONS}" -eq 0 ]]; then
#     return
# fi

if [[ "${DOT_DEBUG}" -eq 1 ]]; then
    echo "loading: ${DOT_LIBRARY} (${DOT_DIRECTORY})"
fi

if [[ "${DOT_DISABLE_EXTENSIONS}" -eq 1 ]]; then
    if [[ "${DOT_DEBUG}" -eq 1 ]]; then
        echo "extensions are disabled"
    fi
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
if [[ "${DOT_DISABLE_ZSH_AUTOSUGGESTIONS}" -lt 1 ]]; then
    test -e "$HOMEBREW_PREFIX"/share/zsh-autosuggestions/zsh-autosuggestions.zsh && source "$HOMEBREW_PREFIX"/share/zsh-autosuggestions/zsh-autosuggestions.zsh
fi
# test -e "$HOMEBREW_PREFIX"/share/zsh-autosuggestions/zsh-autosuggestions.zsh && source "$HOMEBREW_PREFIX"/share/zsh-autosuggestions/zsh-autosuggestions.zsh

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
