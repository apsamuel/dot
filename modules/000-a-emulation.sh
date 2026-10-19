# shellcheck shell=bash
# shellcheck disable=SC2317
DOT_DEBUG="${DOT_DEBUG:-0}"


directory=$(dirname "$0")
library=$(basename "$0")

dot::static::logging::loading "${library}" "${directory}"

# Usage: dot::emulation::run [--spawn] [--arch arm64|x86_64] [--shell sh|bash|csh|ksh|zsh] [--login] [code...]
#   --spawn   Launch a real shell process instead of using zsh emulation mode
#   --arch    Run under a specific architecture (macOS only, implies --spawn --login)
#   --shell   Target shell (default: zsh)
#   --login   Start a login shell (no code execution)
#   code      Code to execute (default: echo "Hello World")
dot::emulation::help() {
    case "${1:-}" in
        ''|help|run|-h|--help) ;;
        *) printf 'dot::emulation: unknown help topic: %s\n' "$1" >&2; return 1 ;;
    esac
    printf '%s\n' 'Usage: dot::emulation run [options] [--] [code...]' \
        '       dot::emulation::run [options] [--] [code...]' \
        'Execute code through ZSH emulation or a real shell.' \
        'Options: --spawn, --arch arm64|x86_64, --shell sh|bash|csh|ksh|zsh, --login, -h, --help.' \
        'Defaults: emulate zsh; code: echo "Hello World".' \
        '--arch replaces the current process with an architecture-specific login shell.' \
        '--login launches a shell and does not execute code. Requires the selected shell (and macOS arch for --arch).' \
        'Returns backend status; invalid options return 1. No retries.' \
        "Example: dot::emulation run --shell sh -- 'printf hello'"
}

dot::emulation() {
    local action="${1:-help}"
    [[ $# -eq 0 ]] || shift
    case "${action}" in
        help|-h|--help) dot::emulation::help "$@" ;;
        run) dot::emulation::run "$@" ;;
        *) printf 'dot::emulation: unknown command: %s\n' "${action}" >&2; return 1 ;;
    esac
}

function dot::emulation::run() {
    local mode="emulate" shell="zsh" architecture="" login=0
    local args=()

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help) dot::emulation::help run; return ;;
            --spawn)  mode="spawn"; shift ;;
            --arch)   [[ $# -ge 2 && -n "$2" ]] || { printf '%s\n' '--arch requires arm64 or x86_64' >&2; return 1; }; architecture="$2"; mode="spawn"; login=1; shift 2 ;;
            --shell)  [[ $# -ge 2 && -n "$2" ]] || { printf '%s\n' '--shell requires a shell name' >&2; return 1; }; shell="$2"; shift 2 ;;
            --login)  login=1; shift ;;
            --)       shift; args+=("$@"); break ;;
            -*)       printf 'dot::emulation: unknown option: %s (use -- before code)\n' "$1" >&2; return 1 ;;
            *)        args+=("$1"); shift ;;
        esac
    done

    local code="${args[*]:-echo \"Hello World\"}"
    case "${shell}" in sh|bash|csh|ksh|zsh) ;; *) printf 'dot::emulation: unsupported shell: %s\n' "${shell}" >&2; return 1 ;; esac

    # Architecture-specific login shell
    if [[ -n "$architecture" ]]; then
        local shell_path=""
        case "$architecture" in
            arm64)  shell_path="/opt/homebrew/bin/${shell}" ;;
            x86_64) shell_path="/usr/local/bin/${shell}" ;;
            *)      echo "dot::emulation::run: unsupported arch '${architecture}'" >&2; return 1 ;;
        esac
        [[ -x "${shell_path}" ]] || { printf 'dot::emulation: shell not executable: %s\n' "${shell_path}" >&2; return 1; }
        exec arch "-${architecture}" "$shell_path" -l
    fi

    # Login shell (no code)
    if [[ $login -eq 1 ]]; then
        command "$shell" -l
        return $?
    fi

    # Spawn a real shell process
    if [[ "$mode" == "spawn" ]]; then
        command "$shell" -c "$code"
        return $?
    fi

    # Default: zsh emulation mode
    command zsh -c "emulate ${shell}; ${code}"
}
