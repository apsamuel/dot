#% author: Aaron Samuel
#% description: foundational functionality leveraged in shell entrypoints, required (early) for using the dotfiles project
# shellcheck shell=bash
# shellcheck source=/dev/null
# - ignore shellcheck warnings about read/mapfile
# shellcheck disable=SC2207


# we need to source the mac.sh file first
source "${DOT_MODULES}"/000-c-mac.sh

dot::static::foundation() {
    local action="${1:-help}"
    [[ $# -eq 0 ]] || shift
    case "${action}" in
        help|-h|--help) dot::static::foundation::help "$@" ;;
        shell-name) dot::static::foundation::shell-name "$@" ;;
        secure-string) dot::static::foundation::secure-string "$@" ;;
        cpu-cores|cpu-brand)
            case "${1:-}" in -h|--help) dot::static::foundation::help "${action}"; return ;; esac
            [[ $# -eq 0 ]] || return 2
            case "${action}" in cpu-cores) dot::static::foundation::cpu-cores ;; *) dot::static::foundation::cpu-brand ;; esac ;;
        load-user-secrets) dot::static::foundation::load-user-secrets "$@" ;;
        ssh-identities) dot::static::foundation::ssh-identities "$@" ;;
        *) printf 'dot::static::foundation: unknown command: %s\n' "${action}" >&2; return 2 ;;
    esac
}

dot::static::foundation::help() {
    case "${1:-}" in
        ''|help|-h|--help) printf '%s\n' 'Usage: dot::static::foundation <command>' 'Commands: shell-name, secure-string, cpu-cores, cpu-brand, load-user-secrets, ssh-identities'; return ;;
        load-user-secrets) dot::static::foundation::load-user-secrets --help; return ;;
        ssh-identities) dot::static::foundation::ssh-identities --help; return ;;
        shell-name) printf '%s\n' 'Print the current shell command name via ps. No operands; read-only.' ;;
        secure-string) printf '%s\n' 'Generate a password via pwgen. Optional positive length defaults to 15.' ;;
        cpu-cores|cpu-brand) printf '%s\n' 'Read CPU information using the existing platform backend. No operands.' ;;
        *) printf 'dot::static::foundation: unknown help topic\n' >&2; return 2 ;;
    esac
    printf 'Usage: dot::static::foundation %s [args]\nExisting dot::static::foundation::%s remains available.\n' "$1" "$1"
    printf '%s\n' 'Use family help <command> or <command> --help. Help returns 0; invalid input returns 2; backend failures are nonzero.'
}

function dot::static::foundation::shell-name () {
    case "${1:-}" in -h|--help) dot::static::foundation::help shell-name; return ;; esac
    [[ $# -eq 0 ]] || return 2
    local currentShell=""
    currentShell="$(command ps -p $$ -ocomm=)" || return $?
    echo "$currentShell"
}

function dot::static::foundation::secure-string () {
    case "${1:-}" in -h|--help) dot::static::foundation::help secure-string; return ;; esac
    local len="${1:-15}"
    [[ $# -le 1 && "${len}" != *[!0-9]* && "${len}" == *[1-9]* ]] || return 2
    command -v pwgen >/dev/null 2>&1 || { printf 'dot::static::foundation: pwgen is required\n' >&2; return 1; }
    pwgen -n -y "${len}" 1
}


function dot::static::foundation::cpu-cores() {
    sysctl -n machdep.cpu.core_count
}

function dot::static::foundation::cpu-brand() {
    sysctl -n machdep.cpu.brand_string
}

function dot::static::foundation::load-zsh-options() {
    # if $ICLOUD is inaccessible, fall back to the .dot directory copy
    if [[ -f "$ICLOUD"/dot/shell/zsh/zsh.yaml ]]; then
        ZSH_OPTIONS=(
            $(
                yq '.options[]' "$ICLOUD"/dot/shell/zsh/zsh.yaml | xargs
            )
        )
    else
        ZSH_OPTIONS=(
            $(
                yq '.options[]' "$DOT_DIRECTORY"/data/zsh.yaml | xargs
            )
        )
    fi

    export ZSH_OPTIONS

    for opt in "${ZSH_OPTIONS[@]}"; do
        if [[ ! "${DOT_DEBUG}x" == "x" && "${DOT_DEBUG}" == true ]]; then
            echo "set option: $opt"
        fi
        setopt "${opt}"
    done
}

# Re-assert authoritative history config AFTER oh-my-zsh.sh, whose lib/history.zsh
# otherwise clobbers HISTSIZE/SAVEHIST back down to its 50000/10000 defaults.
dot::history() {
    local action="${1:-help}"
    [[ $# -eq 0 ]] || shift
    case "${action}" in
        help|-h|--help) dot::history::help "$@" ;;
        rotate) dot::history::rotate "$@" ;;
        configure) dot::history::configure "$@" ;;
        *) printf 'dot::history: unknown command: %s\n' "${action}" >&2; return 1 ;;
    esac
}

