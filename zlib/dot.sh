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
