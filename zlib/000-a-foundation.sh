#shellcheck shell=bash
#% note: these steps will run first, as the order or sourcing is lexicographic hence the name 'a.sh'

# 🕵️ ignore shellcheck warnings about source statements
# shellcheck source=/dev/null

# 🕵️ ignore shellcheck warnings about read/mapfile
# shellcheck disable=SC2207

DOT_DEBUG="${DOT_DEBUG:-0}"
DOT_DIRECTORY="${DOT_DIRECTORY:-$(dirname "$0")}"
DOT_LIBRARY="${DOT_LIBRARY:-$(basename "$0")}"


# TODO: deprecate these variables, they are not very descriptive
directory=$(dirname "$0")
library=$(basename "$0")

export DOT_DEBUG DOT_DIRECTORY DOT_LIBRARY


if [[ "${DOT_DEBUG}" -eq 1 ]]; then
    echo "loading: ${library} (${directory})"
fi

# we need to source the mac.sh file first
source "${directory}"/000-c-mac.sh



function getShellName () {
    currentShell="$(command ps -p $$ -ocomm=)"
    echo "$currentShell"
}

function getSecureString () {
    len="${1:-15}"
    secureString="$(pwgen -n -y "${len}" 1)"
    echo "$secureString"
}
