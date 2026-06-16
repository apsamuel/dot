# shellcheck shell=bash
# 🕵️ ignore shellcheck warnings about source statements
# shellcheck source=/dev/null

# Skip tmux helpers entirely when DOT_DISABLE_TMUX=1 (set automatically in
# VSCode/Copilot terminals — tmux's per-pane alt-screen breaks output capture).
if [[ "${DOT_DISABLE_TMUX}" -eq 1 ]]; then
    dot::static::logging::skip "tmux" "DOT_DISABLE_TMUX=1"
    return 0
fi

# point oh-my-tmux / tpm at the vendored plugin dir
export TMUX_PLUGIN_MANAGER_PATH="${DOT_ROOT}/vendor/oh-my-tmux/plugins"

dot::tmux::kill-unattached() {
    tmux list-sessions -F '#{session_name} #{session_attached}' | awk '$2 == "0" {print $1}' | xargs -I {} -r tmux kill-session -t {}
}

dot::tmux::safe-session-name() {
    local session="$1"
    # ensure session name is safe for tmux
    session="${session//[^a-zA-Z0-9_]/_}"  # replace non-alphanumeric characters with underscores
    # replace dots with underscores
    session="${session//./_}"
    echo "${session}"
}

dot::tmux::has-session() {
    local session="$1"
    if tmux has-session -t "${session}" 2>/dev/null; then
        return 0  # session exists
    else
        return 1  # session does not exist
    fi
}

dot::tmux::create-session-from-cwd() {
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
