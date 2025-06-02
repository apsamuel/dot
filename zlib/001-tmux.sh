# shellcheck shell=bash
# 🕵️ ignore shellcheck warnings about source statements
# shellcheck source=/dev/null

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
    local directory
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
        tmux -2 new-session -s "${session_name}" -c "${directory}"
    fi
}