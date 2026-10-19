# shellcheck shell=bash
# shellcheck source=/dev/null

directory=$(dirname "$0")
library=$(basename "$0")

if [[ "${DOT_DEBUG}" -eq 1 ]]; then
    echo "loading: ${library} (${directory})"
fi


# detect TMUX session if present
if [[ -n "${TMUX}" ]]; then
    # TODO: we should catch the error and set a default value
    session_name="$(tmux display-message -p '#S')"
    export TMUX_SESSION_NAME="${session_name}"
else
    export TMUX_SESSION_NAME=""
fi

# setup icloud shortcuts
export ICLOUD="${HOME}/Library/Mobile Documents/com~apple~CloudDocs"
export ICLOUD_DOCUMENTS="${ICLOUD}/Documents"
export ICLOUD_DOWNLOADS="${ICLOUD}/Downloads"
export ICLOUD_SCREENSHOTS="${ICLOUD}/ScreenShots"


. "${DOT_DIRECTORY}"/modules/static/lib/internal.sh

dot::static::shell::help() {
    local topic="${1:-}" detail=""
    case "${topic}" in
        ''|help|-h|--help)
            printf '%s\n' 'Usage: dot::static::shell [command] [options]' \
                'Default: version. Commands: version, update, reload, changelog, printenv, secrets,' \
                'refresh-modules, load-options, add-plugin, add-theme, vendor.' \
                'Example: dot::static::shell help secrets'
            return ;;
        version) detail='Print repository version metadata (git); unavailable fields use existing empty/main defaults. No arguments.' ;;
        update) detail='Pull dotfiles, then run omz update. Requires git and omz. No arguments; no retries.' ;;
        reload) detail='Reload via omz. Options: -d, --debug enables tracing. No other arguments.' ;;
        changelog) detail='Read git history. Default: 7 entries. -a, --all: all entries; -d, --details: last 7 with diffs (takes precedence).' ;;
        printenv) detail='Print masked DOT environment variables. Requires dot::secrets::mask and its prerequisites. No arguments.' ;;
        secrets) detail='Manage $ICLOUD/dot/secrets.json using jq. Exactly one action:
--list: key names; --all: masked values; --details or --export: UNMASKED secrets.
--get --key NAME: UNMASKED value; --remove --key NAME: delete a key.
--set, --add, --update --key NAME --value VALUE: write a value. -k/-v are aliases.
--import: load into the shell. Writes/imports are not retried.
Example: dot::static::shell secrets --list' ;;
        refresh-modules) detail='Re-source dynamic modules with existing startup effects. No arguments; requires foundation loader.' ;;
        load-options) detail='Apply configured ZSH options. No arguments; requires foundation loader and yq.' ;;
        add-plugin|add-theme) detail='Add a git submodule: exactly one repository URL. Requires git and ZSH directory. Mutates checkout; no retry.' ;;
        vendor) detail='Forward arguments to scripts/dot-submodule-sync.sh. Actions: status, init, update, list. Options: -n dry-run, -v verbose, -j N jobs. init/update mutate submodules.' ;;
        *) printf 'dot::static::shell: unknown help topic: %s\n' "${topic}" >&2; return 1 ;;
    esac
    printf '%s\n' "Usage: dot::static::shell ${topic} [options]" "${detail}" \
        "Help: dot::static::shell help ${topic} or dot::static::shell ${topic} --help" \
        'Help returns 0 without accessing backends. Invalid wrapper input returns 1; backend failures are nonzero.'
}

