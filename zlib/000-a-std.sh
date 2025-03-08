# shellcheck shell=bash
DOT_DEBUG="${DOT_DEBUG:-0}"


directory=$(dirname "$0")
library=$(basename "$0")

if [[ "${DOT_DEBUG}" -eq 1 ]]; then
    echo "loading: ${library} (${directory})"
fi

function emulate::interpreter () {
    local emulation="${1:-sh}"
    local code="${1:-echo "Hello World"}"
    command zsh -c "emulate ${emulation}; $code"

}

function emulate::sh () {
    local code="${1:-echo "Hello World"}"
    command zsh -c "emulate bash; ${code}"
}

function spawn::sh () {
    local code="${1:-echo "Hello World"}"
    command sh -c "$code"
}

function emulate::bash () {
    local code="${1:-echo "Hello World"}"
    emulate::sh "$code"
}

function spawn::bash () {
    local code="${1:-echo "Hello World"}"
    command bash -c "$code"
}

function emulate::csh () {
    local code="${1:-echo "Hello World"}"
    command zsh -c "emulate csh; $code"
}

function spawn::csh () {
    local code="${1:-echo "Hello World"}"
    command csh -c "$code"
}

function emulate::ksh () {
    local code="${1:-echo "Hello World"}"
    command zsh -c "emulate ksh; $code"
}

function spawn::ksh () {
    local code="${1:-echo "Hello World"}"
    command ksh -c "$code"
}

function emulate::zsh () {
    local code="${1:-echo "Hello World"}"
    command zsh -l -c "emulate zsh; $code"
}

function spawn::arm () {
    local code="${1:-uname}"
    arch -arm64 zsh -l -c "$code"
}

function spawn::intel () {
    local code="${1:-uname}"
    command arch -x86_64 zsh -l -c "$code"
}