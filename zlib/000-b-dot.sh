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
#/Users/aaronsamuel/Library/Mobile\ Documents/com\~apple\~CloudDocs/
export ICLOUD="${HOME}/Library/Mobile Documents/com~apple~CloudDocs"
export ICLOUD_DOCUMENTS="${ICLOUD}/Documents"
export ICLOUD_DOWNLOADS="${ICLOUD}/Downloads"
export ICLOUD_SCREENSHOTS="${ICLOUD}/ScreenShots"


. "${DOT_DIR}"/zlib/static/lib/internal.sh

function dot.shell {
    local command="${1:-version}"

    # help
    if [[ "${command}" =~ [Hh]elp ]]; then
        echo "Usage: dot.shell [command]"
        echo ""
        echo "Commands:"
        echo "  version     print version information"
        echo "  update      update dotfiles"
        echo "  reload      reload dotfiles"
        echo "  changelog   print changelog"
        echo "  printenv    print environment variables"
        echo "  source-zlib source all zlib modules"
        return 0
    fi

    # version
    if [[ "${command}" =~ [Vv]ersion ]]; then
        branch="$(git -C "${DOT_DIR}" rev-parse --abbrev-ref HEAD)"
        local branch="${branch:-main}"
        revision="$(git -C "${DOT_DIR}" rev-parse --short HEAD)"
        local revision="${revision:-}"
        date="$(git -C "${DOT_DIR}" log -1 --format=%cd --date=format:'%Y-%m-%d at %H:%M:%S')"
        local date="${date:-}"
        author="$(git -C "${DOT_DIR}" log -1 --format=%an)"
        local author="${author:-}"
        echo "${branch} (${revision}) by ${author} on ${date}"
        return 0
    fi

    # update
    if [[ "${command}" =~ update ]]; then
        git -C "${DOT_DIR}" pull 2>/dev/null|| echo "please update your dotfiles manually"
        omz update
    fi

    # reload
    if [[ "${command}" =~ reload ]]; then
        # we are using oh-my-zsh, so basically...
        if [[ "${2}" == "-debug" ]]; then
            set -x
            omz reload
            set +x
        else
            omz reload
        fi
        #omz reload
    fi

    # changelog
    if [[ "${command}" == changelog ]]; then
        # accept subcommand(s)
        local subcommand="${2:-}"

        if [[ "${subcommand}" == "" || -z "${subcommand}" ]]; then
            git -C "${DOT_DIR}" log --pretty="%C(Yellow)%h  %C(reset)%ad (%C(Green)%cr%C(reset))%x09 %C(Cyan)%an: %C(reset)%s" --date=short -7 && return 0
            return 1
            # return 0
        fi

        if [[ "${subcommand}" == "-all" ]]; then
            git -C "${DOT_DIR}" log --pretty="%C(Yellow)%h  %C(reset)%ad (%C(Green)%cr%C(reset))%x09 %C(Cyan)%an: %C(reset)%s" --date=short && return 0
            return 1
        fi

        if [[ "${subcommand}" == "-details" ]]; then
            git -C "${DOT_DIR}" log -p --pretty="%C(Yellow)%h  %C(reset)%ad (%C(Green)%cr%C(reset))%x09 %C(Cyan)%an: %C(reset)%s" --date=short -7 && return 0
            return 1
        fi
    fi

    # env
    if [[ "${command}" == printenv ]]; then
        env | grep -E '^DOT' | "${HOME}"/.dot/bin/mask.sh
    fi

    # secrets
    if [[ "${command}" == secrets ]]; then
        local subcommand="${2:-}"
        if [[ "${subcommand}" == "" || -z "${subcommand}" ]]; then
            echo "Please provide a subcommand."
            return 1
        fi
        if [[ "${subcommand}" == "-all" ]]; then
            echo "This is a placeholder for secrets command."
            return 0
        fi
        if [[ "${subcommand}" == "-details" ]]; then
            echo "This is a placeholder for secrets command."
            return 0
        fi
        if [[ "${subcommand}" == "-list" ]]; then
            echo "This is a placeholder for secrets command."
            return 0
        fi
        if [[ "${subcommand}" == "-add" ]]; then
            echo "This is a placeholder for secrets command."
            return 0
        fi
        if [[ "${subcommand}" == "-remove" ]]; then
            echo "This is a placeholder for secrets command."
            return 0
        fi
        if [[ "${subcommand}" == "-update" ]]; then
            echo "This is a placeholder for secrets command."
            return 0
        fi
        if [[ "${subcommand}" == "-get" ]]; then
            echo "This is a placeholder for secrets command."
            return 0
        fi
        if [[ "${subcommand}" == "-set" ]]; then
            echo "This is a placeholder for secrets command."
            return 0
        fi
        if [[ "${subcommand}" == "-import" ]]; then
            echo "This is a placeholder for secrets command."
            return 0
        fi
        if [[ "${subcommand}" == "-export" ]]; then
            echo "This is a placeholder for secrets command."
            return 0
        fi

    fi

    # source-zlibs
    if [[ "${command}" == refresh-libs ]]; then
        # make ZLIB available to shell
        if [ -d "$DOT_LIBS_DIR" ]; then
            for lib in $(find "${DOT_LIBS_DIR}" -type f -name "*.sh" | sort -d); do
                # skip README.md files
                if [[ "$lib" =~ .*README.md ]]; then
                    continue
                fi
                if [[ ! "${DOT_DEBUG}x" == "x" && "${DOT_DEBUG}" == true ]]; then
                    echo "load source: $lib"
                fi
                . "$lib" || true
            done
        else
            echo "Warning: DOT_LIBS_DIR not found: $DOT_LIBS_DIR"
        fi
    # true
        # make ZLIB available to shell
        if [ -d "$DOT_LIBS_DIR" ]; then
            for lib in $(find "${DOT_LIBS_DIR}" -type f -name "*.sh" | sort -d); do
                # skip README.md files
                if [[ "$lib" =~ .*README.md ]]; then
                    continue
                fi
                if [[ ! "${DOT_DEBUG}x" == "x" && "${DOT_DEBUG}" == true ]]; then
                    echo "load source: $lib"
                fi
                . "$lib" || true
            done
        else
            echo "Warning: DOT_LIBS_DIR not found: $DOT_LIBS_DIR"
        fi
            return 0
    fi


    if [[ "${command}" == "load-options" ]]; then
        echo "Loading zsh options..."
        return 0
    fi

    if [[ "${command}" == "add-plugin" ]]; then
        if [[ -z "${2}" ]]; then
            echo "Usage: dot.shell add-plugin <git-repo-url>"
            return 1
        fi

        git_url="${2}"
        plugin_name="$(basename -s .git "${git_url}")"
        plugins_dir="${DOT_DIR}/zsh/custom/plugins"


        # adds the submodule in the $ZSH repos custom plugins directory
        git -C "${ZSH}" submodule add "${git_url}" "${plugins_dir}/${plugin_name}"
        return $?
    fi

    if [[ "${command}" == "add-theme" ]]; then
        if [[ -z "${2}" ]]; then
            echo "Usage: dot.shell add-theme <git-repo-url>"
            return 1
        fi

        git_url="${2}"
        theme_name="$(basename -s .git "${git_url}")"
        themes_dir="${DOT_DIR}/zsh/custom/themes"

        # adds the submodule in the $ZSH repos custom themes director
        git -C "${ZSH}" submodule add "${git_url}" "${themes_dir}/${theme_name}"
        return $?
    fi

    # anything else is an error
    echo "Unknown command: ${command}"
    echo "Use 'dot.shell help' for a list of available commands."
    return 1
}

if type -t dot.shell &>/dev/null; then
    DOT_ENABLED=true
else
    DOT_ENABLED=false
fi
DOT_ENABLED=true
export DOT_ENABLED DOT_DIR