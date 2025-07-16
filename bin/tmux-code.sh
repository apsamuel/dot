#!/usr/bin/env bash

exec >> /tmp/tmux-code.log 2>&1

folder="$(pwd)"
session="$(basename "${folder}")"
session_name="${session//./_}"  # replace dots with underscores

printenv

if [[ "$DOT_DEBUG" -gt 0 ]]; then
    set +x
fi

if ! command -v tmux ; then
    echo "tmux is not installed. Please install tmux to use this script."
    exit 0
fi


function tmuxInSession() {
    # check if the TMUX variable is set
    if [[ -n "$TMUX" ]]; then
        [ "$DOT_DEBUG" -gt 0 ] && echo "already in a tmux session"
        return 0
    else
        [ "$DOT_DEBUG" -gt 0 ] && echo "not in a tmux session"
        return 1
    fi
}

function tmuxSetOptions() {
    session_name="$1"
    [ "$DOT_DEBUG" -gt 0 ] &&echo "setting options for session ${session_name}"
    # TODO: set window status format
    #tmux set-option window_status_format "test #I #{?window_bell_flag,🔔,}#{?window_zoomed_flag,🔍,} #{b:pane_current_path} - #{pane_current_command}"
    #tmux set-window-option status-interval 5
    return 0
}

function tmuxSessionExists() {
    session_name="$1"
    session_name="${session_name//./_}"

    tmux list-sessions | grep -q "${session_name}"
    if tmux list-sessions | grep -q "${session_name}"; then
        [ "$DOT_DEBUG" -gt 0 ] && echo "tmux session '${session_name}' exists"
        return 0
    else
        [ "$DOT_DEBUG" -gt 0 ] && echo "tmux session '${session_name}' does not exist"
        return 1
    fi
}

function tmuxAttachSession() {
    session_name="$1"
    [ "$DOT_DEBUG" -gt 0 ] && echo "attaching to tmux session ${session_name}"
    tmux attach-session -t "${session_name//./_}"
    return 0
}

function tmuxDetachSession() {
    session_name="$1"
    [ "$DOT_DEBUG" -gt 0 ] && echo "detaching from tmux session ${session_name}"
    # tmux detach-session -t "${session_name//./_}" || true
    tmux detach-client -s "${session_name//./_}"
    return 0
}

function onDetached() {
    [ "$DOT_DEBUG" -gt 0 ] && echo "exiting tmux session ${session//./_}"
    tmux kill-session -t "${session//./_}"
    return 0
}

if ! tmuxSessionExists "$session"; then
    [ "$DOT_DEBUG" -gt 0 ] && echo "tmux session '${session//./_}' does not exist, creating"
    tmux -u -2 new-session -s "${session//./_}" -c "$folder"
else
    [ "$DOT_DEBUG" -gt 0 ] && echo "tmux session '${session//./_}' exists, attaching (tmux attach -t ${session//./_})"
    tmux attach-session -t "${session//./_}"
fi

function onExit() {
    [ "$DOT_DEBUG" -gt 0 ] && echo "exited ${session}"
}

trap onExit exit
trap onDetached SIGINT
