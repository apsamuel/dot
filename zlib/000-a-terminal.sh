#shellcheck shell=bash
# shellcheck source=/dev/null

function compileTerminalInfo() {
    infocmp -x xterm-256color
    printf '\t%s\n' 'ncv@,'
} >/tmp/t && tic -x /tmp/t


# fzf
if [ -d "$HOMEBREW_PREFIX/Cellar/fzf" ]; then
    # get currently installed version
    fzf_version="$(brew info fzf --json | jq -r '.[0].versions.stable')"
    # shellcheck disable=SC1090
    source "$HOMEBREW_PREFIX"/Cellar/fzf/"${fzf_version}"/shell/completion.bash
    # shellcheck disable=SC1090
    source "$HOMEBREW_PREFIX"/Cellar/fzf/"${fzf_version}"/shell/key-bindings.bash
fi
# source "$HOMEBREW_PREFIX"/Cellar/fzf/"$(brew info fzf --json | jq -r '.[0].versions.stable')"/shell/completion.zsh
# source "$HOMEBREW_PREFIX"/Cellar/fzf/"$(brew info fzf --json | jq -r '.[0].versions.stable')"/shell/key-bindings.zsh