dot::history::help() {
    case "${1:-}" in
        ''|help|-h|--help) printf '%s\n' 'Usage: dot::history <rotate|configure>' 'Example: dot::history help rotate'; return ;;
        rotate) printf '%s\n' 'Usage: dot::history rotate [-f|--force] | dot::history::rotate [-f|--force]' 'Archive HISTFILE (default $HOME/.zsh_history); --force bypasses interval only.' ;;
        configure) printf '%s\n' 'Usage: dot::history configure | dot::history::configure' 'Apply ZSH history options and sizes, then rotate. No arguments.' ;;
        *) printf 'dot::history: unknown help topic\n' >&2; return 1 ;;
    esac
    printf '%s\n' 'Requires gzip and filesystem tools. Archives use DOT_HIST_ARCHIVE_DIR (default XDG_DATA_HOME/dot/history).' \
        'Defaults: enabled, interval 86400s, retention 30 snapshots; trimming disabled (KEEP_LINES=0).' \
        'DOT_HIST_ROTATE_KEEP_LINES > 0 enables live trimming above DOT_HIST_ROTATE_MAX_BYTES (104857600).' \
        'Help (-h/--help), disabled or absent history returns 0. Invalid config/input and operational failures are nonzero. No retries.'
}

function dot::history::configure() {
    case "${1:-}" in -h|--help) dot::history::help configure; return ;; esac
    [[ $# -eq 0 ]] || { dot::history::help configure >&2; return 1; }
    export HISTFILE="${HISTFILE:-$HOME/.zsh_history}"
    export HISTSIZE="${ZSH_HISTSIZE:-1000000000}"
    export SAVEHIST="${ZSH_SAVEHIST:-1000000000}"  # in-memory HISTSIZE must be >= on-disk SAVEHIST

    if [[ -n "${ZSH_VERSION:-}" ]]; then
        setopt EXTENDED_HISTORY SHARE_HISTORY INC_APPEND_HISTORY \
               HIST_IGNORE_ALL_DUPS HIST_EXPIRE_DUPS_FIRST HIST_SAVE_NO_DUPS \
               HIST_FIND_NO_DUPS HIST_IGNORE_SPACE HIST_REDUCE_BLANKS HIST_VERIFY 2>/dev/null
    fi

    dot::history::rotate
}

# Resolve the archive directory (timestamped compressed snapshots live here).
function dot::history::_archive-dir() {
    printf '%s\n' "${DOT_HIST_ARCHIVE_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/dot/history}"
}

# Keep at most DOT_HIST_ARCHIVE_MAX snapshots; timestamped names sort chronologically.
function dot::history::_prune-archives() {
    local dir="$1"
    local keep="$((10#${DOT_HIST_ARCHIVE_MAX:-30}))"
    local files=""
    local count=0
    [[ "$keep" -gt 0 ]] || return 0
    files=$(ls -1 "$dir"/zsh_history-*.gz 2>/dev/null | sort)
    count=$(printf '%s\n' "$files" | grep -c .)
    (( count > keep )) || return 0
    printf '%s\n' "$files" | head -n "$(( count - keep ))" | while IFS= read -r f; do
        [[ -z "$f" ]] || rm -f -- "$f" || return $?
    done
}

# Optional: trim the live HISTFILE to the last DOT_HIST_ROTATE_KEEP_LINES lines,
# but only once it exceeds DOT_HIST_ROTATE_MAX_BYTES. Disabled by default (KEEP_LINES=0).
# Trims at an EXTENDED_HISTORY entry boundary (': <epoch>:<dur>;') so no command is split.
function dot::history::_trim-live() {
    local histfile="$1"
    local keep="$((10#${DOT_HIST_ROTATE_KEEP_LINES:-0}))"
    local max_bytes="$((10#${DOT_HIST_ROTATE_MAX_BYTES:-104857600}))"
    local size=0
    local tmp=""
    [[ "$keep" -gt 0 ]] || return 0
    size=$(/usr/bin/stat -f %z "$histfile" 2>/dev/null || stat -c %s "$histfile" 2>/dev/null || echo 0)
    (( size > max_bytes )) || return 0

    tmp="$(mktemp "${histfile}.XXXXXX")" || return $?
    if ! (set -o pipefail; tail -n "$keep" "$histfile" | awk '/^: [0-9]+:[0-9]+;/{s=1} s' > "$tmp"); then
        rm -f -- "$tmp"
        return 1
    fi
    if [[ -s "$tmp" ]]; then
        mv "$tmp" "$histfile" || return $?
        if [[ -n "${ZSH_VERSION:-}" && -o interactive ]]; then fc -R "$histfile" || return $?; fi
    else
        rm -f "$tmp" || return $?
    fi
    return 0
}

# Snapshot the full history file to a compressed, timestamped archive (non-destructive),
# then apply retention and optional live-file trimming. Gated to run once per
# DOT_HIST_ARCHIVE_INTERVAL seconds; pass --force to bypass the interval gate.
function dot::history::rotate() {
    local force=0
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help) dot::history::help rotate; return ;;
            -f|--force) force=1; shift ;;
            --) shift; [[ $# -eq 0 ]] || return 1 ;;
            *) dot::history::help rotate >&2; return 1 ;;
        esac
    done
    local setting=""
    for setting in "${DOT_HIST_ARCHIVE_INTERVAL:-86400}" "${DOT_HIST_ARCHIVE_MAX:-30}" "${DOT_HIST_ROTATE_KEEP_LINES:-0}" "${DOT_HIST_ROTATE_MAX_BYTES:-104857600}"; do
        case "${setting}" in *[!0-9]*) printf 'dot::history: numeric settings must be nonnegative integers\n' >&2; return 1 ;; esac
    done
    [[ "${DOT_HIST_ARCHIVE_ENABLE:-true}" == true ]] || return 0

    local histfile="${HISTFILE:-$HOME/.zsh_history}"
    [[ -s "$histfile" ]] || return 0

    local archive_dir=""
    local stamp=""
    local interval="$((10#${DOT_HIST_ARCHIVE_INTERVAL:-86400}))"
    local now=0
    local last=0
    local ts=""
    local snapshot=""
    local temporary="" archive_rc=0
    archive_dir="$(dot::history::_archive-dir)"
    stamp="${archive_dir}/.last-archive"

    if (( ! force )) && [[ -f "$stamp" ]]; then
        now=$(date +%s) || return $?
        last=$(cat "$stamp" 2>/dev/null || echo 0)
        case "$last" in ''|*[!0-9]*) last=0 ;; esac
        last="$((10#${last}))"
        (( now - last < interval )) && return 0
    fi

    command -v gzip >/dev/null 2>&1 || { printf 'dot::history: gzip is required\n' >&2; return 1; }
    mkdir -p "$archive_dir" || return $?

    # Flush the current session to disk so the snapshot is complete.
    if [[ -n "${ZSH_VERSION:-}" && -o interactive ]]; then fc -AI || return $?; fi

    ts="$(date +%Y%m%d-%H%M%S)" || return $?
    temporary="$(mktemp "${archive_dir}/zsh_history-${ts}.XXXXXX")" || return $?
    snapshot="${temporary}.gz"
    gzip -c "$histfile" > "$temporary" || archive_rc=$?
    if [[ "${archive_rc}" -ne 0 ]]; then
        rm -f -- "${temporary}"
        return "${archive_rc}"
    fi
    mv -- "${temporary}" "${snapshot}" || return $?
    date +%s > "$stamp" || return $?

    dot::history::_prune-archives "$archive_dir" || return $?
    dot::history::_trim-live "$histfile"
}

