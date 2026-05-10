# shellcheck shell=bash
# shellcheck source=/dev/null

directory=$(dirname "$0")
library=$(basename "$0")

if [[ "${DOT_DEBUG}" -eq 1 ]]; then
    echo "loading: ${library} (${directory})"
fi

DOT_DIRECTORY_NAME="$(dirname "${DOT_DIRECTORY_NAME}")"
# temporarily set DOC_DIR to a basename for git ops...
DOT_DIR="${DOT_DIRECTORY}"


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


. "${DOT_DIR}"/modules/static/lib/internal.sh

function dot.shell {
    local command="${1:-version}"
    shift 2>/dev/null || true

    case "${command}" in
        help|-h|--help)
            cat <<'EOF'
Usage: dot.shell <command> [options]

Commands:
  version                 Print version information
  update                  Update dotfiles and oh-my-zsh
  reload [--debug]        Reload shell (via omz reload)
  changelog [options]     Print git changelog
  printenv                Print DOT_* environment variables
  secrets <action>        Manage secrets (placeholder)
  refresh-modules         Re-source all modules
  load-options            Load zsh options
  add-plugin <url>        Add a zsh plugin via git submodule
  add-theme <url>         Add a zsh theme via git submodule
  vendor <action> [path]  Manage git submodules (root + nested)
  help, -h, --help        Show this help message

Vendor actions:
  status, init, update, list
  Options: -n (dry-run), -v (verbose), -j <N> (parallel jobs)

Changelog options:
  --all                   Show full changelog
  --details               Show changelog with diffs

Secrets actions:
  --all, --details, --list, --add, --remove,
  --update, --get, --set, --import, --export
EOF
            return 0
            ;;

        version)
            local branch revision date author
            branch="$(git -C "${DOT_DIR}" rev-parse --abbrev-ref HEAD 2>/dev/null)"
            branch="${branch:-main}"
            revision="$(git -C "${DOT_DIR}" rev-parse --short HEAD 2>/dev/null)"
            revision="${revision:-}"
            date="$(git -C "${DOT_DIR}" log -1 --format=%cd --date=format:'%Y-%m-%d at %H:%M:%S' 2>/dev/null)"
            date="${date:-}"
            author="$(git -C "${DOT_DIR}" log -1 --format=%an 2>/dev/null)"
            author="${author:-}"
            echo "${branch} (${revision}) by ${author} on ${date}"
            return 0
            ;;

        update)
            git -C "${DOT_DIR}" pull 2>/dev/null || echo "please update your dotfiles manually"
            omz update
            return $?
            ;;

        reload)
            local opt_debug=false
            while [[ $# -gt 0 ]]; do
                case "$1" in
                    -d|--debug) opt_debug=true; shift ;;
                    *) shift ;;
                esac
            done

            if [[ "${opt_debug}" == true ]]; then
                set -x
                omz reload
                set +x
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
                    *) shift ;;
                esac
            done

            local log_fmt="%C(Yellow)%h  %C(reset)%ad (%C(Green)%cr%C(reset))%x09 %C(Cyan)%an: %C(reset)%s"

            if [[ "${opt_details}" == true ]]; then
                git -C "${DOT_DIR}" log -p --pretty="${log_fmt}" --date=short -7
                return $?
            elif [[ "${opt_all}" == true ]]; then
                git -C "${DOT_DIR}" log --pretty="${log_fmt}" --date=short
                return $?
            else
                git -C "${DOT_DIR}" log --pretty="${log_fmt}" --date=short -7
                return $?
            fi
            ;;

        printenv)
            env | grep -E '^DOT' | "${HOME}"/.dot/bin/mask-secret.sh
            return $?
            ;;

        secrets)
            local action="" opt_key="" opt_value=""
            local secrets_file="${ICLOUD}/dot/secrets.json"
            while [[ $# -gt 0 ]]; do
                case "$1" in
                    --all|--details|--list|--add|--remove|--update|--get|--set|--import|--export)
                        action="${1#--}"; shift ;;
                    -k|--key)   opt_key="$2"; shift 2 ;;
                    -v|--value) opt_value="$2"; shift 2 ;;
                    *) shift ;;
                esac
            done

            if [[ -z "${action}" ]]; then
                cat <<'USAGE'
