#!/usr/local/bin/bash

# properly setup imgcat
# alias imgcat=$HOME/.iterm2/imgcat
function termImage () {

    local image="${1}"
    TERM=screen-256color "$HOME"/.iterm2/imgcat "${image}"
    sleep 5
    export TERM=xterm-256color
    # echo "hi"
}