function dot::static::foundation::source-module() {
    local mod="$1"
    local mod_name=""
    mod_name="$(basename "$mod")"

    if [[ ! -r "$mod" ]]; then
        DOT_FAILED_MODULES+=("$mod_name")
        if [[ "${DOT_DEBUG:-0}" == "1" || "${DOT_DEBUG:-}" == "true" ]]; then
            echo "skip source: $mod (not readable)"
        fi
        return 0
    fi

    local rc=0
    local t0=""
    if [[ "${DOT_DEBUG:-0}" == "1" || "${DOT_DEBUG:-}" == "true" ]]; then
        t0="$EPOCHREALTIME"
    fi

    . "$mod"
    rc=$?

    if [[ $rc -ne 0 ]]; then
        DOT_FAILED_MODULES+=("$mod_name")
        if [[ "${DOT_DEBUG:-0}" == "1" || "${DOT_DEBUG:-}" == "true" ]]; then
            echo "FAIL source: $mod (rc=$rc)"
        fi
    else
        DOT_LOADED_MODULES+=("$mod_name")
        if [[ "${DOT_DEBUG:-0}" == "1" || "${DOT_DEBUG:-}" == "true" ]]; then
            local elapsed=""
            elapsed="$(( EPOCHREALTIME - t0 ))"
            printf "load source: %s (%.3fs)\n" "$mod" "$elapsed"
        fi
    fi

    return 0
}

