#shellcheck shell=bash
#% note: this runs first!
# 🕵️ ignore shellcheck warnings about source statements
# shellcheck source=/dev/null
# 🕵️ ignore shellcheck warnings about read/mapfile
# shellcheck disable=SC2207


dot::tools::help() {
    case "${1:-}" in
        ''|help|-h|--help) printf '%s\n' 'Usage: dot::tools <command> [arguments]' 'Commands: preview, help' 'Example: dot::tools help preview' ;;
        preview) printf '%s\n' 'Usage: dot::tools preview [--] [FZF_OPTIONS...]' '       dot::tools::preview [--] [FZF_OPTIONS...]' 'Select stdin entries with a file preview. Requires fzf; uses bat, or cat when bat is absent.' 'Options: -h, --help; -- ends wrapper option handling. Other arguments are passed unchanged to fzf.' 'Example: dot::tools preview -- --multi' 'Interactive except when using FZF options such as --filter. Help runs no tools.' 'Returns the fzf status, including cancellation; missing dependencies return 1.' ;;
        *) printf 'dot::tools: unknown help topic: %s\n' "$1" >&2; return 1 ;;
    esac
}

dot::tools() {
    local action="${1:-help}"
    [[ $# -eq 0 ]] || shift
    case "${action}" in
        help|-h|--help) dot::tools::help "$@" ;;
        preview) dot::tools::preview "$@" ;;
        *) printf 'dot::tools: unknown command: %s\n' "${action}" >&2; return 1 ;;
    esac
}

dot::tools::preview() {
    case "${1:-}" in -h|--help) dot::tools::help preview; return ;; --) shift ;; esac
    command -v fzf >/dev/null 2>&1 || { printf '%s\n' 'dot::tools::preview: fzf is required' >&2; return 1; }
    local preview_command='bat --color=always -- {-1}'
    if ! command -v bat >/dev/null 2>&1; then
        command -v cat >/dev/null 2>&1 || { printf '%s\n' 'dot::tools::preview: bat or cat is required' >&2; return 1; }
        preview_command='cat -- {-1}'
    fi
    fzf --preview "${preview_command}" "$@"
}
