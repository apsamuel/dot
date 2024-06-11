#% author: Aaron Samuel
#% description: foundational functionality leveraged in shell entrypoints, required (early) for using the dotfiles project
# shellcheck shell=bash
# shellcheck source=/dev/null
# - ignore shellcheck warnings about read/mapfile
# shellcheck disable=SC2207


# we need to source the mac.sh file first
source "${DOT_LIBRARY}"/000-c-mac.sh

function getShellName () {
    currentShell="$(command ps -p $$ -ocomm=)"
    echo "$currentShell"
}

function getSecureString () {
    len="${1:-15}"
    secureString="$(pwgen -n -y "${len}" 1)"
    echo "$secureString"
}


function getProcessorCores() {
    sysctl -n machdep.cpu.core_count
}

function getProcessorBrand() {
    sysctl -n machdep.cpu.brand_string
}
