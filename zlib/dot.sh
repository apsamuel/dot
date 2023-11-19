#!/usr/local/bin/bash

_directory_name="$(dirname "${0}")"
directory_name="$(dirname "${_directory_name}")"
export DOT_DIR="${directory_name}"

# detect TMUX session if present
if [[ -n "${TMUX}" ]]; then
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

function dot::sh {
    local command="${1:-version}"

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
    fi

    # reload
    if [[ "${command}" =~ reload ]]; then
        # we are using oh-my-zsh, so basically...
        omz reload
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
        env | "${HOME}"/.dot/bin/mask.sh
    fi

}