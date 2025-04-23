# shellcheck shell=bash
DOT_DEBUG="${DOT_DEBUG:-0}"


directory=$(dirname "$0")
library=$(basename "$0")

if [[ "${DOT_DEBUG}" -eq 1 ]]; then
    echo "loading: ${library} (${directory})"
fi

function emulateIntepreter() {
    local emulation="${1:-sh}"
    local code="${1:-echo "Hello World"}"
    command zsh -c "emulate ${emulation}; $code"

}

function emulateZsh() {
    local code="${1:-echo "Hello World"}"
    command zsh -c "emulate bash; ${code}"
}

function spawnSh() {
    local code="${1:-echo "Hello World"}"
    command sh -c "$code"
}

function emulateBash() {
    local code="${1:-echo "Hello World"}"
    emulateZsh "$code"
}

function spawnBash() {
    local code="${1:-echo "Hello World"}"
    command bash -c "$code"
}

function emulateCsh() {
    local code="${1:-echo "Hello World"}"
    command zsh -c "emulate csh; $code"
}

function spawnCsh () {
    local code="${1:-echo "Hello World"}"
    command csh -c "$code"
}

function emulateKsh () {
    local code="${1:-echo "Hello World"}"
    command zsh -c "emulate ksh; $code"
}

function spawnKsh () {
    local code="${1:-echo "Hello World"}"
    command ksh -c "$code"
}

function emulateZsh () {
    local code="${1:-echo "Hello World"}"
    command zsh -l -c "emulate zsh; $code"
}

function spawnArm () {
    local code="${1:-uname}"
    arch -arm64 zsh -l -c "$code"
}

function spawnIntel () {
    local code="${1:-uname}"
    command arch -x86_64 zsh -l -c "$code"
}