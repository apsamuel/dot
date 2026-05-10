# shellcheck shell=bash
# 🕵️ ignore shellcheck warnings about source statements
# shellcheck source=/dev/null

# Skip tmux helpers entirely when DOT_DISABLE_TMUX=1 (set automatically in
# VSCode/Copilot terminals — tmux's per-pane alt-screen breaks output capture).
if [[ "${DOT_DISABLE_TMUX}" -eq 1 ]]; then
    if [[ "${DOT_DEBUG}" -eq 1 ]]; then
        echo "tmux module disabled (DOT_DISABLE_TMUX=1)"
    fi
    return 0
fi

# point oh-my-tmux / tpm at an XDG-style plugin dir so we don't need ~/.tmux
export TMUX_PLUGIN_MANAGER_PATH="${XDG_DATA_HOME:-${HOME}/.local/share}/tmux/plugins"

tmuxKillUnattached() {
    tmux list-sessions -F '#{session_name} #{session_attached}' | awk '$2 == "0" {print $1}' | xargs -I {} -r tmux kill-session -t {}
}

tmuxGetSafeSessionName() {
    local session="$1"
    # ensure session name is safe for tmux
    session="${session//[^a-zA-Z0-9_]/_}"  # replace non-alphanumeric characters with underscores
    # replace dots with underscores
    session="${session//./_}"
    echo "${session}"
}

tmuxHasSession() {
    local session="$1"
    if tmux has-session -t "${session}" 2>/dev/null; then
        return 0  # session exists
    else
        return 1  # session does not exist
    fi
}

tmuxCreateSessionFromCwd() {
    local current_directory
    local current_directory_base
    local session_name

    current_directory="$(pwd)"
    current_directory_base="$(basename "${current_directory}")"
    session_name="$(tmuxGetSafeSessionName "${current_directory_base}")"

    if tmuxHasSession "${session_name}"; then
        echo "tmux session '${session_name}' already exists, attaching"
        tmux attach-session -t "${session_name}"
    else
        echo "tmux session '${session_name}' does not exist, creating"
        tmux -2 new-session -s "${session_name}" -c "${current_directory}"
    fi
}
