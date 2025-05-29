# shellcheck shell=bash
# 🕵️ ignore shellcheck warnings about source statements
# shellcheck source=/dev/null

tmuxKillUnattached() {
    tmux list-sessions -F '#{session_name} #{session_attached}' | awk '$2 == "0" {print $1}' | xargs -I {} -r tmux kill-session -t {}
}