function dot::static::foundation::load-modules() {
    DOT_LOADED_MODULES=()
    DOT_FAILED_MODULES=()

    if [ -d "$DOT_LIBS_DIR" ]; then
        for lib in $(find "${DOT_LIBS_DIR}" -maxdepth 1 -type f -name "[0-9][0-9][0-9]-*-*.sh" | sort -d); do
            dot::static::foundation::source-module "$lib"
        done
    else
        echo "Warning: DOT_LIBS_DIR not found: $DOT_LIBS_DIR"
    fi

    export DOT_LOADED_MODULES
    export DOT_FAILED_MODULES
}

function dot::static::foundation::load-secrets () {
    local secret_keys=()
    # declare -A secrets
    while IFS=' ' read -r -d ' ' secret_key; do
        secret_keys+=("${secret_key}")
    done < <(jq -r '. | keys | .[]' "${ICLOUD}"/dot/secrets.json | xargs) # -print0
    touch "${TMPDIR}"/.secrets
    if [[ ${#secret_keys[@]} -gt 0  ]]; then
        echo "#!/bin/bash" > "$TMPDIR"/.secrets
    fi
    for secret_key in "${secret_keys[@]}"; do
        secret_value="$(jq --arg secret_key "${secret_key}" -r '.[$secret_key]' "${ICLOUD}"/dot/secrets.json)"
        echo "${secret_key}=${secret_value}" >> "$TMPDIR"/.secrets
    done
    if [[ -f "$TMPDIR"/.secrets ]]; then
        source "$TMPDIR"/.secrets
        rm -f "$TMPDIR"/.secrets
    else
        echo "no secrets file found"
    fi
}

# dot::static::foundation::load-user-secrets: loads secrets from $ICLOUD/dot/secrets.json into the current
# shell environment. Each JSON key is exported as an environment variable and
# the key names are collected in DOT_SECRET_KEYS. The intermediate file is
# written to $TMPDIR and removed after sourcing so secrets never persist on disk.
#
# Usage: dot::static::foundation::load-user-secrets [-l|--list-loaded] [-d|--list-defined]
#                                                   [--show-values] [-h|--help]
# With no arguments the secrets are loaded. Listing modes print key names only,
# unless --show-values is given.
function dot::static::foundation::load-user-secrets () {
    local _dot_user_secrets_file="${ICLOUD}/dot/secrets.json"
    local _dot_user_secrets_mode="load"
    local _dot_user_secrets_show=0

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -l|--list-loaded)  _dot_user_secrets_mode="list-loaded"; shift ;;
            -d|--list-defined) _dot_user_secrets_mode="list-defined"; shift ;;
            --show-values)     _dot_user_secrets_show=1; shift ;;
            -h|--help)
                cat <<'EOF'
