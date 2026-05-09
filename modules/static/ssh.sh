#% author: Aaron Samuel
#% description: exports SSH_KEYS for future operations
# shellcheck shell=bash
# shellcheck source=/dev/null
# - ignore shellcheck warnings about read/mapfile
# shellcheck disable=SC2207
# - the literal '~/' patterns inside [[ ... ]] are intentional pattern matches,
#   not paths we expect the shell to expand
# shellcheck disable=SC2088



# # this ensures that foundational functions and variables are available, and also provides a consistent error handling mechanism if the library fails to load
# source "${DOT_MODULES}/zlib/foundation.sh" || {
#     echo "Error: unable to load internal library for SSH module"
#     exit 1
# }

declare -a SSH_KEYS

# default exclusion regex for non key related files in an .ssh directory
SSH_KEY_EXCLUDE_REGEX='(config|deprecated|.*\.pub|environment.*|known_hosts.*)'

# prepare SSH keys for export
if [[ -d "$HOME"/.ssh ]]; then
    files=("$HOME"/.ssh/*)
    for file in "${files[@]}"; do
        if [[ "$file" =~ ${SSH_KEY_EXCLUDE_REGEX} ]]; then
            continue
        fi
        base=$(basename "$file")
        SSH_KEYS+=("$base")
    done
fi

export SSH_KEYS

# listSshKeys: enumerate private SSH keys in a directory and report metadata
# (name, fingerprint, created/modified timestamps) along with any Host/Match
# bindings from an ssh config file that reference each key via IdentityFile.
#
# Usage:
#   listSshKeys [--dir DIR] [--config FILE] [--exclude REGEX]
#               [--format text|json] [-h|--help]
#
# Options:
#   --dir DIR        Directory to scan (default: $HOME/.ssh).
#   --config FILE    SSH config file to parse for bindings
#                    (default: ${DIR}/config).
#   --exclude REGEX  Override the default exclusion regex. The default skips
#                    config, *.pub, known_hosts*, environment*, and *deprecated*
#                    entries (same as SSH_KEY_EXCLUDE_REGEX).
#   --format FMT     Output format: "text" (default) or "json".
#   -h, --help       Show this help.
function listSshKeys () {
    local dir="${HOME}/.ssh"
    local config=""
    local exclude="${SSH_KEY_EXCLUDE_REGEX}"
    local format="text"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dir)     dir="$2"; shift 2 ;;
            --config)  config="$2"; shift 2 ;;
            --exclude) exclude="$2"; shift 2 ;;
            --format)  format="$2"; shift 2 ;;
            -h|--help)
                cat <<'EOF'
Usage: listSshKeys [--dir DIR] [--config FILE] [--exclude REGEX]
                   [--format text|json]

  --dir DIR        Directory to scan (default: $HOME/.ssh)
  --config FILE    SSH config file to parse (default: <dir>/config)
  --exclude REGEX  Override default key exclusion regex
  --format FMT     Output format: text (default) or json
  -h, --help       Show this help
EOF
                return 0
                ;;
            *)
                echo "listSshKeys: unknown argument: $1" >&2
                return 2
                ;;
        esac
    done

    if [[ -z "${config}" ]]; then
        config="${dir}/config"
    fi

    if [[ "${format}" != "text" && "${format}" != "json" ]]; then
        echo "listSshKeys: --format must be 'text' or 'json'" >&2
        return 2
    fi

    if [[ ! -d "${dir}" ]]; then
        echo "listSshKeys: directory not found: ${dir}" >&2
        return 1
    fi

    # parse config: build map of resolved IdentityFile path -> "host1|host2|..."
    # Recursive parser to follow `Include` directives. Uses portable shell
    # constructs (no BASH_REMATCH) so it works under both bash and zsh.
    local -A bindings=()
    local -A _seen_includes=()

    _expand_ssh_path () {
        # Expand ~, ~/, %d (user home dir) tokens used in ssh_config paths.
        local p="$1"
        # strip surrounding quotes (single or double)
        p="${p%\"}"; p="${p#\"}"
        p="${p%\'}"; p="${p#\'}"
        # %d -> $HOME (escape the % so zsh doesn't try to interpret it)
        p="${p//\%d/${HOME}}"
        if [[ "${p}" == '~' ]]; then
            p="${HOME}"
        elif [[ "${p:0:2}" == '~/' ]]; then
            p="${HOME}/${p:2}"
        fi
        printf '%s' "${p}"
    }

    _parse_ssh_config () {
        local cfg="$1"
        [[ -f "${cfg}" ]] || return 0
        # avoid infinite recursion on Include cycles
        if [[ -n "${_seen_includes[${cfg}]:-}" ]]; then
            return 0
        fi
        _seen_includes[${cfg}]=1

        local cfg_dir="${cfg%/*}"
        local current_hosts="" line stripped key val rest resolved existing
        local inc inc_path
        while IFS= read -r line || [[ -n "${line}" ]]; do
            # strip leading/trailing whitespace
            stripped="${line#"${line%%[![:space:]]*}"}"
            stripped="${stripped%"${stripped##*[![:space:]]}"}"
            [[ -z "${stripped}" ]] && continue
            [[ "${stripped:0:1}" == "#" ]] && continue

            # extract first token (key) and remainder (value); ssh_config
            # accepts whitespace or '=' as the separator
            key="${stripped%%[[:space:]=]*}"
            rest="${stripped#"${key}"}"
            # drop leading separator chars (spaces/tabs/'=') from remainder
            rest="${rest#"${rest%%[![:space:]=]*}"}"
            val="${rest}"
            [[ -z "${key}" ]] && continue

            # lowercase the key for case-insensitive match
            key="$(printf '%s' "${key}" | tr '[:upper:]' '[:lower:]')"

            case "${key}" in
                host|match)
                    current_hosts="${val}"
                    ;;
                include)
                    # ssh supports multiple, optionally glob-expanded, include
                    # paths separated by whitespace. Word-split with explicit
                    # IFS so this works in both bash and zsh.
                    val="${val%\"}"; val="${val#\"}"
                    val="${val%\'}"; val="${val#\'}"
                    local _old_ifs="${IFS}"
                    IFS=$' \t'
                    # shellcheck disable=SC2086
                    set -- ${val}
                    IFS="${_old_ifs}"
                    for inc in "$@"; do
                        inc_path="$(_expand_ssh_path "${inc}")"
                        if [[ "${inc_path:0:1}" != "/" ]]; then
                            inc_path="${cfg_dir}/${inc_path}"
                        fi
                        # try literal path first; fall back to shell globbing.
                        # Unquoted ${inc_path} expands globs in both bash and
                        # zsh; if there are no matches the literal string is
                        # returned and the -f test simply skips it.
                        local g
                        if [[ -f "${inc_path}" ]]; then
                            _parse_ssh_config "${inc_path}"
                        else
                            # shellcheck disable=SC2086
                            for g in ${inc_path}; do
                                [[ -f "${g}" ]] && _parse_ssh_config "${g}"
                            done
                        fi
                    done
                    ;;
                identityfile)
                    resolved="$(_expand_ssh_path "${val}")"
                    # resolve any remaining relative path against $HOME
                    if [[ "${resolved:0:1}" != "/" ]]; then
                        resolved="${HOME}/${resolved}"
                    fi
                    if [[ -n "${current_hosts}" ]]; then
                        existing="${bindings[${resolved}]:-}"
                        if [[ -z "${existing}" ]]; then
                            bindings[${resolved}]="${current_hosts}"
                        else
                            bindings[${resolved}]="${existing}|${current_hosts}"
                        fi
                    fi
                    ;;
            esac
        done < "${cfg}"
    }

    if [[ -f "${config}" ]]; then
        _parse_ssh_config "${config}"
    else
        echo "listSshKeys: config not found, bindings will be empty: ${config}" >&2
    fi

    # collect keys
    local -a keys=()
    local file base
    for file in "${dir}"/*; do
        [[ -e "${file}" ]] || continue
        [[ -f "${file}" ]] || continue
        base="${file##*/}"
        if [[ "${base}" =~ ${exclude} ]]; then
            continue
        fi
        keys+=("${file}")
    done

    # helper: dedupe + comma-join host labels (split on '|' portably)
    local _dedupe_join
    _dedupe_join () {
        local raw="$1"
        [[ -z "${raw}" ]] && { printf ''; return; }
        local -a parts=()
        local -A seen=()
        local p="" chunk="${raw}"
        # manual split on '|' so we don't depend on shell word splitting,
        # which behaves differently in bash vs zsh
        while [[ -n "${chunk}" ]]; do
            p="${chunk%%|*}"
            if [[ "${chunk}" == *"|"* ]]; then
                chunk="${chunk#*|}"
            else
                chunk=""
            fi
            p="${p#"${p%%[![:space:]]*}"}"
            p="${p%"${p##*[![:space:]]}"}"
            [[ -z "${p}" ]] && continue
            [[ -n "${seen[${p}]:-}" ]] && continue
            seen[${p}]=1
            parts+=("${p}")
        done
        local out=""
        for p in "${parts[@]}"; do
            if [[ -z "${out}" ]]; then
                out="${p}"
            else
                out="${out}, ${p}"
            fi
        done
        printf '%s' "${out}"
    }

    # helper: minimal JSON string escape
    local _json_escape
    _json_escape () {
        local s="$1"
        s="${s//\\/\\\\}"
        s="${s//\"/\\\"}"
        # strip control chars (tabs/newlines unlikely here, replace if present)
        s="${s//$'\t'/ }"
        s="${s//$'\n'/ }"
        s="${s//$'\r'/ }"
        printf '%s' "${s}"
    }

    local first=1
    if [[ "${format}" == "json" ]]; then
        printf '['
    fi

    # Pick a stat binary that supports BSD-style format flags. Some users
    # (homebrew coreutils) shadow `stat` with GNU `gstat`, which uses a
    # totally different syntax (-c) and would silently produce garbage.
    # On macOS the BSD stat is always available at /usr/bin/stat.
    local _stat="stat"
    if [[ -x /usr/bin/stat ]] && /usr/bin/stat -f '%Sm' -t '%Y' /dev/null >/dev/null 2>&1; then
        _stat="/usr/bin/stat"
    fi

    local fp created modified bindings_str abspath
    for file in "${keys[@]}"; do
        base="${file##*/}"
        # absolute path (already absolute since dir was used directly, but normalize)
        if [[ "${file:0:1}" == "/" ]]; then
            abspath="${file}"
        else
            abspath="${PWD}/${file}"
        fi

        # fingerprint: try .pub first, then private key
        fp="$(ssh-keygen -lf "${file}.pub" 2>/dev/null)"
        if [[ -z "${fp}" ]]; then
            fp="$(ssh-keygen -lf "${file}" 2>/dev/null)"
        fi
        [[ -z "${fp}" ]] && fp="unavailable"

        created="$("${_stat}" -f '%SB' -t '%Y-%m-%d %H:%M:%S' "${file}" 2>/dev/null)"
        [[ -z "${created}" ]] && created="unknown"
        modified="$("${_stat}" -f '%Sm' -t '%Y-%m-%d %H:%M:%S' "${file}" 2>/dev/null)"
        [[ -z "${modified}" ]] && modified="unknown"

        bindings_str="$(_dedupe_join "${bindings[${abspath}]:-}")"

        if [[ "${format}" == "json" ]]; then
            if (( first )); then
                first=0
            else
                printf ','
            fi
            printf '{"name":"%s","path":"%s","fingerprint":"%s","created":"%s","modified":"%s","bindings":[' \
                "$(_json_escape "${base}")" \
                "$(_json_escape "${abspath}")" \
                "$(_json_escape "${fp}")" \
                "$(_json_escape "${created}")" \
                "$(_json_escape "${modified}")"
            if [[ -n "${bindings_str}" ]]; then
                # rebuild from raw to avoid splitting on ", " (which can also
                # legally appear inside Host patterns). Use manual splitting
                # on '|' so this works in both bash and zsh.
                local raw="${bindings[${abspath}]:-}"
                local b="" chunk="${raw}"
                local -A bseen=()
                local bfirst=1
                while [[ -n "${chunk}" ]]; do
                    b="${chunk%%|*}"
                    if [[ "${chunk}" == *"|"* ]]; then
                        chunk="${chunk#*|}"
                    else
                        chunk=""
                    fi
                    b="${b#"${b%%[![:space:]]*}"}"
                    b="${b%"${b##*[![:space:]]}"}"
                    [[ -z "${b}" ]] && continue
                    [[ -n "${bseen[${b}]:-}" ]] && continue
                    bseen[${b}]=1
                    if (( bfirst )); then
                        bfirst=0
                    else
                        printf ','
                    fi
                    printf '"%s"' "$(_json_escape "${b}")"
                done
            fi
            printf ']}'
        else
            if (( first )); then
                first=0
            else
                printf '\n'
            fi
            [[ -z "${bindings_str}" ]] && bindings_str="(none)"
            printf 'key:           %s\n' "${base}"
            printf 'path:          %s\n' "${abspath}"
            printf 'fingerprint:   %s\n' "${fp}"
            printf 'created:       %s\n' "${created}"
            printf 'modified:      %s\n' "${modified}"
            printf 'bindings:      %s\n' "${bindings_str}"
        fi
    done

    if [[ "${format}" == "json" ]]; then
        printf ']\n'
    fi
}
