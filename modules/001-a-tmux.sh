# shellcheck shell=bash
# 🕵️ ignore shellcheck warnings about source statements
# shellcheck source=/dev/null

# Skip tmux helpers entirely when DOT_DISABLE_TMUX=1 (set automatically in
# VSCode/Copilot terminals — tmux's per-pane alt-screen breaks output capture).
if [[ "${DOT_DISABLE_TMUX}" -eq 1 ]]; then
    dot::static::logging::skip "tmux" "DOT_DISABLE_TMUX=1"
    return 0
fi

# point oh-my-tmux at the vendored plugin dir
export TMUX_PLUGIN_MANAGER_PATH="${DOT_ROOT}/vendor/oh-my-tmux/plugins"

dot::tmux::help() {
    local usage="" purpose=""
    case "${1:-}" in
        ''|help|-h|--help) printf '%s\n' 'Usage: dot::tmux <command> [args]' 'Commands: kill-unattached, safe-session-name, has-session, create-session-from-cwd' 'Use dot::tmux help <command> for details.'; return ;;
        kill-unattached) purpose='Kill unattached sessions; stop on the first failure. No retries.' ;;
        safe-session-name) usage='<name>'; purpose='Print a sanitized session name. No tmux dependency.' ;;
        has-session) usage='<name>'; purpose='Check whether a session exists; returns 0 if present, 1 otherwise.' ;;
        create-session-from-cwd) purpose='Create or attach to a session named after the current directory.' ;;
        *) printf 'dot::tmux: unknown help topic: %s\n' "$1" >&2; return 1 ;;
    esac
    printf '%s\n' "${purpose}"
    printf 'Usage: dot::tmux %s %s\n       dot::tmux::%s %s\n' "$1" "${usage}" "$1" "${usage}"
    printf '%s\n' 'Session operations require tmux; help does not. Invalid input returns 1.' 'Use family help for data helpers; their operands are literal.'
    printf 'Example: dot::tmux help %s\n' "$1"
}

dot::tmux() {
    local action="${1:-help}"
    [[ $# -eq 0 ]] || shift
    case "${action}" in
        help|-h|--help) dot::tmux::help "$@" ;;
        kill-unattached) dot::tmux::kill-unattached "$@" ;;
        safe-session-name) dot::tmux::safe-session-name "$@" ;;
        has-session) dot::tmux::has-session "$@" ;;
        create-session-from-cwd) dot::tmux::create-session-from-cwd "$@" ;;
        *) printf 'dot::tmux: unknown command: %s\n' "${action}" >&2; return 1 ;;
    esac
}

dot::tmux::_require() {
    command -v tmux >/dev/null 2>&1 || { printf '%s\n' 'dot::tmux: tmux is required' >&2; return 1; }
}

dot::tmux::kill-unattached() {
    case "${1:-}" in -h|--help) dot::tmux::help kill-unattached; return ;; esac
    [[ $# -eq 0 ]] || { dot::tmux::help kill-unattached >&2; return 1; }
    dot::tmux::_require || return $?
    local sessions="" entry=""
    sessions="$(tmux list-sessions -F '#{session_name} #{session_attached}')" || return $?
    while IFS= read -r entry; do
        [[ "${entry##* }" == 0 ]] || continue
        tmux kill-session -t "${entry% *}" || return $?
    done <<< "${sessions}"
    return 0
}

dot::tmux::safe-session-name() {
    [[ $# -eq 1 ]] || { dot::tmux::help safe-session-name >&2; return 1; }
    local session="$1"
    # ensure session name is safe for tmux
    session="${session//[^a-zA-Z0-9_]/_}"  # replace non-alphanumeric characters with underscores
    # replace dots with underscores
    session="${session//./_}"
    echo "${session}"
}

dot::tmux::has-session() {
    [[ $# -eq 1 && -n "$1" ]] || { dot::tmux::help has-session >&2; return 1; }
    dot::tmux::_require || return $?
    local session="$1"
    if tmux has-session -t "${session}" 2>/dev/null; then
        return 0  # session exists
    else
        return 1  # session does not exist
    fi
}

dot::tmux::create-session-from-cwd() {
    case "${1:-}" in -h|--help) dot::tmux::help create-session-from-cwd; return ;; esac
    [[ $# -eq 0 ]] || { dot::tmux::help create-session-from-cwd >&2; return 1; }
    dot::tmux::_require || return $?
    local current_directory
    local current_directory_base
    local session_name

    current_directory="$(pwd)"
    current_directory_base="$(basename "${current_directory}")"
    session_name="$(dot::tmux::safe-session-name "${current_directory_base}")"

    if dot::tmux::has-session "${session_name}"; then
        echo "tmux session '${session_name}' already exists, attaching"
        tmux attach-session -t "${session_name}"
    else
        echo "tmux session '${session_name}' does not exist, creating"
        tmux -2 new-session -s "${session_name}" -c "${current_directory}"
    fi
}

if [[ "${DOT_INTERACTIVE}" -ne 0 && -n "${TMUX}" ]]; then
    dot::tmux::window-name() {
        ("$TMUX_PLUGIN_MANAGER_PATH"/tmux-window-name/scripts/rename_session_windows.py &)
    }

    add-zsh-hook chpwd dot::tmux::window-name
fi
