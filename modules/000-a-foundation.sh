#% author: Aaron Samuel
#% description: define baseline environment variables required for the dotfiles ecosystem and the shell
# shellcheck shell=bash

#** disable relevant shellcheck warnings **#
# shellcheck source=/dev/null
# shellcheck disable=SC2207
DOT_DEBUG="${DOT_DEBUG:-0}"

directory=$(dirname "$0")
library=$(basename "$0")

dot::static::logging::loading "${library}" "${directory}"

# we need to source the mac.sh file first
source "${DOT_MODULES}"/static/lib/mac.sh


dot::foundation::help() {
    local operands=""
    case "${1:-}" in
        ''|help|-h|--help) printf '%s\n' 'Usage: dot::foundation <command>' 'Commands: compile-terminfo, shell-name, secure-string, help'; return ;;
        compile-terminfo) printf '%s\n' 'Compile xterm-256color with ncv disabled. Requires infocmp, tic, mktemp.' 'Writes the user terminfo database; no automatic retries.' ;;
        shell-name) printf '%s\n' 'Print the current shell name. Requires ps, tr, sed, xargs outside fish.' ;;
        secure-string) operands=' [length]'; printf '%s\n' 'Generate a password with pwgen. Optional positive length defaults to 15.' ;;
        *) printf 'dot::foundation: unknown help topic: %s\n' "$1" >&2; return 1 ;;
    esac
    printf 'Usage: dot::foundation %s%s\n       dot::foundation::%s%s\n' "$1" "${operands}" "$1" "${operands}"
    printf '%s\n' 'Options: -h, --help. Returns backend status; invalid arguments return 1.'
}

dot::foundation() {
    local action="${1:-help}"
    [[ $# -eq 0 ]] || shift
    case "${action}" in
        help|-h|--help) dot::foundation::help "$@" ;;
        compile-terminfo) dot::foundation::compile-terminfo "$@" ;;
        shell-name) dot::foundation::shell-name "$@" ;;
        secure-string) dot::foundation::secure-string "$@" ;;
        *) printf 'dot::foundation: unknown command: %s\n' "${action}" >&2; return 1 ;;
    esac
}

function dot::foundation::compile-terminfo() {
    case "${1:-}" in -h|--help) dot::foundation::help compile-terminfo; return ;; esac
    [[ $# -eq 0 ]] || { dot::foundation::help compile-terminfo >&2; return 1; }
    local tool="" temporary="" definition="" ret=0
    for tool in infocmp tic mktemp; do
        command -v "${tool}" >/dev/null 2>&1 || { printf 'dot::foundation: %s is required\n' "${tool}" >&2; return 1; }
    done
    definition="$(infocmp -x xterm-256color)" || return $?
    temporary="$(mktemp "${TMPDIR:-/tmp}/dot-terminfo.XXXXXX")" || return $?
    printf '%s\n\t%s\n' "${definition}" 'ncv@,' >"${temporary}" && tic -x "${temporary}" || ret=$?
    rm -f -- "${temporary}"
    return "${ret}"
}

function dot::foundation::shell-name () {
    case "${1:-}" in -h|--help) dot::foundation::help shell-name; return ;; esac
    [[ $# -eq 0 ]] || { dot::foundation::help shell-name >&2; return 1; }
    local currentShell=""
    if [[ -n "${fish_pid:-}" ]]; then
        echo "fish"
    else
    currentShell="$(command ps -p $$ -ocomm=)" || return $?
    # removes non-standard characters and returns the shell name
    echo "${currentShell}" | tr '[:upper:]' '[:lower:]' | sed -e s/-//g | xargs
    fi
}

function dot::foundation::secure-string () {
    case "${1:-}" in -h|--help) dot::foundation::help secure-string; return ;; esac
    local len="${1:-15}"
    [[ $# -le 1 && "${len}" != *[!0-9]* && "${len}" == *[1-9]* ]] || { dot::foundation::help secure-string >&2; return 1; }
    command -v pwgen >/dev/null 2>&1 || { printf '%s\n' 'dot::foundation: pwgen is required' >&2; return 1; }
    pwgen -n -y "${len}" 1
}