Usage: dot::static::foundation::load-user-secrets [-l|--list-loaded] [-d|--list-defined]
                                                  [--show-values] [-h|--help]

Load secrets from $ICLOUD/dot/secrets.json into the current shell environment.
Each JSON key is exported as an environment variable and the key names are
collected in DOT_SECRET_KEYS.

Options:
  -l, --list-loaded   List keys currently loaded into the environment
  -d, --list-defined  List keys defined in secrets.json
      --show-values   Print KEY=value instead of key names (listing modes only)
  -h, --help          Show this help

With no options the secrets are loaded. Values are never printed unless
--show-values is given.
Requires jq for loading or listing defined keys. Missing files are a no-op
when loading. Invalid usage returns 2; invalid JSON/assignments return 1.
Keys must be shell identifiers; DOT_SECRET_KEYS and _dot_user_secrets_ names
are reserved. NUL values cannot be represented by shell variables.
Values are assigned literally, without temporary shell scripts or retries.

Examples:
  dot::static::foundation::load-user-secrets
  dot::static::foundation::load-user-secrets --list-loaded
  dot::static::foundation::load-user-secrets --list-defined --show-values
EOF
                return 0
                ;;
            *)
                echo "dot::static::foundation::load-user-secrets: unknown argument: $1" >&2
                return 2
                ;;
        esac
    done

    if (( _dot_user_secrets_show )) && [[ "${_dot_user_secrets_mode}" == "load" ]]; then
        echo "dot::static::foundation::load-user-secrets: --show-values requires --list-loaded or --list-defined" >&2
        return 2
    fi

    if [[ "${_dot_user_secrets_mode}" == "list-loaded" ]]; then
        local _dot_user_secrets_loaded=""
        for _dot_user_secrets_loaded in "${DOT_SECRET_KEYS[@]}"; do
            # printenv returns 0 for set-but-empty values, 1 when unset
            printenv "${_dot_user_secrets_loaded}" >/dev/null 2>&1 || continue
            if (( _dot_user_secrets_show )); then
                printf '%s=%s\n' "${_dot_user_secrets_loaded}" "$(printenv "${_dot_user_secrets_loaded}")"
            else
                printf '%s\n' "${_dot_user_secrets_loaded}"
            fi
        done
        return 0
    fi

    if [[ "${_dot_user_secrets_mode}" == "list-defined" ]]; then
        if [[ ! -f "${_dot_user_secrets_file}" ]]; then
            echo "dot::static::foundation::load-user-secrets: secrets file not found: ${_dot_user_secrets_file}" >&2
            return 1
        fi
        command -v jq >/dev/null 2>&1 || { printf 'dot::static::foundation: jq is required\n' >&2; return 1; }
        if (( _dot_user_secrets_show )); then
            jq -r 'to_entries[] | "\(.key)=\(.value)"' "${_dot_user_secrets_file}"
        else
            jq -r 'keys[]' "${_dot_user_secrets_file}"
        fi
        return $?
    fi

    if [[ ! -d "${ICLOUD}/dot" || ! -f "${_dot_user_secrets_file}" ]]; then
        return 0
    fi

    command -v jq >/dev/null 2>&1 || { printf 'dot::static::foundation: jq is required\n' >&2; return 1; }
    jq -e 'type == "object" and all(to_entries[]; (.key | test("^[A-Za-z_][A-Za-z0-9_]*$")) and (.key != "DOT_SECRET_KEYS") and (.key | startswith("_dot_user_secrets_") | not) and (.value | tostring | contains("\u0000") | not))' "${_dot_user_secrets_file}" >/dev/null 2>&1 || {
        printf 'dot::static::foundation: unreadable or invalid secrets JSON\n' >&2; return 1;
    }
    local _dot_user_secrets_keys="" _dot_user_secrets_key="" _dot_user_secrets_value=""
    local -a _dot_user_secrets_names=() _dot_user_secrets_assignments=()
    _dot_user_secrets_keys="$(jq -r 'keys[]' "${_dot_user_secrets_file}" 2>/dev/null)" || return $?
    while IFS= read -r _dot_user_secrets_key; do
        [[ -n "${_dot_user_secrets_key}" ]] || continue
        _dot_user_secrets_value="$(jq -j --arg key "${_dot_user_secrets_key}" '.[$key]' "${_dot_user_secrets_file}" 2>/dev/null && printf '.')" || return $?
        _dot_user_secrets_names+=("${_dot_user_secrets_key}")
        _dot_user_secrets_assignments+=("${_dot_user_secrets_key}=${_dot_user_secrets_value%.}")
    done <<< "${_dot_user_secrets_keys}"
    if [[ ${#_dot_user_secrets_assignments[@]} -gt 0 ]]; then
        typeset -gx -- "${_dot_user_secrets_assignments[@]}" 2>/dev/null || { printf 'dot::static::foundation: variable assignment failed\n' >&2; return 1; }
    fi
    typeset -ga DOT_SECRET_KEYS
    DOT_SECRET_KEYS=("${_dot_user_secrets_names[@]}")
    return 0
}

# dot::static::foundation::ssh-identities: scan an SSH directory for private key files and return the
# basenames in a form suitable for `zstyle :omz:plugins:ssh-agent identities`
# (or any other consumer).
#
# Usage:
#   dot::static::foundation::ssh-identities [-p|--list-present] [-l|--list-loaded] [--dir DIR]
#                    [--format array|string] [--var VARNAME] [--exclude REGEX] [--absolute]
#
# Options:
#   -p, --list-present  List identities present in the SSH directory (default mode).
#   -l, --list-loaded   List identities currently loaded in ssh-agent (`ssh-add -l`).
#   --dir DIR        Directory to scan (default: $HOME/.ssh).
#   --format FMT     Output format: "array" (newline-separated, default) or
#                    "string" (space-separated, shell-quoted entries).
#   --var VARNAME    Assign the result to VARNAME instead of printing to stdout.
#                    With --format array the variable is populated as a real
#                    array; with --format string it receives a single string.
#   --exclude REGEX  Override the default exclusion regex. The default skips
#                    config, *.pub, known_hosts*, environment*, and *deprecated*
#                    entries.
#   --absolute       Emit absolute paths instead of basenames.
#
# Examples:
#   # populate a zsh array and pass to zstyle
#   dot::static::foundation::ssh-identities --format array --var SSH_KEYS
#   zstyle :omz:plugins:ssh-agent identities "${SSH_KEYS[@]}"
#
#   # capture as a string
#   dot::static::foundation::ssh-identities --format string --var SSH_KEYS_STR
function dot::static::foundation::ssh-identities () {
    local dir="${HOME}/.ssh"
    local format="array"
    local outVar=""
    local exclude='(config|deprecated|.*\.pub|environment.*|known_hosts.*)'
    local absolute=0
    local mode="present"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dir|--format|--var|--exclude)
                [[ $# -ge 2 ]] || { printf 'dot::static::foundation: missing option value\n' >&2; return 2; } ;;
        esac
        case "$1" in
            -p|--list-present) mode="present"; shift ;;
            -l|--list-loaded)  mode="loaded"; shift ;;
            --dir)      dir="$2"; shift 2 ;;
            --format)   format="$2"; shift 2 ;;
            --var)      outVar="$2"; shift 2 ;;
            --exclude)  exclude="$2"; shift 2 ;;
            --absolute) absolute=1; shift ;;
            -h|--help)
                cat <<'EOF'
