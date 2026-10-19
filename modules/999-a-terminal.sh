# shellcheck shell=bash
# shellcheck source=/dev/null

dot::terminal::help() {
    case "${1:-}" in
        ''|help|-h|--help) printf '%s\n' 'Usage: dot::terminal <compile-info|configure-fzf>' 'Example: dot::terminal help compile-info'; return ;;
        compile-info) printf '%s\n' 'Compile xterm-256color with ncv disabled into the user terminfo database.' 'Requires dot::foundation::compile-terminfo, infocmp, tic, mktemp. No arguments or retries.' ;;
        configure-fzf) printf '%s\n' 'Load fzf ZSH completion and key bindings. No arguments.' 'Noninteractive sessions (DOT_INTERACTIVE=0) skip successfully. Otherwise requires ZSH, fzf, brew, jq and readable installed scripts.' ;;
        *) printf 'dot::terminal: unknown help topic\n' >&2; return 1 ;;
    esac
    printf 'Usage: dot::terminal %s | dot::terminal::%s\n' "$1" "$1"
    printf '%s\n' 'Options: -h, --help. Help returns 0 without backend work; invalid input or missing dependencies return 1; backend status is preserved.'
}

dot::terminal() {
    local action="${1:-help}"
    [[ $# -eq 0 ]] || shift
    case "${action}" in
        help|-h|--help) dot::terminal::help "$@" ;;
        compile-info) dot::terminal::compile-info "$@" ;;
        configure-fzf) dot::terminal::configure-fzf "$@" ;;
        *) printf 'dot::terminal: unknown command: %s\n' "${action}" >&2; return 1 ;;
    esac
}

function dot::terminal::compile-info() {
    case "${1:-}" in -h|--help) dot::terminal::help compile-info; return ;; esac
    [[ $# -eq 0 ]] || { dot::terminal::help compile-info >&2; return 1; }
    command -v dot::foundation::compile-terminfo >/dev/null 2>&1 || {
        printf 'dot::terminal: dot::foundation::compile-terminfo is required\n' >&2; return 1;
    }
    dot::foundation::compile-terminfo
}

# fzf
function dot::terminal::configure-fzf() {
    case "${1:-}" in -h|--help) dot::terminal::help configure-fzf; return ;; esac
    [[ $# -eq 0 ]] || { dot::terminal::help configure-fzf >&2; return 1; }
    # fzf key-bindings install widgets that can pop the alternate screen
    # buffer for previews. Skip entirely in non-interactive / Copilot
    # terminals where DOT_INTERACTIVE=0 — there's no human at the keyboard
    # to use CTRL-R / CTRL-T / ALT-C anyway.
    if [[ "${DOT_INTERACTIVE:-0}" -eq 0 ]]; then
        return 0
    fi
    [[ -n "${ZSH_VERSION:-}" ]] || { printf 'dot::terminal: fzf shell configuration requires ZSH\n' >&2; return 1; }
    local tool="" fzf_version="" completion="" bindings=""
    for tool in fzf brew jq; do
        command -v "${tool}" >/dev/null 2>&1 || { printf 'dot::terminal: %s is required\n' "${tool}" >&2; return 1; }
    done
    fzf_version="$(set -o pipefail; brew info fzf --json | jq -er '.[0].linked_keg')" || return $?
    completion="${HOMEBREW_PREFIX:-}/Cellar/fzf/${fzf_version}/shell/completion.zsh"
    bindings="${HOMEBREW_PREFIX:-}/Cellar/fzf/${fzf_version}/shell/key-bindings.zsh"
    [[ -n "${HOMEBREW_PREFIX:-}" && -r "${completion}" && -r "${bindings}" ]] || {
        printf 'dot::terminal: installed fzf shell scripts are unavailable\n' >&2; return 1;
    }
    . "${completion}" || return $?
    . "${bindings}" || return $?
    return 0
}

if [[ "${DOT_INTERACTIVE:-0}" -ne 0 ]] && command -v fzf >/dev/null 2>&1; then
    dot::terminal::configure-fzf || dot::static::logging::warn 'error loading fzf shell configuration'
fi
