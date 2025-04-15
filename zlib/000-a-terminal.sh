# shellcheck shell=bash
# shellcheck source=/dev/null

function compileTerminalInfo() {
    infocmp -x xterm-256color
    printf '\t%s\n' 'ncv@,'
} >/tmp/t && tic -x /tmp/t


# fzf
if [ -d "$HOMEBREW_PREFIX/Cellar/fzf" ]; then
    # get currently installed version
    fzf_version="$(brew info fzf --json | jq -r '.[0].linked_keg')"
    # shellcheck disable=SC1090
    source "$HOMEBREW_PREFIX"/Cellar/fzf/"${fzf_version}"/shell/completion.zsh
    # shellcheck disable=SC1090
    # translate bind to bindkey
    source "$HOMEBREW_PREFIX"/Cellar/fzf/"${fzf_version}"/shell/key-bindings.zsh
    # source "$HOMEBREW_PREFIX"/Cellar/fzf/"${fzf_version}"/shell/key-bindings.bash
fi
