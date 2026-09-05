#% author: Aaron Samuel
#% description: foundational functionality leveraged in shell entrypoints, required (early) for using the dotfiles project
# shellcheck shell=bash
# shellcheck source=/dev/null
# - ignore shellcheck warnings about read/mapfile
# shellcheck disable=SC2207


# we need to source the mac.sh file first
source "${DOT_MODULES}"/000-c-mac.sh

function dot::static::foundation::shell-name () {
    currentShell="$(command ps -p $$ -ocomm=)"
    echo "$currentShell"
}

function dot::static::foundation::secure-string () {
    len="${1:-15}"
    secureString="$(pwgen -n -y "${len}" 1)"
    echo "$secureString"
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
function dot::history::configure() {
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
    local keep="${DOT_HIST_ARCHIVE_MAX:-30}"
    local files=""
    local count=0
    [[ "$keep" -gt 0 ]] || return 0
    files=$(ls -1 "$dir"/zsh_history-*.gz 2>/dev/null | sort)
    count=$(printf '%s\n' "$files" | grep -c .)
    (( count > keep )) || return 0
    printf '%s\n' "$files" | head -n "$(( count - keep ))" | while IFS= read -r f; do
        [[ -n "$f" ]] && rm -f "$f" 2>/dev/null
    done
}

# Optional: trim the live HISTFILE to the last DOT_HIST_ROTATE_KEEP_LINES lines,
# but only once it exceeds DOT_HIST_ROTATE_MAX_BYTES. Disabled by default (KEEP_LINES=0).
# Trims at an EXTENDED_HISTORY entry boundary (': <epoch>:<dur>;') so no command is split.
function dot::history::_trim-live() {
    local histfile="$1"
    local keep="${DOT_HIST_ROTATE_KEEP_LINES:-0}"
    local max_bytes="${DOT_HIST_ROTATE_MAX_BYTES:-104857600}"
    local size=0
    local tmp=""
    [[ "$keep" -gt 0 ]] || return 0
    size=$(/usr/bin/stat -f %z "$histfile" 2>/dev/null || stat -c %s "$histfile" 2>/dev/null || echo 0)
    (( size > max_bytes )) || return 0

    tmp="$(mktemp "${histfile}.XXXXXX")" || return 0
    tail -n "$keep" "$histfile" | awk '/^: [0-9]+:[0-9]+;/{s=1} s' > "$tmp" 2>/dev/null
    if [[ -s "$tmp" ]]; then
        mv "$tmp" "$histfile" 2>/dev/null
        [[ -n "${ZSH_VERSION:-}" ]] && fc -R "$histfile" 2>/dev/null
    else
        rm -f "$tmp" 2>/dev/null
    fi
}

# Snapshot the full history file to a compressed, timestamped archive (non-destructive),
# then apply retention and optional live-file trimming. Gated to run once per
# DOT_HIST_ARCHIVE_INTERVAL seconds; pass --force to bypass the interval gate.
function dot::history::rotate() {
    local force=0
    [[ "${1:-}" == "--force" || "${1:-}" == "-f" ]] && force=1
    [[ "${DOT_HIST_ARCHIVE_ENABLE:-true}" == true ]] || return 0

    local histfile="${HISTFILE:-$HOME/.zsh_history}"
    [[ -s "$histfile" ]] || return 0

    local archive_dir=""
    local stamp=""
    local interval="${DOT_HIST_ARCHIVE_INTERVAL:-86400}"
    local now=0
    local last=0
    local ts=""
    local snapshot=""
    archive_dir="$(dot::history::_archive-dir)"
    stamp="${archive_dir}/.last-archive"

    if (( ! force )) && [[ -f "$stamp" ]]; then
        now=$(date +%s)
        last=$(cat "$stamp" 2>/dev/null || echo 0)
        case "$last" in ''|*[!0-9]*) last=0 ;; esac
        (( now - last < interval )) && return 0
    fi

    mkdir -p "$archive_dir" 2>/dev/null || return 0

    # Flush the current session to disk so the snapshot is complete.
    [[ -n "${ZSH_VERSION:-}" ]] && fc -AI 2>/dev/null

    ts="$(date +%Y%m%d-%H%M%S)"
    snapshot="${archive_dir}/zsh_history-${ts}.gz"
    gzip -c "$histfile" > "$snapshot" 2>/dev/null || return 0
    date +%s > "$stamp" 2>/dev/null

    dot::history::_prune-archives "$archive_dir"
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
function dot::static::foundation::load-user-secrets () {
    local secrets_file="${ICLOUD}/dot/secrets.json"
    if [[ ! -d "${ICLOUD}/dot" || ! -f "${secrets_file}" ]]; then
        return 0
    fi

    declare -A secrets
    local secretKeys=()
    secretKeys=(
        $(
            jq -r '. | keys | .[]' "${secrets_file}" | xargs
        )
    )
    export DOT_SECRET_KEYS=("${secretKeys[@]}")

    if [[ ${#secretKeys[@]} -gt 0 ]]; then
        touch "${TMPDIR}"/.secrets
        echo "#!/bin/bash" > "${TMPDIR}"/.secrets
    fi

    for secretKey in "${secretKeys[@]}"; do
        secrets[$secretKey]="$(jq --arg secretKey "${secretKey}" -r '.[$secretKey]' "${secrets_file}")"
        echo "export ${secretKey}=${secrets[$secretKey]}" >> "${TMPDIR}"/.secrets
    done

    if [[ -f "${TMPDIR}"/.secrets ]]; then
        . "${TMPDIR}"/.secrets
        rm -f "${TMPDIR}"/.secrets
    fi
}

# dot::static::foundation::ssh-identities: scan an SSH directory for private key files and return the
# basenames in a form suitable for `zstyle :omz:plugins:ssh-agent identities`
# (or any other consumer).
#
# Usage:
#   dot::static::foundation::ssh-identities [--dir DIR] [--format array|string] [--var VARNAME]
#                    [--exclude REGEX] [--absolute]
#
# Options:
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

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dir)      dir="$2"; shift 2 ;;
            --format)   format="$2"; shift 2 ;;
            --var)      outVar="$2"; shift 2 ;;
            --exclude)  exclude="$2"; shift 2 ;;
            --absolute) absolute=1; shift ;;
            -h|--help)
                cat <<'EOF'
Usage: dot::static::foundation::ssh-identities [--dir DIR] [--format array|string] [--var VARNAME]
                        [--exclude REGEX] [--absolute]

Scan an SSH directory for private key files and return their basenames
(or absolute paths) in a form suitable for consumers like
`zstyle :omz:plugins:ssh-agent identities`.

Options:
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
EOF
                return 0
                ;;
            *)
                echo "dot::static::foundation::ssh-identities: unknown argument: $1" >&2
                return 2
                ;;
        esac
    done

    if [[ "${format}" != "array" && "${format}" != "string" ]]; then
        echo "dot::static::foundation::ssh-identities: --format must be 'array' or 'string'" >&2
        return 2
    fi

    local -a keys=()
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
