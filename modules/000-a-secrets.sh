#shellcheck shell=bash
#% note: this runs first!
# 🕵️ ignore shellcheck warnings about source statements
# shellcheck source=/dev/null
# 🕵️ ignore shellcheck warnings about read/mapfile
# shellcheck disable=SC2207
DOT_DEBUG="${DOT_DEBUG:-0}"

directory=$(dirname "$0")
library=$(basename "$0")

dot::static::logging::loading "${library}" "${directory}"


dot::secrets() {
    local action="${1:-help}"
    [[ $# -eq 0 ]] || shift
    case "${action}" in
        help|-h|--help) dot::secrets::help "$@" ;;
        load) dot::secrets::load "$@" ;;
        mask)
            case "${1:-}" in -h|--help) dot::secrets::help mask; return ;; esac
            [[ "${1:-}" != -- ]] || shift
            dot::secrets::mask "$@" ;;
        reload-options) dot::secrets::reload-options "$@" ;;
        *) printf 'dot::secrets: unknown command: %s\n' "${action}" >&2; return 1 ;;
    esac
}

dot::secrets::help() {
    case "${1:-}" in
        ''|help|-h|--help) printf '%s\n' 'Usage: dot::secrets <load|mask|reload-options> [args]' 'Example: dot::secrets help mask'; return ;;
        load) printf '%s\n' 'Usage: dot::secrets load | dot::secrets::load' 'Load string values from $ICLOUD/dot/secrets.json into shell variables without adding export attributes. Requires jq.' 'Names must be shell identifiers; the _dot_secrets_ prefix is reserved for loader state.' 'No arguments. Invalid names/data fail before assignment; no temporary secret files or retries.' ;;
        mask) printf '%s\n' 'Usage: dot::secrets mask [--] [text...] | dot::secrets::mask [text...]' 'Mask literal secret values and SuperSecretPassword with **************. Requires jq and the secrets JSON.' 'Reads piped stdin after arguments. Direct leaf arguments are always literal, including --help.' 'Example: dot::secrets mask -- "message"' ;;
        reload-options) printf '%s\n' 'Usage: dot::secrets reload-options | dot::secrets::reload-options' 'Apply configured ZSH options; requires ZSH and yq. No arguments.' 'Uses iCloud configuration when present, otherwise DOT_SHELL_DATA. Partial failure returns 1.' ;;
        *) printf 'dot::secrets: unknown help topic: %s\n' "$1" >&2; return 1 ;;
    esac
    printf '%s\n' 'Family options: -h, --help. Help reads no credentials. Invalid input returns 1; backend failures are nonzero.'
}

function dot::secrets::_load () {
    dot::secrets::load "$@"
}

function dot::secrets::load () {
    case "${1:-}" in -h|--help) dot::secrets::help load; return ;; esac
    [[ $# -eq 0 ]] || { dot::secrets::help load >&2; return 1; }
    command -v jq >/dev/null 2>&1 || { printf 'dot::secrets: jq is required\n' >&2; return 1; }
    local _dot_secrets_file="${ICLOUD}/dot/secrets.json" _dot_secrets_keys="" _dot_secrets_key="" _dot_secrets_value=""
    local -a _dot_secrets_assignments=()
    jq -e 'type == "object" and all(to_entries[]; (.key | test("^[A-Za-z_][A-Za-z0-9_]*$")) and (.key | startswith("_dot_secrets_") | not) and (.value | type == "string" and (contains("\u0000") | not)))' "${_dot_secrets_file}" >/dev/null 2>&1 || {
        printf 'dot::secrets: unreadable or invalid secrets JSON\n' >&2; return 1;
    }
    _dot_secrets_keys="$(jq -r 'keys[]' "${_dot_secrets_file}" 2>/dev/null)" || return $?
    while IFS= read -r _dot_secrets_key; do
        [[ -n "${_dot_secrets_key}" ]] || continue
        _dot_secrets_value="$(jq -j --arg secret_key "${_dot_secrets_key}" '.[$secret_key]' "${_dot_secrets_file}" 2>/dev/null && printf '.')" || return $?
        _dot_secrets_assignments+=("${_dot_secrets_key}=${_dot_secrets_value%.}")
    done <<< "${_dot_secrets_keys}"
    [[ ${#_dot_secrets_assignments[@]} -gt 0 ]] || return 0
    typeset -g -- "${_dot_secrets_assignments[@]}" 2>/dev/null || { printf 'dot::secrets: variable assignment failed\n' >&2; return 1; }
    return 0
}

function dot::secrets::_mask () {
    dot::secrets::mask "$@"
}

function dot::secrets::mask () {
    command -v jq >/dev/null 2>&1 || { printf 'dot::secrets: jq is required\n' >&2; return 1; }
    local secret_file="${ICLOUD}/dot/secrets.json"
    [[ -r "${secret_file}" ]] || { printf 'dot::secrets: secrets JSON is not readable\n' >&2; return 1; }
    (set -o pipefail
        { [[ $# -eq 0 ]] || printf '%s\n' "$@"; if [[ -p /dev/stdin ]]; then cat; fi; } |
            jq -Rr --slurpfile secrets "${secret_file}" '
                reduce (["SuperSecretPassword"] + [$secrets[0][] | strings | select(length > 0)] | sort_by(length) | reverse)[] as $secret
                (.; split($secret) | join("**************"))' 2>/dev/null
    ) || { printf 'dot::secrets: masking failed\n' >&2; return 1; }
}

function dot::secrets::reload-options () {
    case "${1:-}" in -h|--help) dot::secrets::help reload-options; return ;; esac
    [[ $# -eq 0 ]] || { dot::secrets::help reload-options >&2; return 1; }
    command -v yq >/dev/null 2>&1 || { printf 'dot::secrets: yq is required\n' >&2; return 1; }
    command -v setopt >/dev/null 2>&1 || { printf 'dot::secrets: reload-options requires ZSH\n' >&2; return 1; }
    local _zsh_cfg="${ICLOUD}/dot/shell/zsh/zsh.yaml"
    if [[ ! -f "${_zsh_cfg}" ]]; then
        _zsh_cfg="${DOT_SHELL_DATA:-${HOME}/.dot/data/zsh.yaml}"
    fi
    local zsh_options="" option="" failed=0
    zsh_options="$(yq '.options[]' "${_zsh_cfg}")" || return $?
    while IFS= read -r option; do
        [[ -n "${option}" ]] || continue
        dot::static::logging::debug "setting option: ${option}"

        setopt "${option}" 2>/dev/null || {
            dot::static::logging::warn "Failed to set option: ${option}"
            failed=1
            continue
        }
    done <<< "${zsh_options}"
    return "${failed}"
}