function dot::static::shell {
    local command="${1:-version}"
    shift 2>/dev/null || true

    case "${command}" in
        help|-h|--help) dot::static::shell::help "$@"; return ;;
    esac
    case "${1:-}" in
        -h|--help) dot::static::shell::help "${command}"; return ;;
    esac
    case "${command}" in
        version|update|printenv|refresh-modules|load-options)
            [[ $# -eq 0 ]] || { dot::static::shell::help "${command}" >&2; return 1; } ;;
        add-plugin|add-theme)
            [[ $# -eq 1 && -n "$1" ]] || { dot::static::shell::help "${command}" >&2; return 1; } ;;
    esac

    case "${command}" in
        version)
            local branch revision date author
            branch="$(git -C "${DOT_DIRECTORY}" rev-parse --abbrev-ref HEAD 2>/dev/null)"
            branch="${branch:-main}"
            revision="$(git -C "${DOT_DIRECTORY}" rev-parse --short HEAD 2>/dev/null)"
            revision="${revision:-}"
            date="$(git -C "${DOT_DIRECTORY}" log -1 --format=%cd --date=format:'%Y-%m-%d at %H:%M:%S' 2>/dev/null)"
            date="${date:-}"
            author="$(git -C "${DOT_DIRECTORY}" log -1 --format=%an 2>/dev/null)"
            author="${author:-}"
            echo "${branch} (${revision}) by ${author} on ${date}"
            return 0
            ;;

        update)
            command -v git >/dev/null 2>&1 && command -v omz >/dev/null 2>&1 || {
                printf 'dot::static::shell: git and omz are required\n' >&2; return 1;
            }
            git -C "${DOT_DIRECTORY}" pull || return $?
            omz update
            return $?
            ;;

        reload)
            local opt_debug=false reload_rc=0 tracing=false
            while [[ $# -gt 0 ]]; do
                case "$1" in
                    -d|--debug) opt_debug=true; shift ;;
                    --) shift; [[ $# -eq 0 ]] || return 1 ;;
                    *) dot::static::shell::help reload >&2; return 1 ;;
                esac
            done

            if [[ "${opt_debug}" == true ]]; then
                [[ "$-" != *x* ]] || tracing=true
                set -x
                omz reload || reload_rc=$?
                [[ "${tracing}" == true ]] || set +x
                return "${reload_rc}"
            else
                omz reload
            fi
            return $?
            ;;

        changelog)
            local opt_all=false opt_details=false
            while [[ $# -gt 0 ]]; do
                case "$1" in
                    -a|--all)     opt_all=true; shift ;;
                    -d|--details) opt_details=true; shift ;;
                    --) shift; [[ $# -eq 0 ]] || return 1 ;;
                    *) dot::static::shell::help changelog >&2; return 1 ;;
                esac
            done

            local log_fmt="%C(Yellow)%h  %C(reset)%ad (%C(Green)%cr%C(reset))%x09 %C(Cyan)%an: %C(reset)%s"

            if [[ "${opt_details}" == true ]]; then
                git -C "${DOT_DIRECTORY}" log -p --pretty="${log_fmt}" --date=short -7
                return $?
            elif [[ "${opt_all}" == true ]]; then
                git -C "${DOT_DIRECTORY}" log --pretty="${log_fmt}" --date=short
                return $?
            else
                git -C "${DOT_DIRECTORY}" log --pretty="${log_fmt}" --date=short -7
                return $?
            fi
            ;;

        printenv)
            command -v dot::secrets::mask >/dev/null 2>&1 || {
                printf 'dot::static::shell: dot::secrets::mask is required\n' >&2; return 1;
            }
            (set -o pipefail; env | grep -E '^DOT' | dot::secrets::mask)
            return $?
            ;;

        secrets)
            local action="" opt_key="" opt_value=""
            local secrets_file="${ICLOUD}/dot/secrets.json"
            while [[ $# -gt 0 ]]; do
                case "$1" in
                    --all|--details|--list|--add|--remove|--update|--get|--set|--import|--export)
                        [[ -z "${action}" ]] || { printf 'dot::static::shell: choose one secrets action\n' >&2; return 1; }
                        action="${1#--}"; shift ;;
                    -k|--key|-v|--value)
                        [[ $# -ge 2 ]] || { printf 'dot::static::shell: missing option value\n' >&2; return 1; }
                        case "$1" in -k|--key) opt_key="$2" ;; *) opt_value="$2" ;; esac
                        shift 2 ;;
                    -h|--help) dot::static::shell::help secrets; return ;;
                    --) shift; [[ $# -eq 0 ]] || return 1 ;;
                    *) printf 'dot::static::shell: invalid secrets option\n' >&2; return 1 ;;
                esac
            done

            if [[ -z "${action}" ]]; then
                cat <<'USAGE'
Usage: dot::static::shell secrets <action> [--key <name>] [--value <val>]

Actions:
  --list              List all secret key names
  --all               Show all secrets (key=<masked>)
  --details           Show all secrets (key=value, unmasked!)
  --get --key <name>  Print the value of a single secret
  --set --key <k> --value <v>   Set (add or update) a secret
  --add --key <k> --value <v>   Add a new secret (fails if exists)
  --update --key <k> --value <v> Update an existing secret
  --remove --key <name>         Remove a secret
  --import            Import secrets into the shell environment
  --export            Dump secrets.json to stdout
USAGE
                return 1
            fi

            # guard: require the secrets file for most actions
            command -v jq >/dev/null 2>&1 || { printf 'dot::static::shell: jq is required\n' >&2; return 1; }
            if [[ "${action}" != "import" && ! -f "${secrets_file}" ]]; then
                echo "Error: secrets file not found: ${secrets_file}"
                return 1
            fi

            case "${action}" in
                list)
                    jq -r 'keys[]' "${secrets_file}"
                    ;;
                all)
                    jq -r 'to_entries[] | "\(.key)=********"' "${secrets_file}"
                    ;;
                details)
                    jq -r 'to_entries[] | "\(.key)=\(.value)"' "${secrets_file}"
                    ;;
                get)
                    if [[ -z "${opt_key}" ]]; then
                        echo "Usage: dot::static::shell secrets --get --key <name>"
                        return 1
                    fi
                    local val
                    val="$(jq -r --arg k "${opt_key}" '.[$k] // empty' "${secrets_file}")" || return $?
                    if [[ -z "${val}" ]]; then
                        echo "Error: key '${opt_key}' not found"
                        return 1
                    fi
                    echo "${val}"
                    ;;
                set)
                    if [[ -z "${opt_key}" || -z "${opt_value}" ]]; then
                        echo "Usage: dot::static::shell secrets --set --key <name> --value <val>"
                        return 1
                    fi
                    local tmp=""
                    tmp="$(jq --arg k "${opt_key}" --arg v "${opt_value}" \
                        '.[$k] = $v' "${secrets_file}")" || return $?
                    printf '%s\n' "${tmp}" > "${secrets_file}" || return $?
                    echo "Secret '${opt_key}' set."
                    ;;
                add)
                    if [[ -z "${opt_key}" || -z "${opt_value}" ]]; then
                        echo "Usage: dot::static::shell secrets --add --key <name> --value <val>"
                        return 1
                    fi
                    if jq -e --arg k "${opt_key}" 'has($k)' "${secrets_file}" >/dev/null 2>&1; then
                        echo "Error: key '${opt_key}' already exists (use --set or --update)"
                        return 1
                    fi
                    local tmp=""
                    tmp="$(jq --arg k "${opt_key}" --arg v "${opt_value}" \
                        '.[$k] = $v' "${secrets_file}")" || return $?
                    printf '%s\n' "${tmp}" > "${secrets_file}" || return $?
                    echo "Secret '${opt_key}' added."
                    ;;
                update)
                    if [[ -z "${opt_key}" || -z "${opt_value}" ]]; then
                        echo "Usage: dot::static::shell secrets --update --key <name> --value <val>"
                        return 1
                    fi
                    if ! jq -e --arg k "${opt_key}" 'has($k)' "${secrets_file}" >/dev/null 2>&1; then
                        echo "Error: key '${opt_key}' not found (use --add)"
                        return 1
                    fi
                    local tmp=""
                    tmp="$(jq --arg k "${opt_key}" --arg v "${opt_value}" \
                        '.[$k] = $v' "${secrets_file}")" || return $?
                    printf '%s\n' "${tmp}" > "${secrets_file}" || return $?
                    echo "Secret '${opt_key}' updated."
                    ;;
                remove)
                    if [[ -z "${opt_key}" ]]; then
                        echo "Usage: dot::static::shell secrets --remove --key <name>"
                        return 1
                    fi
                    if ! jq -e --arg k "${opt_key}" 'has($k)' "${secrets_file}" >/dev/null 2>&1; then
                        echo "Error: key '${opt_key}' not found"
                        return 1
                    fi
                    local tmp=""
                    tmp="$(jq --arg k "${opt_key}" 'del(.[$k])' "${secrets_file}")" || return $?
                    printf '%s\n' "${tmp}" > "${secrets_file}" || return $?
                    echo "Secret '${opt_key}' removed."
                    ;;
                import)
                    dot::static::foundation::load-user-secrets || return $?
                    echo "Secrets imported into environment (${#DOT_SECRET_KEYS[@]} keys)."
                    ;;
                export)
                    cat "${secrets_file}"
                    ;;
            esac
            return $?
            ;;

        refresh-modules)
            dot::static::foundation::load-modules
            return $?
            ;;

        load-options)
            dot::static::foundation::load-zsh-options
            return $?
            ;;

        add-plugin)
            if [[ -z "${1:-}" ]]; then
                echo "Usage: dot::static::shell add-plugin <git-repo-url>"
                return 1
            fi
            local git_url="$1"
            local plugin_name
            plugin_name="$(basename -s .git "${git_url}")"
            local plugins_dir="${DOT_DIRECTORY}/zsh/custom/plugins"
            git -C "${ZSH}" submodule add "${git_url}" "${plugins_dir}/${plugin_name}"
            return $?
            ;;

        add-theme)
            if [[ -z "${1:-}" ]]; then
                echo "Usage: dot::static::shell add-theme <git-repo-url>"
                return 1
            fi
            local git_url="$1"
            local theme_name
            theme_name="$(basename -s .git "${git_url}")"
            local themes_dir="${DOT_DIRECTORY}/zsh/custom/themes"
            git -C "${ZSH}" submodule add "${git_url}" "${themes_dir}/${theme_name}"
            return $?
            ;;

        vendor)
            local vendor_script="${DOT_DIRECTORY}/scripts/dot-submodule-sync.sh"
            if [[ ! -x "${vendor_script}" ]]; then
                if [[ -r "${vendor_script}" ]]; then
                    bash "${vendor_script}" "$@"
                    return $?
                fi
                echo "Error: vendor script not found: ${vendor_script}"
                return 1
            fi
            "${vendor_script}" "$@"
            return $?
            ;;

        *)
            echo "Unknown command: ${command}" >&2
            echo "Use 'dot::static::shell help' for a list of available commands." >&2
            return 1
            ;;
    esac
}