Usage: dot::static::foundation::ssh-identities [-p|--list-present] [-l|--list-loaded] [--dir DIR]
                        [--format array|string] [--var VARNAME] [--exclude REGEX] [--absolute]

Scan an SSH directory for private key files and return their basenames
(or absolute paths) in a form suitable for consumers like
`zstyle :omz:plugins:ssh-agent identities`, or list the identities
currently loaded in ssh-agent.

Options:
  -p, --list-present  List identities present in the SSH directory (default)
  -l, --list-loaded   List identities loaded in ssh-agent, as printed by
                      `ssh-add -l` (bits, fingerprint, comment, type);
                      --dir/--format/--var/--exclude/--absolute do not apply
  --dir DIR        Directory to scan (default: $HOME/.ssh)
  --format FMT     Output format: "array" (newline-separated, default) or
                   "string" (space-separated, shell-quoted entries)
  --var VARNAME    Assign result to VARNAME instead of printing to stdout
  --exclude REGEX  Override default key exclusion regex
                   (default skips config, *.pub, known_hosts*,
                   environment*, and *deprecated* entries)
  --absolute       Emit absolute paths instead of basenames
  -h, --help       Show this help

Examples:
  dot::static::foundation::ssh-identities --format array --var SSH_KEYS
  dot::static::foundation::ssh-identities --format string --var SSH_KEYS_STR
  dot::static::foundation::ssh-identities --list-present --absolute
  dot::static::foundation::ssh-identities --list-loaded
