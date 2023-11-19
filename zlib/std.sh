#!/usr/local/bin/bash

function emulate::interpreter () {
    local emulation="${1:-sh}"
    local code="${1:-echo "Hello World"}"
    command zsh -c "emulate ${emulation}; $code"

}

function emulate::sh () {
    local code="${1:-echo "Hello World"}"
    command zsh -c "emulate bash; $code"
}

function emulate::bash () {
    local code="${1:-echo "Hello World"}"
    emulate::sh "$code"
}

function emulate::csh () {
    local code="${1:-echo "Hello World"}"
    command zsh -c "emulate csh; $code"
}

function emulate::kzsh () {
    local code="${1:-echo "Hello World"}"
    command zsh -c "emulate ksh; $code"
}

function emulate::zsh () {
    local code="${1:-echo "Hello World"}"
    command zsh -c "emulate zsh; $code"
}