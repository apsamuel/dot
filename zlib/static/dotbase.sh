#% author: Aaron Samuel
#% description: define baseline environment variables required for the dotfiles ecosystem and the shell
# shellcheck shell=bash
# shellcheck source=/dev/null
# - ignore shellcheck warnings about read/mapfile
# shellcheck disable=SC2207

# source static sources
source "${DOT_LIBRARY}"/static/limits.sh
source "${DOT_LIBRARY}"/static/autoload.sh