Usage: dot.shell secrets <action> [--key <name>] [--value <val>]

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
                        echo "Usage: dot.shell secrets --get --key <name>"
                        return 1
                    fi
                    local val
                    val="$(jq -r --arg k "${opt_key}" '.[$k] // empty' "${secrets_file}")"
                    if [[ -z "${val}" ]]; then
                        echo "Error: key '${opt_key}' not found"
                        return 1
                    fi
                    echo "${val}"
                    ;;
                set)
                    if [[ -z "${opt_key}" || -z "${opt_value}" ]]; then
                        echo "Usage: dot.shell secrets --set --key <name> --value <val>"
                        return 1
                    fi
                    local tmp
                    tmp="$(jq --arg k "${opt_key}" --arg v "${opt_value}" \
                        '.[$k] = $v' "${secrets_file}")" && \
                        echo "${tmp}" > "${secrets_file}"
                    echo "Secret '${opt_key}' set."
                    ;;
                add)
                    if [[ -z "${opt_key}" || -z "${opt_value}" ]]; then
                        echo "Usage: dot.shell secrets --add --key <name> --value <val>"
                        return 1
                    fi
                    if jq -e --arg k "${opt_key}" 'has($k)' "${secrets_file}" >/dev/null 2>&1; then
                        echo "Error: key '${opt_key}' already exists (use --set or --update)"
                        return 1
                    fi
                    local tmp
                    tmp="$(jq --arg k "${opt_key}" --arg v "${opt_value}" \
                        '.[$k] = $v' "${secrets_file}")" && \
                        echo "${tmp}" > "${secrets_file}"
                    echo "Secret '${opt_key}' added."
                    ;;
                update)
                    if [[ -z "${opt_key}" || -z "${opt_value}" ]]; then
                        echo "Usage: dot.shell secrets --update --key <name> --value <val>"
                        return 1
                    fi
                    if ! jq -e --arg k "${opt_key}" 'has($k)' "${secrets_file}" >/dev/null 2>&1; then
                        echo "Error: key '${opt_key}' not found (use --add)"
                        return 1
                    fi
                    local tmp
                    tmp="$(jq --arg k "${opt_key}" --arg v "${opt_value}" \
                        '.[$k] = $v' "${secrets_file}")" && \
                        echo "${tmp}" > "${secrets_file}"
                    echo "Secret '${opt_key}' updated."
                    ;;
                remove)
                    if [[ -z "${opt_key}" ]]; then
                        echo "Usage: dot.shell secrets --remove --key <name>"
                        return 1
                    fi
                    if ! jq -e --arg k "${opt_key}" 'has($k)' "${secrets_file}" >/dev/null 2>&1; then
                        echo "Error: key '${opt_key}' not found"
                        return 1
                    fi
                    local tmp
                    tmp="$(jq --arg k "${opt_key}" 'del(.[$k])' "${secrets_file}")" && \
                        echo "${tmp}" > "${secrets_file}"
                    echo "Secret '${opt_key}' removed."
                    ;;
                import)
                    loadUserSecrets
                    echo "Secrets imported into environment (${#DOT_SECRET_KEYS[@]} keys)."
                    ;;
                export)
                    cat "${secrets_file}"
                    ;;
            esac
            return $?
            ;;

        refresh-modules)
            loadModules
            return $?
            ;;

        load-options)
            loadZshOptions
            return $?
            ;;

        add-plugin)
            if [[ -z "${1:-}" ]]; then
                echo "Usage: dot.shell add-plugin <git-repo-url>"
                return 1
            fi
            local git_url="$1"
            local plugin_name
            plugin_name="$(basename -s .git "${git_url}")"
            local plugins_dir="${DOT_DIR}/zsh/custom/plugins"
            git -C "${ZSH}" submodule add "${git_url}" "${plugins_dir}/${plugin_name}"
            return $?
            ;;

        add-theme)
            if [[ -z "${1:-}" ]]; then
                echo "Usage: dot.shell add-theme <git-repo-url>"
                return 1
            fi
            local git_url="$1"
            local theme_name
            theme_name="$(basename -s .git "${git_url}")"
            local themes_dir="${DOT_DIR}/zsh/custom/themes"
            git -C "${ZSH}" submodule add "${git_url}" "${themes_dir}/${theme_name}"
            return $?
            ;;

        vendor)
            local vendor_script="${DOT_DIR}/scripts/dot-submodule-sync.sh"
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
            echo "Unknown command: ${command}"
            echo "Use 'dot.shell help' for a list of available commands."
            return 1
            ;;
    esac
}

if type -t dot.shell &>/dev/null; then
    DOT_ENABLED=true
else
    DOT_ENABLED=false
fi
DOT_ENABLED=true
export DOT_ENABLED DOT_DIR
