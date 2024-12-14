#% author: Aaron Samuel
#% description: define baseline environment variables required for the dotfiles ecosystem and the shell
# shellcheck shell=bash

#** disable relevant shellcheck warnings **#
# shellcheck source=/dev/null
# shellcheck disable=SC2207


if [[ "${DOT_DEBUG}" -eq 1 ]]; then
    echo "loading: ${DOT_LIBRARY} (${DOT_DIRECTORY})"
fi

# we need to source the mac.sh file first
source "${DOT_LIBRARY}"/static/lib/mac.sh


function compileTermInfo() {
    infocmp -x xterm-256color
    printf '\t%s\n' 'ncv@,'
} >/tmp/t && tic -x /tmp/t

function getShellName () {
    if [[ -z "$fish_pid" ]]; then
        echo "fish"
    else
    currentShell="$(command ps -p $$ -ocomm=)"
    # removes non-standard characters and returns the shell name
    echo "${currentShell}" | tr '[:upper:]' '[:lower:]' | sed -e s/-//g | xargs
    fi
}

function getSecureString () {
    len="${1:-15}"
    secureString="$(pwgen -n -y "${len}" 1)"
    echo "$secureString"
}
