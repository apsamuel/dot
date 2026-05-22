# shellcheck shell=bash
# shellcheck source=/dev/null

function compileTerminalInfo() {
    infocmp -x xterm-256color
    printf '\t%s\n' 'ncv@,'
} >/tmp/t && tic -x /tmp/t

# fzf
function configureFzf() {
    # fzf key-bindings install widgets that can pop the alternate screen
    # buffer for previews. Skip entirely in non-interactive / Copilot
    # terminals where DOT_INTERACTIVE=0 — there's no human at the keyboard
    # to use CTRL-R / CTRL-T / ALT-C anyway.
    if [[ "${DOT_INTERACTIVE}" -eq 0 ]]; then
        return 0
    fi
    if  command -v fzf  >/dev/null 2>&1; then
        # get currently installed version
        # echo "fzf version: $(brew info fzf --json | jq -r '.[0].linked_keg')"
        fzf_version="$(brew info fzf --json | jq -r '.[0].linked_keg')"
        # shellcheck disable=SC1090
        . "$HOMEBREW_PREFIX"/Cellar/fzf/"${fzf_version}"/shell/completion.zsh || dot::warn "error loading fzf completion"

        # translate bind to bindkey
        . "$HOMEBREW_PREFIX"/Cellar/fzf/"${fzf_version}"/shell/key-bindings.zsh || dot::warn "error loading fzf key bindings"
        # source "$HOMEBREW_PREFIX"/Cellar/fzf/"${fzf_version}"/shell/key-bindings.bash
    fi
    return 0
}

if [[ "${DOT_INTERACTIVE}" -ne 0 ]] && command -v fzf >/dev/null 2>&1; then
    # get currently installed version
    # echo "fzf version: $(brew info fzf --json | jq -r '.[0].linked_keg')"
    fzf_version="$(brew info fzf --json | jq -r '.[0].linked_keg')"
    # shellcheck disable=SC1090
    . "$HOMEBREW_PREFIX"/Cellar/fzf/"${fzf_version}"/shell/completion.zsh || dot::warn "error loading fzf completion"

    # translate bind to bindkey
    . "$HOMEBREW_PREFIX"/Cellar/fzf/"${fzf_version}"/shell/key-bindings.zsh || dot::warn "error loading fzf key bindings"
    # source "$HOMEBREW_PREFIX"/Cellar/fzf/"${fzf_version}"/shell/key-bindings.bash
fi
