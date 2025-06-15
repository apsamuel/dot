#!/usr/bin/env bash


folder="$(pwd)"
session="$(basename "${folder}")"

selfPid="${$}"
echo "selfPid: ${selfPid}"

function tmuxSetOptions() {
    session_name="$1"
    echo "setting options for session ${session_name}"
    # TODO: set window status format
    #tmux set-option window_status_format "test #I #{?window_bell_flag,🔔,}#{?window_zoomed_flag,🔍,} #{b:pane_current_path} - #{pane_current_command}"
    #tmux set-window-option status-interval 5
}

function tmuxSessionExists() {
    session_name="$1"
    # replace dots with underscores
    session_name="${session_name//./_}"

    tmux list-sessions | grep -q "${session_name}"
    echo $?
}

function onDetached() {
    echo "exiting tmux session ${session//./_}"
    # when sessions names contain dots (hidden directories, etc) ...
    # tmux will replace them with underscores
    tmux kill-session -t "${session//./_}"
}

if [[ $(tmuxSessionExists "$session") -eq 0 ]]; then
    echo "tmux session '${session//./_}' exists, attaching (tmux attach -t ${session//./_})"
    tmux attach-session -t "${session//./_}"
    # tmuxSetOptions "${session}"
else
    echo "tmux session '${session//./_}' does not exist, creating"
    tmux -2 new-session -s "${session//./_}" -c "$folder"
    # tmuxSetOptions "${session//./_}"
fi



function onExit() {
    echo "exited ${session}"
}


trap onExit exit
trap onDetached SIGINT
