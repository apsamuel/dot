#!/usr/bin/env bash

exec >> /tmp/tmux-code.log 2>&1

architecture="$(uname -m)"
folder="$(pwd)"
session="${architecture}-$(basename "${folder}")"
session_name="${session//./_}"  # replace dots with underscores

# use osascript to list the pid, and details of every Code Window processes

function listCodeWindows() {
    osascript -e '
        tell application "System Events"
            set codeProcesses to every process whose name is "Code"
            set output to ""
            repeat with proc in codeProcesses
                set procName to name of proc
                set procPID to unix id of proc
                set procPath to (path of proc) as text
                set output to output & procName & " (PID: " & procPID & ", Path: " & procPath & ")" & linefeed
            end repeat
            return output
        end tell
    ' 2>/dev/null || true
}



if [[ "$DOT_DEBUG" -gt 0 ]]; then
    set +x
fi

if ! command -v tmux >/dev/null 2>&1; then
    echo "$(date +'%Y-%m-%d %H:%M:%S') tmux is not installed. Please install tmux to use this script."
    exit 0
fi


function tmuxInSession() {
    # check if the TMUX variable is set
    if [[ -n "$TMUX" ]]; then
        [ "$DOT_DEBUG" -gt 0 ] && echo "$(date +'%Y-%m-%d %H:%M:%S') already in a tmux session"
        return 0
    else
        [ "$DOT_DEBUG" -gt 0 ] && echo "$(date +'%Y-%m-%d %H:%M:%S') not in a tmux session"
        return 1
    fi
}

function tmuxSetOptions() {
    session_name="$1"
    [ "$DOT_DEBUG" -gt 0 ] &&echo "$(date +'%Y-%m-%d %H:%M:%S') setting options for session ${session_name}"
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
        [ "$DOT_DEBUG" -gt 0 ] && echo "$(date +'%Y-%m-%d %H:%M:%S') tmux session '${session_name}' exists"
        return 0
    else
        [ "$DOT_DEBUG" -gt 0 ] && echo "$(date +'%Y-%m-%d %H:%M:%S') tmux session '${session_name}' does not exist"
        return 1
    fi
}

function tmuxAttachSession() {
    session_name="$1"
    [ "$DOT_DEBUG" -gt 0 ] && echo "$(date +'%Y-%m-%d %H:%M:%S') attaching to tmux session ${session_name}"
    tmux attach-session -t "${session_name//./_}"
    return 0
}

function tmuxDetachSession() {
    session_name="$1"
    [ "$DOT_DEBUG" -gt 0 ] && echo "$(date +'%Y-%m-%d %H:%M:%S') detaching from tmux session ${session_name}"
    # tmux detach-session -t "${session_name//./_}" || true
    tmux detach-client -s "${session_name//./_}" 2>/dev/null || true
    return 0
}

function onDetached() {
    [ "$DOT_DEBUG" -gt 0 ] && echo "$(date +'%Y-%m-%d %H:%M:%S') exiting tmux session ${session//./_}"
    tmux kill-session -t "${session//./_}" 2>/dev/null || true
    return 0
}

if ! tmuxSessionExists "$session"; then
    [ "$DOT_DEBUG" -gt 0 ] && echo "$(date +'%Y-%m-%d %H:%M:%S') tmux session '${session//./_}' does not exist, creating"
    tmux -u -2 new-session -s "${session//./_}" -c "$folder"
else
    [ "$DOT_DEBUG" -gt 0 ] && echo "$(date +'%Y-%m-%d %H:%M:%S') tmux session '${session//./_}' exists, attaching (tmux attach -t ${session//./_})"
    tmux attach-session -t "${session//./_}"
fi

function onExit() {
    [ "$DOT_DEBUG" -gt 0 ] && echo "$(date +'%Y-%m-%d %H:%M:%S') exited ${session}"
    if [[ -n "${watcher_pid}" ]]; then
        kill "${watcher_pid}" 2>/dev/null || true
    fi
}

trap onExit exit
trap onDetached SIGINT SIGTERM SIGHUP
