#!/usr/local/bin/bash

function emulate::interpreter () {
    local emulation="${1:-sh}"
    local code="${1:-echo "Hello World"}"
    command zsh -c "emulate ${emulation}; $code"

}

function emulate::sh () {
    local code="${1:-echo "Hello World"}"
    command zsh -c "emulate bash; ${code}"
}

function run::sh () {
    local code="${1:-echo "Hello World"}"
    command sh -c "$code"
}

function emulate::bash () {
    local code="${1:-echo "Hello World"}"
    emulate::sh "$code"
}

function run::bash () {
    local code="${1:-echo "Hello World"}"
    command bash -c "$code"
}

function emulate::csh () {
    local code="${1:-echo "Hello World"}"
    command zsh -c "emulate csh; $code"
}

function run::csh () {
    local code="${1:-echo "Hello World"}"
    command csh -c "$code"
}

function emulate::ksh () {
    local code="${1:-echo "Hello World"}"
    command zsh -c "emulate ksh; $code"
}

function run::ksh () {
    local code="${1:-echo "Hello World"}"
    command ksh -c "$code"
}

function emulate::zsh () {
    local code="${1:-echo "Hello World"}"
    command zsh -c "emulate zsh; $code"
}

function run::arm () {
    local code="${1:-uname}"
    arch -arm64 zsh -c "$code"
}

function run::intel () {
    local code="${1:-uname}"
    command arch -x86_64 zsh -c "$code"
}