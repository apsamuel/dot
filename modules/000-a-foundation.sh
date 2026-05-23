#% author: Aaron Samuel
#% description: define baseline environment variables required for the dotfiles ecosystem and the shell
# shellcheck shell=bash

#** disable relevant shellcheck warnings **#
# shellcheck source=/dev/null
# shellcheck disable=SC2207
DOT_DEBUG="${DOT_DEBUG:-0}"

directory=$(dirname "$0")
library=$(basename "$0")

dot::static::logging::loading "${library}" "${directory}"

# we need to source the mac.sh file first
source "${DOT_MODULES}"/static/lib/mac.sh


function dot::foundation::compile-terminfo() {
    infocmp -x xterm-256color
    printf '\t%s\n' 'ncv@,'
} >/tmp/t && tic -x /tmp/t

function dot::foundation::shell-name () {
    if [[ -z "$fish_pid" ]]; then
        echo "fish"
    else
    currentShell="$(command ps -p $$ -ocomm=)"
    # removes non-standard characters and returns the shell name
    echo "${currentShell}" | tr '[:upper:]' '[:lower:]' | sed -e s/-//g | xargs
    fi
}

function dot::foundation::secure-string () {
    len="${1:-15}"
    secureString="$(pwgen -n -y "${len}" 1)"
    echo "$secureString"
}
