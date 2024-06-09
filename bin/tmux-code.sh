#!/usr/local/bin/bash
# author: github.com/apsamuel
# description: make tmux great again

folder="$(pwd)"
session="$(basename "${folder}")"

selfPid="${$}"
echo "selfPid: ${selfPid}"

function tmuxSetOptions() {
    session_name="$1"
    echo "setting options for session ${session_name}"
    #tmux set-option window_status_format "test #I #{?window_bell_flag,🔔,}#{?window_zoomed_flag,🔍,} #{b:pane_current_path} - #{pane_current_command}"
    #tmux set-window-option status-interval 5
}

function tmuxSessionExists() {
    session_name="$1"
    tmux list-sessions | grep -q "${session_name}"
    echo $?
}

if [[ $(tmuxSessionExists "$session") -eq 0 ]]; then
    echo "tmux session '${session}' exists, attaching"
    tmux attach-session -t "${session}"
    tmuxSetOptions "${session}"
else
    echo "tmux session '${session}' does not exist, creating"
    tmux -2 new-session -s "${session}" -c "$folder"
    tmuxSetOptions "${session}"
fi


function onDetached() {
    echo "exiting tmux session ${session}'"
    tmux kill-session -t "${session}"
}

function onExit() {
    echo "exited ${session}"
}


trap onExit exit
