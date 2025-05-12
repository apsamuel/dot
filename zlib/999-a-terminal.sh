# shellcheck shell=bash
# shellcheck source=/dev/null

function compileTerminalInfo() {
    infocmp -x xterm-256color
    printf '\t%s\n' 'ncv@,'
} >/tmp/t && tic -x /tmp/t

# fzf
function configureFzf() {
    if  command -v fzf  >/dev/null 2>&1; then
        # get currently installed version
        # echo "fzf version: $(brew info fzf --json | jq -r '.[0].linked_keg')"
        fzf_version="$(brew info fzf --json | jq -r '.[0].linked_keg')"
        # shellcheck disable=SC1090
        . "$HOMEBREW_PREFIX"/Cellar/fzf/"${fzf_version}"/shell/completion.zsh || echo "error loading fzf completion"

        # translate bind to bindkey
        . "$HOMEBREW_PREFIX"/Cellar/fzf/"${fzf_version}"/shell/key-bindings.zsh || echo "error loading fzf key bindings"
        # source "$HOMEBREW_PREFIX"/Cellar/fzf/"${fzf_version}"/shell/key-bindings.bash
    fi
    return 0
}

if  command -v fzf  >/dev/null 2>&1; then
    # get currently installed version
    # echo "fzf version: $(brew info fzf --json | jq -r '.[0].linked_keg')"
    fzf_version="$(brew info fzf --json | jq -r '.[0].linked_keg')"
    # shellcheck disable=SC1090
    . "$HOMEBREW_PREFIX"/Cellar/fzf/"${fzf_version}"/shell/completion.zsh || echo "error loading fzf completion"

    # translate bind to bindkey
    . "$HOMEBREW_PREFIX"/Cellar/fzf/"${fzf_version}"/shell/key-bindings.zsh || echo "error loading fzf key bindings"
    # source "$HOMEBREW_PREFIX"/Cellar/fzf/"${fzf_version}"/shell/key-bindings.bash
fi
