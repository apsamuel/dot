#shellcheck shell=bash
# shellcheck source=/dev/null

# load iterm shell integration
test -e "${HOME}/.iterm2_shell_integration.zsh" && source "${HOME}/.iterm2_shell_integration.zsh"

# load thefuck
command -v thefuck && eval "$(thefuck --enable-experimental-instant-mode --yeah --alias)"

# load zsh autosuggestions
test -e "$HOMEBREW_PREFIX"/share/zsh-autosuggestions/zsh-autosuggestions.zsh && source "$HOMEBREW_PREFIX"/share/zsh-autosuggestions/zsh-autosuggestions.zsh

# load zsh-syntax-highlighting
export ZSH_HIGHLIGHT_HIGHLIGHTERS_DIR="$HOMEBREW_PREFIX"/share/zsh-syntax-highlighting/highlighters
test -e "$HOMEBREW_PREFIX"/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh && source "$HOMEBREW_PREFIX"/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# load "z"
test -e "$HOMEBREW_PREFIX"/etc/profile.d/z.sh && source "$HOMEBREW_PREFIX"/etc/profile.d/z.sh