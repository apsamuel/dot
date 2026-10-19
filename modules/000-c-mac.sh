#shellcheck shell=bash


directory=$(dirname "$0")
library=$(basename "$0")

dot::static::logging::loading "${library}" "${directory}"


if [[ "${DOT_DISABLE_MAC:-0}" -eq 1 ]]; then
    dot::static::logging::skip "mac" "disabled"
    return
fi

dot::mac::help() {
    case "${1:-}" in
        ''|help|-h|--help) printf '%s\n' 'Usage: dot::mac <command>' 'Commands: cpu-cores, cpu-brand, help' 'Example: dot::mac help cpu-cores'; return ;;
        cpu-cores) printf '%s\n' 'Read the physical CPU core count (machdep.cpu.core_count).' ;;
        cpu-brand) printf '%s\n' 'Read the CPU brand string (machdep.cpu.brand_string).' ;;
        *) printf 'dot::mac: unknown help topic: %s\n' "$1" >&2; return 1 ;;
    esac
    printf 'Usage: dot::mac %s\n       dot::mac::%s\n' "$1" "$1"
    printf '%s\n' 'Options: -h, --help. No operands.' 'Requires sysctl and the macOS CPU key; read-only. Help does not query the host.' 'Returns sysctl status; invalid arguments or missing sysctl return 1.'
    printf 'Example: dot::mac %s\n' "$1"
}

dot::mac() {
    local action="${1:-help}"
    [[ $# -eq 0 ]] || shift
    case "${action}" in
        help|-h|--help) dot::mac::help "$@" ;;
        cpu-cores) dot::mac::cpu-cores "$@" ;;
        cpu-brand) dot::mac::cpu-brand "$@" ;;
        *) printf 'dot::mac: unknown command: %s\n' "${action}" >&2; return 1 ;;
    esac
}

dot::mac::_query() {
    command -v sysctl >/dev/null 2>&1 || { printf '%s\n' 'dot::mac: sysctl is required' >&2; return 1; }
    sysctl -n "$1"
}

dot::mac::cpu-cores() {
    case "${1:-}" in -h|--help) dot::mac::help cpu-cores; return ;; esac
    [[ $# -eq 0 ]] || { dot::mac::help cpu-cores >&2; return 1; }
    dot::mac::_query machdep.cpu.core_count
}

dot::mac::cpu-brand() {
    case "${1:-}" in -h|--help) dot::mac::help cpu-brand; return ;; esac
    [[ $# -eq 0 ]] || { dot::mac::help cpu-brand >&2; return 1; }
    dot::mac::_query machdep.cpu.brand_string
}

# blah