EOF
                return 0
                ;;
            *)
                echo "dot::static::foundation::ssh-identities: unknown argument: $1" >&2
                return 2
                ;;
        esac
    done

    case "${outVar}" in
        [0-9]*|*[!a-zA-Z0-9_]*) printf 'dot::static::foundation: invalid variable name\n' >&2; return 2 ;;
    esac
    if [[ "${format}" != "array" && "${format}" != "string" ]]; then
        echo "dot::static::foundation::ssh-identities: --format must be 'array' or 'string'" >&2
        return 2
    fi

    if [[ "${mode}" == "loaded" ]]; then
        if [[ -n "${outVar}" ]]; then
            echo "dot::static::foundation::ssh-identities: --var is not supported with --list-loaded" >&2
            return 2
        fi
        local agentOut=""
        local agentRc=0
        command -v ssh-add >/dev/null 2>&1 || { printf 'dot::static::foundation: ssh-add is required\n' >&2; return 1; }
        agentOut="$(ssh-add -l 2>/dev/null)" || agentRc=$?
        # ssh-add -l: 0 = identities listed, 1 = agent has none, 2 = no agent reachable
        if (( agentRc == 2 )); then
            echo "dot::static::foundation::ssh-identities: cannot reach ssh-agent" >&2
            return 1
        fi
        (( agentRc <= 1 )) || return "${agentRc}"
        [[ ${agentRc} -eq 0 ]] && printf '%s\n' "${agentOut}"
        return 0
    fi

    local -a keys=()
    if [[ -n "${ZSH_VERSION:-}" ]]; then setopt local_options null_glob; fi
    if [[ -d "${dir}" ]]; then
        local file base
        for file in "${dir}"/*; do
            [[ -e "${file}" ]] || continue
            [[ -f "${file}" ]] || continue
            base="${file##*/}"
            if [[ "${base}" =~ ${exclude} ]]; then
                continue
            fi
            if (( absolute )); then
                keys+=("${file}")
            else
                keys+=("${base}")
            fi
        done
    fi

    local joined
    joined="$(printf '%q ' "${keys[@]}")"
    joined="${joined% }"

    if [[ -n "${outVar}" ]]; then
        if [[ "${format}" == "array" ]]; then
            # assign positional values to a named array (zsh + bash compatible)
            eval "${outVar}=(\"\${keys[@]}\")"
        else
            # assign string to a named scalar
            eval "${outVar}=\${joined}"
        fi
        return 0
    fi

    if [[ "${format}" == "array" ]]; then
        local k
        for k in "${keys[@]}"; do
            printf '%s\n' "${k}"
        done
    else
        printf '%s\n' "${joined}"
    fi
}
